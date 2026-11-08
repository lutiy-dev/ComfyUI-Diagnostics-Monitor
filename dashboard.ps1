# ComfyUI Diagnostics LAB v0.4. Windows PowerShell 5.1, read-only, localhost only.
# Keep collector.ps1 running separately for GPU/Windows sampling.
param(
  [ValidateSet('HOME','WORK')][string]$Machine='HOME',
  [string]$DataDir="$env:LOCALAPPDATA\ComfyUI-Diagnostics",
  [string]$ComfyUrl='http://127.0.0.1:8188',
  [switch]$SelfTest,
  [switch]$HudSelfTest
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization
. (Join-Path $PSScriptRoot 'lib\ComfyWs.ps1')
$uri=[uri]$ComfyUrl
if ($uri.Scheme -ne 'http' -or $uri.Host -notin @('localhost','127.0.0.1','::1') -or $uri.UserInfo) {
    throw 'ComfyUI endpoint must be unauthenticated localhost HTTP'
}
$null=New-Item -ItemType Directory -Path $DataDir -Force
$script:wsEndpoint='ws://'+$uri.Authority+'/ws?clientId='+[guid]::NewGuid().ToString()
$script:socket=$null
$script:connectTask=$null
$script:connectCts=$null
$script:receiveTask=$null
$script:buffer=New-Object byte[] 65536
$script:message=New-Object System.IO.MemoryStream
$script:skipMessage=$false
$script:lastAttempt=[datetime]::MinValue
$script:activeNode='—'
$script:step=0
$script:stepTotal=0
$script:session='Idle'
$script:wsState='DISCONNECTED'
$script:lastEvent=''
$script:ticks=0
$script:closing=$false

function Safe-Disconnect {
    if ($null -ne $script:connectCts) {
        try { $script:connectCts.Cancel() } catch {}
        try { $script:connectCts.Dispose() } catch {}
        $script:connectCts=$null
    }
    if ($null -ne $script:socket) {
        try { $script:socket.Abort() } catch {}
        try { $script:socket.Dispose() } catch {}
    }
    $script:socket=$null
    $script:connectTask=$null
    $script:receiveTask=$null
    $script:wsState='DISCONNECTED'
    $script:message.SetLength(0)
    $script:skipMessage=$false
}
function Save-LiveEvent($record) {
    $name='live_'+$Machine+'_'+(Get-Date -Format 'yyyyMMdd')+'.jsonl'
    $path=Join-Path $DataDir $name
    # Bound to 5 MiB/day. Do not delete historical evidence automatically.
    if ((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -ge 5MB) { return }
    $obj=[ordered]@{
        schema=1; machine=$Machine; source='ComfyUI'
        time_utc=(Get-Date).ToUniversalTime().ToString('o')
        type=$record.type; node=$record.node; prompt_id=$record.prompt_id
        current=$record.current; total=$record.total
        error_code=$record.error_code; queue_remaining=$record.queue_remaining
    }
    [IO.File]::AppendAllText($path,((ConvertTo-Json $obj -Compress -Depth 5)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
}
function Handle-WsMessage([string]$json) {
    $ev=ConvertFrom-ComfyWsEvent -Json $json
    if ($null -eq $ev) { return }
    switch ($ev.type) {
        'execution_start' { $script:session='Running'; $script:activeNode='—'; $script:step=0; $script:stepTotal=0 }
        'executing' {
            if ([string]::IsNullOrEmpty($ev.node)) {
                $script:activeNode='—'; $script:session='Idle'; $script:step=0; $script:stepTotal=0
            } else {
                $script:activeNode=$ev.node; $script:session='Running'
                $script:step=0; $script:stepTotal=0
            }
        }
        'progress' { $script:step=$ev.current; $script:stepTotal=$ev.total; $script:session='Running' }
        'execution_success' { $script:session='Completed'; $script:activeNode='—' }
        'execution_interrupted' { $script:session='Interrupted'; $script:activeNode='—' }
        'execution_error' { $script:session='ERROR'; $script:lastEvent='ComfyUI: '+$ev.error_code }
    }
    if ($ev.type -ne 'status' -or $null -ne $ev.queue_remaining) { Save-LiveEvent $ev }
}
function Tick-WebSocket {
    if ($script:closing) { return }
    if ($null -eq $script:socket) {
        if (((Get-Date)-$script:lastAttempt).TotalSeconds -lt 5) { return }
        $script:lastAttempt=Get-Date
        try {
            $script:socket=[Net.WebSockets.ClientWebSocket]::new()
            $script:connectCts=[Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(3))
            $script:connectTask=$script:socket.ConnectAsync([uri]$script:wsEndpoint,$script:connectCts.Token)
            $script:wsState='CONNECTING'
        } catch { Safe-Disconnect }
        return
    }
    if ($null -ne $script:connectTask) {
        if (-not $script:connectTask.IsCompleted) { return }
        try {
            $script:connectTask.GetAwaiter().GetResult()
            $script:wsState='CONNECTED'
            $script:connectTask=$null
            if ($null -ne $script:connectCts) { $script:connectCts.Dispose(); $script:connectCts=$null }
        } catch { Safe-Disconnect; return }
    }
    if ($script:socket.State -ne [Net.WebSockets.WebSocketState]::Open) { Safe-Disconnect; return }
    if ($null -eq $script:receiveTask) {
        try {
            $segment=[ArraySegment[byte]]::new($script:buffer)
            $script:receiveTask=$script:socket.ReceiveAsync($segment,[Threading.CancellationToken]::None)
        } catch { Safe-Disconnect }
        return
    }
    if (-not $script:receiveTask.IsCompleted) { return }
    try {
        $result=$script:receiveTask.GetAwaiter().GetResult()
        $script:receiveTask=$null
        if ($result.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { Safe-Disconnect; return }
        if ($result.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Binary) { $script:skipMessage=$true }
        if (-not $script:skipMessage -and $result.Count -gt 0) {
            if ($script:message.Length + $result.Count -gt 131072) { $script:skipMessage=$true }
            else { $script:message.Write($script:buffer,0,$result.Count) }
        }
        if ($result.EndOfMessage) {
            if (-not $script:skipMessage) {
                $json=[Text.Encoding]::UTF8.GetString($script:message.ToArray())
                Handle-WsMessage $json
            }
            $script:message.SetLength(0)
            $script:skipMessage=$false
        }
    } catch { Safe-Disconnect }
}

$form=New-Object Windows.Forms.Form
$form.Text="ComfyUI Diagnostics · $Machine · LAB v0.4"
$form.Size=[Drawing.Size]::new(960,740)
$form.MinimumSize=[Drawing.Size]::new(960,740)
$form.BackColor=[Drawing.Color]::FromArgb(22,26,33)
$form.ForeColor=[Drawing.Color]::White
$form.Font=[Drawing.Font]::new('Segoe UI',10)
$form.StartPosition='CenterScreen'
$form.TopMost=$true
$form.KeyPreview=$true

function New-Label([string]$name,[int]$x,[int]$y,[int]$width,[int]$height,[int]$size=11) {
    $l=New-Object Windows.Forms.Label
    $l.Text=$name; $l.Location=[Drawing.Point]::new($x,$y)
    $l.Size=[Drawing.Size]::new($width,$height)
    $l.Font=[Drawing.Font]::new('Segoe UI',$size)
    $l.ForeColor=[Drawing.Color]::White
    $form.Controls.Add($l)
    return $l
}
$title=New-Label 'GPU / ComfyUI Diagnostics' 20 12 620 36 18
$status=New-Label 'Collector: waiting | WebSocket: connecting' 22 55 900 25 10
$gpu=New-Label 'GPU: —' 22 94 880 26 13
$gpu.ForeColor=[Drawing.Color]::DeepSkyBlue
$vram=New-Label 'VRAM: —' 22 128 880 26 13
$vram.ForeColor=[Drawing.Color]::Orange
$temp=New-Label 'Temperature: —  |  Power: —  |  RAM: —' 22 160 900 25 11
$node=New-Label 'Node: —' 22 200 880 30 13
$progress=New-Object Windows.Forms.ProgressBar
$progress.Location=[Drawing.Point]::new(22,237)
$progress.Size=[Drawing.Size]::new(790,20)
$progress.Minimum=0; $progress.Maximum=100
$form.Controls.Add($progress)
$steps=New-Label 'Sampler: —' 820 233 120 26 10

$chart=New-Object Windows.Forms.DataVisualization.Charting.Chart
$chart.Location=[Drawing.Point]::new(20,280)
$chart.Size=[Drawing.Size]::new(905,220)
$chart.BackColor=[Drawing.Color]::FromArgb(28,34,42)
$area=New-Object Windows.Forms.DataVisualization.Charting.ChartArea 'Telemetry'
$area.BackColor=$chart.BackColor
$area.AxisX.LabelStyle.Enabled=$false
$area.AxisX.MajorGrid.Enabled=$false
$area.AxisY.Minimum=0; $area.AxisY.Maximum=100
$area.AxisY.LabelStyle.ForeColor=[Drawing.Color]::White
$area.AxisY.MajorGrid.LineColor=[Drawing.Color]::FromArgb(55,65,75)
$chart.ChartAreas.Add($area)
foreach ($spec in @(@('GPU %','DeepSkyBlue'),@('VRAM %','Orange'))) {
    $series=New-Object Windows.Forms.DataVisualization.Charting.Series $spec[0]
    $series.ChartType='Line'; $series.BorderWidth=2
    $series.Color=[Drawing.Color]::FromName($spec[1])
    $chart.Series.Add($series)
}
$legend=New-Object Windows.Forms.DataVisualization.Charting.Legend
$legend.ForeColor=[Drawing.Color]::White
$legend.BackColor=$chart.BackColor
$chart.Legends.Add($legend)
$form.Controls.Add($chart)
$null=New-Label 'Incident timeline (normalized events, no prompts)' 22 510 800 25 11
$incident=New-Object Windows.Forms.TextBox
$incident.Location=[Drawing.Point]::new(22,540)
$incident.Size=[Drawing.Size]::new(904,145)
$incident.Multiline=$true
$incident.ReadOnly=$true
$incident.ScrollBars='Vertical'
$incident.BackColor=[Drawing.Color]::FromArgb(30,36,44)
$incident.ForeColor=[Drawing.Color]::White
$incident.Font=[Drawing.Font]::new('Consolas',9)
$form.Controls.Add($incident)

. (Join-Path $PSScriptRoot 'lib\Updates.ps1')
. (Join-Path $PSScriptRoot 'lib\Hud.ps1')
Initialize-Hud
$hudButton=New-Object System.Windows.Forms.Button
$hudButton.Text='HUD (F9)'
$hudButton.Location=[Drawing.Point]::new(784,12)
$hudButton.Size=[Drawing.Size]::new(136,34)
$hudButton.FlatStyle=[System.Windows.Forms.FlatStyle]::Flat
$hudButton.ForeColor=[Drawing.Color]::White
$hudButton.BackColor=[Drawing.Color]::FromArgb(42,55,68)
$form.Controls.Add($hudButton)
$hudButton.Add_Click({Switch-ToHud})
$updatesButton=New-Object System.Windows.Forms.Button
$updatesButton.Text='Check updates'
$updatesButton.Location=[Drawing.Point]::new(626,12)
$updatesButton.Size=[Drawing.Size]::new(152,34)
$updatesButton.FlatStyle=[System.Windows.Forms.FlatStyle]::Flat
$updatesButton.ForeColor=[Drawing.Color]::White
$updatesButton.BackColor=[Drawing.Color]::FromArgb(42,55,68)
$form.Controls.Add($updatesButton)
$updatesButton.Add_Click({
    $updatesButton.Enabled=$false
    try {
        $currentVersion='0.5.0-LAB'
        $manifestPath=Join-Path $PSScriptRoot 'installation.json'
        if (Test-Path -LiteralPath $manifestPath) {
            try { $currentVersion=[string]((Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).version) } catch {}
        }
        $result=Get-DiagnosticsReleaseStatus -CurrentVersion $currentVersion
        if ($result.status -eq 'UPDATE_AVAILABLE') {
            $answer=[Windows.Forms.MessageBox]::Show(
                "New release $($result.version) found. Open the official GitHub release page? Automatic installation is disabled until signed updates and rollback are verified.",
                'ComfyUI Diagnostics Updates',
                [Windows.Forms.MessageBoxButtons]::YesNo,
                [Windows.Forms.MessageBoxIcon]::Information)
            if ($answer -eq [Windows.Forms.DialogResult]::Yes) {
                [void][Diagnostics.Process]::Start($result.url)
            }
        } elseif ($result.status -eq 'UP_TO_DATE') {
            [void][Windows.Forms.MessageBox]::Show("No newer published stable release. Current version: $currentVersion",'Updates')
        } else {
            [void][Windows.Forms.MessageBox]::Show('No verified update available. A network error or no published stable release may be the cause. Nothing was downloaded or installed.','Updates')
        }
    } catch {
        [void][Windows.Forms.MessageBox]::Show('Update check failed; no changes made.','Updates')
    } finally {
        $updatesButton.Enabled=$true
    }
})
$form.Add_KeyDown({param($sender,$e);if ($e.KeyCode -eq [Windows.Forms.Keys]::F9) { Switch-ToHud }})
$form.Add_Resize({
    if (-not $script:closing -and -not $script:hudVisible -and $script:form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) {
        Switch-ToHud
    }
})
function To-Metric([object]$value) {
    $number=0.0
    if ($null -eq $value) { return $null }
    if ([double]::TryParse(([string]$value),[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$number)) { return $number }
    return $null
}
function Update-Telemetry {
    $paths=@(Get-ChildItem -LiteralPath $DataDir -Filter ("telemetry_"+$Machine+"_*.jsonl") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($paths.Count -eq 0) { $status.Text='Collector: NO DATA | WebSocket: '+$script:wsState; return }
    $raw=@(Get-Content -LiteralPath $paths[0].FullName -Tail 120 -ErrorAction SilentlyContinue)
    $valid=@()
    foreach ($line in $raw) {
        try { $valid+=ConvertFrom-Json -InputObject $line -ErrorAction Stop } catch {}
    }
    if ($valid.Count -eq 0) { return }
    $current=$valid[-1]
    $stale=$true
    try { $stale=(([datetime]::UtcNow-[datetime]::Parse($current.timestamp_utc).ToUniversalTime()).TotalSeconds -gt 20) } catch {}
    $ws=$script:wsState
    $status.Text='Collector: '+$(if ($stale) { 'STALE' } else { 'ACTIVE' })+' | ComfyUI API: '+$current.comfy.status+' | WebSocket: '+$ws+' | '+$script:session
    if ($current.gpu.status -eq 'OK' -and $current.gpu.gpus.Count -gt 0) {
        $g=$current.gpu.gpus[0]
        $gpu.Text='GPU: '+$g.name+'  |  Load: '+$g.util_pct+'%'
        $used=To-Metric $g.vram_used_mib; $total=To-Metric $g.vram_total_mib
        $pct=if ($null -ne $used -and $total -gt 0) {[math]::Round(100*$used/$total,1)} else {0}
        $vram.Text='VRAM: '+$g.vram_used_mib+' / '+$g.vram_total_mib+' MiB ('+$pct+'%)'
        $temp.Text='Temperature: '+$g.temperature_c+' °C  |  Power: '+$g.power_w+' W  |  RAM: '+$current.ram.used_mib+' / '+$current.ram.total_mib+' MiB'
    }
    $node.Text='Active node: '+$script:activeNode
    if ($script:stepTotal -gt 0) {
        $pct=[math]::Min(100,[math]::Max(0,[math]::Round(100*$script:step/$script:stepTotal)))
        $progress.Value=[int]$pct
        $steps.Text="$($script:step) / $($script:stepTotal)"
    } else { $progress.Value=0; $steps.Text='Sampler: —' }
    foreach ($s in @($chart.Series)) { $s.Points.Clear() }
    foreach ($sample in $valid) {
        if ($sample.gpu.status -ne 'OK' -or $sample.gpu.gpus.Count -eq 0) { continue }
        $g=$sample.gpu.gpus[0]
        $load=To-Metric $g.util_pct; $used=To-Metric $g.vram_used_mib; $total=To-Metric $g.vram_total_mib
        if ($null -ne $load) { [void]$chart.Series['GPU %'].Points.AddY($load) }
        if ($null -ne $used -and $total -gt 0) { [void]$chart.Series['VRAM %'].Points.AddY((100*$used/$total)) }
    }
}
function Update-Incidents {
    $lines=@()
    foreach ($prefix in @('events','live')) {
        $paths=@(Get-ChildItem -LiteralPath $DataDir -Filter ($prefix+'_'+$Machine+'_*.jsonl') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2)
        foreach ($path in $paths) {
            foreach ($line in @(Get-Content -LiteralPath $path.FullName -Tail 45 -ErrorAction SilentlyContinue)) {
                try {
                    $item=ConvertFrom-Json -InputObject $line -ErrorAction Stop
                    $when=if ($item.time_utc) { $item.time_utc } else { $item.event_utc }
                    if ($prefix -eq 'events') { $detail=($item.provider+' / '+$item.code) }
                    else {
                        if ($item.type -notin @('execution_error','execution_interrupted','execution_success','execution_start')) { continue }
                        $detail=('ComfyUI '+$item.type+' '+$item.error_code)
                    }
                    $lines+=([pscustomobject]@{when=$when;display=("$when | $detail")})
                } catch {}
            }
        }
    }
    $incident.Text=(($lines | Sort-Object when -Descending | Select-Object -First 22 | ForEach-Object { $_.display }) -join [Environment]::NewLine)
}
$timer=New-Object Windows.Forms.Timer
$timer.Interval=1000
$timer.Add_Tick({
    try {
        Tick-WebSocket
        $script:ticks++
        if ($script:ticks % 3 -eq 0) { Update-Telemetry; Update-Incidents }
        if ($script:hudVisible) { $script:hud.Invalidate() }
    } catch { $status.Text='Monitor UI warning (see PowerShell console)' }
})
# Keep the WinForms message loop alive when the main window is hidden for HUD.
# ShowDialog() exits on Hide(), causing the PowerShell process to terminate.
$script:tray=New-Object System.Windows.Forms.NotifyIcon
$script:tray.Icon=[Drawing.SystemIcons]::Application
$script:tray.Text='ComfyUI Diagnostics HOME/WORK - restore'
$script:tray.Visible=$true
$trayMenu=New-Object System.Windows.Forms.ContextMenuStrip
$restoreItem=$trayMenu.Items.Add('Restore Dashboard')
$exitItem=$trayMenu.Items.Add('Exit Dashboard')
$restoreItem.Add_Click({ Switch-ToFullDashboard })
$exitItem.Add_Click({ $script:form.Close() })
$script:tray.ContextMenuStrip=$trayMenu
$script:tray.Add_DoubleClick({ Switch-ToFullDashboard })
$form.Add_FormClosing({
    $script:closing=$true
    $timer.Stop()
    $script:tray.Visible=$false
    $script:tray.Dispose()
    $trayMenu.Dispose()
    Safe-Disconnect
    $script:hud.Close()
    $script:hud.Dispose()
    $script:message.Dispose()
})
if ($SelfTest) {
    if (-not $form.TopMost -or -not $script:hud.TopMost -or $script:hud.TransparencyKey -ne [Drawing.Color]::Magenta) { throw 'HUD configuration FAILED' }
    $timer.Dispose()
    $script:tray.Visible=$false
    $script:tray.Dispose()
    $trayMenu.Dispose()
    $script:hud.Dispose()
    $form.Dispose()
    $script:message.Dispose()
    Write-Host 'PASS: WinForms Dashboard controls created'
    return
}
if ($HudSelfTest) {
    # Windows CI regression: switch windows while application message loop remains alive.
    $script:hudTestPhase=0
    $script:hudTestResult='FAIL: HUD message-loop smoke test never finished'
    $script:hudTestTimer=New-Object System.Windows.Forms.Timer
    $script:hudTestTimer.Interval=300
    $script:hudTestTimer.Add_Tick({
        try {
            $script:hudTestPhase++
            if ($script:hudTestPhase -eq 1) {
                Switch-ToHud
                if (-not $script:hudVisible -or -not $script:hud.Visible -or $script:form.Visible) { throw 'HUD transition failed' }
            } elseif ($script:hudTestPhase -eq 2) {
                Switch-ToFullDashboard
                if ($script:hudVisible -or -not $script:form.Visible) { throw 'Dashboard restore failed' }
                $script:hudTestResult='PASS: HUD hide/restore maintained WinForms message loop'
                $script:hudTestTimer.Stop()
                $script:form.Close()
            }
        } catch {
            $script:hudTestResult='FAIL: '+$_.Exception.Message
            $script:hudTestTimer.Stop()
            $script:form.Close()
        }
    })
    $script:hudTestTimer.Start()
}
$timer.Start()
# ApplicationContext preserves process lifetime while Dashboard is hidden.
$context=New-Object System.Windows.Forms.ApplicationContext($form)
[System.Windows.Forms.Application]::Run($context)
if ($HudSelfTest) {
    $script:hudTestTimer.Dispose()
    if (-not $script:hudTestResult.StartsWith('PASS:')) { throw $script:hudTestResult }
    Write-Host $script:hudTestResult
}
