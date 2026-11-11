# v0.9 LAB: single-window Windows Forms UI. Collector runs in an in-process runspace.
# Read-only by default; no ComfyUI mutation, GPU reset or automatic cache clearing.
[CmdletBinding()]
param(
    [ValidateSet('HOME','WORK')][string]$Machine='HOME',
    [string]$DataDir=(Join-Path $env:LOCALAPPDATA 'ComfyUI-Diagnostics'),
    [string]$ComfyUrl='http://127.0.0.1:8188',
    [string]$ComfyLog='',
    [switch]$SelfTest
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization
. (Join-Path $PSScriptRoot 'lib\ComfyWs.ps1')
. (Join-Path $PSScriptRoot 'lib\Updates.ps1')
$endpoint=[uri]$ComfyUrl
if ($endpoint.Scheme -ne 'http' -or $endpoint.Host -notin @('localhost','127.0.0.1','::1') -or $endpoint.UserInfo) {
    throw 'STOP: ComfyUI endpoint must be unauthenticated localhost HTTP'
}
$null=New-Item -ItemType Directory -Path $DataDir -Force
$uiFile=Join-Path $DataDir 'ui-settings.json'
$language='ru'
if (Test-Path -LiteralPath $uiFile) {
    try { $p=Get-Content -LiteralPath $uiFile -Raw | ConvertFrom-Json; if ($p.language -in @('ru','en')) {$language=$p.language} } catch {}
}
$script:lang=$language
$script:collectorState='ОЖИДАНИЕ'
$script:collectorPS=$null
$script:collectorRunspace=$null
$script:collectorMutex=$null
$script:collectorOwned=$false
$script:collectorAsync=$null
$script:closing=$false
$script:wsState='DISCONNECTED'
$script:socket=$null
$script:connectTask=$null
$script:connectCts=$null
$script:receiveTask=$null
$script:wsBuffer=New-Object byte[] 65536
$script:wsMessage=New-Object IO.MemoryStream
$script:wsSkip=$false
$script:lastAttempt=[datetime]::MinValue
$script:activeNode='-'
$script:step=0
$script:stepTotal=0
$script:session='Idle'
$script:queueRemaining=$null
$script:currentPrompt=''
$script:captureJob=$null
$script:updateJob=$null
$script:ticks=0

function Translate([string]$ru,[string]$en) {
    if ($script:lang -eq 'ru') { return $ru }
    return $en
}
$back=[Drawing.Color]::FromArgb(23,25,28)
$card=[Drawing.Color]::FromArgb(42,46,51)
$navOff=[Drawing.Color]::FromArgb(31,34,38)
$text=[Drawing.Color]::FromArgb(234,237,241)
$muted=[Drawing.Color]::FromArgb(165,176,186)
$stroke=[Drawing.Color]::FromArgb(64,70,77)
$yellow=[Drawing.Color]::FromArgb(244,184,62)
$green=[Drawing.Color]::FromArgb(80,198,137)
$form=New-Object Windows.Forms.Form
$script:form=$form
$form.Text="Diagnostics Monitor | $Machine | 0.9.0-LAB"
$form.Size=[Drawing.Size]::new(1080,800)
$form.MinimumSize=[Drawing.Size]::new(940,710)
$form.AutoScaleMode=[Windows.Forms.AutoScaleMode]::Font
$form.StartPosition='CenterScreen'
$form.BackColor=$back
$form.ForeColor=$text
$form.Font=[Drawing.Font]::new('Segoe UI',10)
$form.KeyPreview=$true

function New-Text([Windows.Forms.Control]$parent,[int]$x,[int]$y,[int]$w,[int]$h,[string]$value,[int]$size=10,[switch]$bold) {
    $o=New-Object Windows.Forms.Label
    $o.Location=[Drawing.Point]::new($x,$y)
    $o.Size=[Drawing.Size]::new($w,$h)
    $o.Text=$value
    $style=if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}
    $o.Font=[Drawing.Font]::new('Segoe UI',$size,$style)
    $o.ForeColor=$text
    $o.AutoEllipsis=$true
    $parent.Controls.Add($o)
    return $o
}
function New-Button([Windows.Forms.Control]$parent,[string]$caption,[int]$x,[int]$y,[int]$w,[int]$h,[switch]$primary) {
    $o=New-Object Windows.Forms.Button
    $o.Location=[Drawing.Point]::new($x,$y)
    $o.Size=[Drawing.Size]::new($w,$h)
    $o.Text=$caption
    $o.FlatStyle=[Windows.Forms.FlatStyle]::Flat
    $o.FlatAppearance.BorderSize=1
    $o.FlatAppearance.BorderColor=$stroke
    $o.BackColor=if($primary){$yellow}else{$card}
    $o.ForeColor=if($primary){$back}else{$text}
    $o.Cursor=[Windows.Forms.Cursors]::Hand
    $parent.Controls.Add($o)
    return $o
}
$headline=New-Text $form 22 14 720 35 'Diagnostics Monitor' 19 -bold
$subline=New-Text $form 24 52 800 24 '' 10
$subline.ForeColor=$muted
$version=New-Text $form 925 20 130 26 'v0.9 LAB' 10
$version.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Right
$navLabels=@('Монитор','Генерации','Диагностика','Настройки')
$navEnglish=@('Monitor','Generations','Diagnostics','Settings')
$script:nav=@()
$script:pages=@()
for ($i=0;$i -lt 4;$i++) {
    $button=New-Button $form $navLabels[$i] (22+$i*256) 88 248 40
    $button.Tag=$i
    $button.Add_Click({Show-Page ([int]$this.Tag)})
    $script:nav+=,$button
    $page=New-Object Windows.Forms.Panel
    $page.Location=[Drawing.Point]::new(22,147)
    $page.Size=[Drawing.Size]::new(1028,585)
    $page.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Bottom -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $page.BackColor=$back
    $page.Visible=$false
    $form.Controls.Add($page)
    $script:pages+=,$page
}
function Show-Page([int]$n) {
    for($i=0;$i -lt $script:pages.Count;$i++) {
        $script:pages[$i].Visible=($i -eq $n)
        $script:nav[$i].BackColor=if($i -eq $n){$card}else{$navOff}
        $script:nav[$i].FlatAppearance.BorderColor=if($i -eq $n){$yellow}else{$stroke}
    }
    $script:pages[$n].BringToFront()
}
$monitor=$script:pages[0]
$generations=$script:pages[1]
$evidencePage=$script:pages[2]
$settings=$script:pages[3]
$monitorTitle=New-Text $monitor 10 3 330 30 'Обзор системы' 14 -bold
$collectorStatus=New-Text $monitor 525 5 490 27 'Сбор: ожидание' 10
$collectorStatus.TextAlign=[Drawing.ContentAlignment]::MiddleRight
$collectorStatus.ForeColor=$muted
$collectorStatus.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Right
$cards=@()
$names=@('GPU','VRAM','CPU','RAM')
$colors=@([Drawing.Color]::DeepSkyBlue,[Drawing.Color]::Orange,$green,[Drawing.Color]::MediumPurple)
foreach($i in 0..3) {
    $panel=New-Object Windows.Forms.Panel
    $panel.Location=[Drawing.Point]::new((10+$i*251),43)
    $panel.Size=[Drawing.Size]::new(242,122)
    $panel.BackColor=$card
    $monitor.Controls.Add($panel)
    $label=New-Text $panel 14 10 210 24 $names[$i] 10
    $label.ForeColor=$muted
    $value=New-Text $panel 14 43 214 48 '—' 25 -bold
    $value.ForeColor=$colors[$i]
    $cards+=,$value
}
$script:gpu=New-Text $monitor 10 175 485 24 'GPU: —  |  VRAM: —' 10
$script:vram=New-Text $monitor 499 175 500 24 '3ds Max: —  |  ComfyUI: —' 10
$script:gpu.ForeColor=[Drawing.Color]::DeepSkyBlue
$script:vram.ForeColor=$muted
$chart=New-Object Windows.Forms.DataVisualization.Charting.Chart
$script:chart=$chart
$chart.Location=[Drawing.Point]::new(10,210)
$chart.Size=[Drawing.Size]::new(1002,220)
$chart.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$chart.BackColor=$card
$area=New-Object Windows.Forms.DataVisualization.Charting.ChartArea 'Metrics'
$area.BackColor=$card
$area.AxisY.Minimum=0
$area.AxisY.Maximum=100
$area.AxisY.LabelStyle.ForeColor=$muted
$area.AxisY.MajorGrid.LineColor=$stroke
$area.AxisX.LabelStyle.Enabled=$false
$area.AxisX.MajorGrid.Enabled=$false
$chart.ChartAreas.Add($area)
foreach($i in 0..3) {
    $key=$names[$i]+' %'
    $series=New-Object Windows.Forms.DataVisualization.Charting.Series $key
    $series.ChartType=[Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    $series.BorderWidth=2
    $series.Color=$colors[$i]
    [void]$chart.Series.Add($series)
}
$legend=New-Object Windows.Forms.DataVisualization.Charting.Legend
$legend.BackColor=$card
$legend.ForeColor=$text
$legend.Font=[Drawing.Font]::new('Consolas',9)
$legend.Docking=[Windows.Forms.DataVisualization.Charting.Docking]::Right
$chart.Legends.Add($legend)
$monitor.Controls.Add($chart)
$incidentTitle=New-Text $monitor 10 443 550 27 'Последние события' 11 -bold
$incident=New-Object Windows.Forms.TextBox
$incident.Location=[Drawing.Point]::new(10,478)
$incident.Size=[Drawing.Size]::new(1002,90)
$incident.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Bottom -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$incident.Multiline=$true
$incident.ReadOnly=$true
$incident.ScrollBars='Vertical'
$incident.BackColor=$card
$incident.ForeColor=$text
$incident.Font=[Drawing.Font]::new('Consolas',9)
$monitor.Controls.Add($incident)

$genTitle=New-Text $generations 10 4 550 32 'Текущая генерация' 14 -bold
$genStatus=New-Text $generations 750 4 250 30 'ОЖИДАНИЕ' 11 -bold
$genStatus.TextAlign=[Drawing.ContentAlignment]::MiddleRight
$genStatus.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Right
$genPanel=New-Object Windows.Forms.Panel
$genPanel.BackColor=$card
$genPanel.Location=[Drawing.Point]::new(10,48)
$genPanel.Size=[Drawing.Size]::new(1002,150)
$genPanel.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$generations.Controls.Add($genPanel)
$nodeCaption=New-Text $genPanel 16 18 220 26 'Активная нода' 10
$nodeValue=New-Text $genPanel 245 18 700 26 '—' 12 -bold
$progressCaption=New-Text $genPanel 16 54 220 26 'Шаги генерации' 10
$progressValue=New-Text $genPanel 245 54 700 26 '—' 11
$bar=New-Object Windows.Forms.ProgressBar
$bar.Location=[Drawing.Point]::new(16,100)
$bar.Size=[Drawing.Size]::new(966,22)
$bar.Maximum=100
$bar.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$genPanel.Controls.Add($bar)
$historyTitle=New-Text $generations 10 216 680 29 'События генераций (без промптов)' 12 -bold
$history=New-Object Windows.Forms.TextBox
$history.Location=[Drawing.Point]::new(10,252)
$history.Size=[Drawing.Size]::new(1002,246)
$history.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Bottom -bor [Windows.Forms.AnchorStyles]::Right
$history.Multiline=$true
$history.ReadOnly=$true
$history.ScrollBars='Vertical'
$history.Font=[Drawing.Font]::new('Consolas',10)
$history.BackColor=$card
$history.ForeColor=$text
$generations.Controls.Add($history)
$privacy=New-Text $generations 10 516 990 44 'Личные промпты не сохраняются автоматически. История показывает только нормализованные события ComfyUI.' 10
$privacy.ForeColor=$muted

$evTitle=New-Text $evidencePage 10 3 650 34 'Центр диагностики' 14 -bold
$evDescription=New-Text $evidencePage 10 46 940 30 'Локальный отчёт JSON без автоматической отправки.' 10
$evDescription.ForeColor=$muted
$historyCaption=New-Text $evidencePage 10 88 240 24 'Период событий (часы)' 10
$hours=New-Object Windows.Forms.NumericUpDown
$hours.Location=[Drawing.Point]::new(270,85)
$hours.Size=[Drawing.Size]::new(100,27)
$hours.Minimum=1; $hours.Maximum=24; $hours.Value=3
$hours.BackColor=$card; $hours.ForeColor=$text
$evidencePage.Controls.Add($hours)
$checks=@()
foreach($entry in @('События Windows / WER','Процессы и память','Накопители','ComfyUI API и подписи логов')) {
    $i=$checks.Count
    $cb=New-Object Windows.Forms.CheckBox
    $cb.Text=$entry
    $cb.Checked=$true
    $cb.Location=[Drawing.Point]::new(12,(137+$i*43))
    $cb.Size=[Drawing.Size]::new(850,32)
    $cb.ForeColor=$text
    $evidencePage.Controls.Add($cb)
    $checks+=,$cb
}
$rawWarning=New-Text $evidencePage 10 319 960 47 'RAW-логи и промпты по умолчанию не включаются в отчёт.' 10
$rawWarning.ForeColor=$yellow
$capture=New-Button $evidencePage 'Собрать отчёт' 10 384 200 43 -primary
$openEvidence=New-Button $evidencePage 'Открыть отчёты' 224 384 220 43
$openLogs=New-Button $evidencePage 'Открыть логи' 458 384 200 43
$evStatus=New-Text $evidencePage 10 453 978 75 'Готово к сбору отчёта.' 10
$evStatus.ForeColor=$muted

$settingsTitle=New-Text $settings 10 3 650 34 'Настройки приложения' 14 -bold
$langLabel=New-Text $settings 12 60 250 30 'Язык интерфейса' 11
$langBox=New-Object Windows.Forms.ComboBox
$langBox.Location=[Drawing.Point]::new(286,60)
$langBox.Size=[Drawing.Size]::new(220,31)
$langBox.DropDownStyle=[Windows.Forms.ComboBoxStyle]::DropDownList
$langBox.BackColor=$card
$langBox.ForeColor=$text
[void]$langBox.Items.Add('Русский')
[void]$langBox.Items.Add('English')
$langBox.SelectedIndex=if($script:lang -eq 'ru'){0}else{1}
$settings.Controls.Add($langBox)
$machineLabel=New-Text $settings 12 128 670 28 "Компьютер: $Machine" 11
$folderLabel=New-Text $settings 12 180 980 55 "Диагностические файлы: $DataDir" 10
$folderLabel.ForeColor=$muted
$updateButton=New-Button $settings 'Проверить обновления' 12 260 265 44
$updateStatus=New-Text $settings 12 320 980 55 'Проверка доступных версий выполняется отдельно от обновления приложения.' 10
$updateStatus.ForeColor=$muted
$cacheTitle=New-Text $settings 12 412 600 30 'Управление памятью' 12 -bold
$cacheButton=New-Button $settings 'Очистить кэш ComfyUI' 12 456 300 43
$cacheButton.Enabled=$false
$cacheHelp=New-Text $settings 12 509 980 50 'Заблокировано до подтверждения безопасной операции при простое ComfyUI.' 10
$cacheHelp.ForeColor=$yellow

function Apply-Language {
    $ru=$script:lang -eq 'ru'
    for($i=0;$i -lt 4;$i++) { $script:nav[$i].Text=if($ru){$navLabels[$i]}else{$navEnglish[$i]} }
    $monitorTitle.Text=Translate 'Обзор системы' 'System Overview'
    $genTitle.Text=Translate 'Текущая генерация' 'Current generation'
    $nodeCaption.Text=Translate 'Активная нода' 'Active node'
    $progressCaption.Text=Translate 'Шаги генерации' 'Generation steps'
    $historyTitle.Text=Translate 'События генераций (без промптов)' 'Generation events (no prompts)'
    $privacy.Text=Translate 'Личные промпты не сохраняются автоматически. История содержит только нормализованные события.' 'Private prompts are not stored automatically. History contains only normalized events.'
    $incidentTitle.Text=Translate 'Последние события' 'Recent events'
    $evTitle.Text=Translate 'Центр диагностики' 'Diagnostics center'
    $evDescription.Text=Translate 'Локальный отчёт JSON без автоматической отправки.' 'Local JSON report; no automatic upload.'
    $historyCaption.Text=Translate 'Период событий (часы)' 'Event history (hours)'
    $checks[0].Text=Translate 'События Windows / WER' 'Windows Events / WER'
    $checks[1].Text=Translate 'Процессы и память' 'Processes and memory'
    $checks[2].Text=Translate 'Накопители' 'Storage capacity'
    $checks[3].Text=Translate 'ComfyUI API и подписи логов' 'ComfyUI API and log signatures'
    $rawWarning.Text=Translate 'RAW-логи и промпты по умолчанию не включаются в отчёт.' 'RAW logs and prompts are excluded by default.'
    $capture.Text=Translate 'Собрать отчёт' 'Capture evidence'
    $openEvidence.Text=Translate 'Открыть отчёты' 'Open reports'
    $openLogs.Text=Translate 'Открыть логи' 'Open logs'
    $settingsTitle.Text=Translate 'Настройки приложения' 'Application settings'
    $langLabel.Text=Translate 'Язык интерфейса' 'Interface language'
    $machineLabel.Text=(Translate 'Компьютер: ' 'Machine: ')+$Machine
    $folderLabel.Text=(Translate 'Диагностические файлы: ' 'Diagnostics folder: ')+$DataDir
    $updateButton.Text=Translate 'Проверить обновления' 'Check updates'
    $cacheTitle.Text=Translate 'Управление памятью' 'Memory management'
    $cacheButton.Text=Translate 'Очистить кэш ComfyUI' 'Clear ComfyUI cache'
    $cacheHelp.Text=Translate 'Заблокировано до подтверждения безопасной операции при простое ComfyUI.' 'Disabled until a safe idle-only operation is verified.'
    $subline.Text=(Translate 'Локальный мониторинг · ' 'Local monitoring · ')+$Machine
}
$langBox.Add_SelectedIndexChanged({
    $script:lang=if($langBox.SelectedIndex -eq 0){'ru'}else{'en'}
    Apply-Language
    $obj=@{schema=1;language=$script:lang}
    [IO.File]::WriteAllText($uiFile,($obj|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
})
function Open-Data([string]$path) {
    $null=New-Item -ItemType Directory -Path $path -Force
    [void][Diagnostics.Process]::Start('explorer.exe',('"'+$path+'"'))
}
$openLogs.Add_Click({ Open-Data $DataDir })
$openEvidence.Add_Click({ Open-Data (Join-Path $DataDir 'evidence') })
$capture.Add_Click({
    if ($null -ne $script:captureJob) { return }
    $capture.Enabled=$false
    $evStatus.Text=Translate 'Сбор отчёта...' 'Capturing evidence...'
    $args=@{
        Machine=$Machine;DataRoot=$DataDir;ComfyLog=$ComfyLog;Hours=[int]$hours.Value;
        SkipWindows=(-not $checks[0].Checked);SkipProcesses=(-not $checks[1].Checked);
        SkipStorage=(-not $checks[2].Checked);SkipComfy=(-not $checks[3].Checked)
    }
    $script:captureJob=Start-Job -ScriptBlock {
        param($path,$params)
        & $path @params
        if (-not $?) { throw 'Evidence script failed' }
    } -ArgumentList (Join-Path $PSScriptRoot 'evidence.ps1'),$args
})
$updateButton.Add_Click({
    $result=Get-DiagnosticsReleaseStatus -CurrentVersion '0.9.0-LAB'
    if($result.status -eq 'UPDATE_AVAILABLE') {
        $confirm=[Windows.Forms.MessageBox]::Show(
            (Translate 'Открыть официальный релиз для ручного обновления?' 'Open the official release for manual update?'),
            'Diagnostics Monitor',[Windows.Forms.MessageBoxButtons]::YesNo)
        if($confirm -eq [Windows.Forms.DialogResult]::Yes) { [void][Diagnostics.Process]::Start($result.url) }
    } else {
        $updateStatus.Text=if($result.status -eq 'UP_TO_DATE') {
            Translate 'Новых релизов нет.' 'No newer release.'
        } else { Translate 'Нет проверенных данных о релизе.' 'Release status unavailable.' }
    }
})
function Start-ManagedCollector {
    if ($SelfTest) { return }
    $script:collectorMutex=New-Object System.Threading.Mutex($false,('Local\OVizLAB_Diagnostics_Collector_'+$Machine))
    $script:collectorOwned=$script:collectorMutex.WaitOne(0)
    if (-not $script:collectorOwned) { $script:collectorState='ALREADY RUNNING'; return }
    try {
        $script:collectorRunspace=[RunspaceFactory]::CreateRunspace()
        $script:collectorRunspace.ApartmentState=[Threading.ApartmentState]::MTA
        $script:collectorRunspace.ThreadOptions=[Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
        $script:collectorRunspace.Open()
        $script:collectorPS=[PowerShell]::Create()
        $script:collectorPS.Runspace=$script:collectorRunspace
        $null=$script:collectorPS.AddCommand((Join-Path $PSScriptRoot 'collector.ps1')).
            AddParameter('Machine',$Machine).
            AddParameter('DataDir',$DataDir).
            AddParameter('ComfyLog',$ComfyLog).
            AddParameter('ComfyUrl',$ComfyUrl)
        $script:collectorAsync=$script:collectorPS.BeginInvoke()
        $script:collectorState='STARTED'
    } catch {
        $script:collectorState='START FAILED'
        if($null -ne $script:collectorPS){$script:collectorPS.Dispose();$script:collectorPS=$null}
        if($null -ne $script:collectorRunspace){$script:collectorRunspace.Dispose();$script:collectorRunspace=$null}
        if($script:collectorOwned){$script:collectorMutex.ReleaseMutex();$script:collectorOwned=$false}
    }
}
function Stop-ManagedCollector {
    if($null -ne $script:collectorPS) {
        try { $script:collectorPS.Stop() } catch {}
        $script:collectorPS.Dispose()
        $script:collectorPS=$null
    }
    if($null -ne $script:collectorRunspace){$script:collectorRunspace.Dispose();$script:collectorRunspace=$null}
    if($script:collectorOwned){$script:collectorMutex.ReleaseMutex();$script:collectorOwned=$false}
    if($null -ne $script:collectorMutex){$script:collectorMutex.Dispose();$script:collectorMutex=$null}
}
function Disconnect-Comfy {
    if($null -ne $script:connectCts){try{$script:connectCts.Cancel()}catch{};$script:connectCts.Dispose();$script:connectCts=$null}
    if($null -ne $script:socket){try{$script:socket.Abort()}catch{};$script:socket.Dispose();$script:socket=$null}
    $script:connectTask=$null
    $script:receiveTask=$null
    $script:wsMessage.SetLength(0)
    $script:wsSkip=$false
    $script:wsState='DISCONNECTED'
}
function Write-LiveEvent($item) {
    $path=Join-Path $DataDir ('live_'+$Machine+'_'+(Get-Date -Format 'yyyyMMdd')+'.jsonl')
    if((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -ge 5MB){return}
    $obj=[ordered]@{
        schema=1;machine=$Machine;source='ComfyUI';time_utc=[datetime]::UtcNow.ToString('o');
        type=$item.type;node=$item.node;prompt_id=$item.prompt_id;
        current=$item.current;total=$item.total;error_code=$item.error_code;queue_remaining=$item.queue_remaining
    }
    [IO.File]::AppendAllText($path,((ConvertTo-Json $obj -Compress)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
}
function Handle-ComfyEvent([string]$json) {
    $item=ConvertFrom-ComfyWsEvent -Json $json
    if($null -eq $item){return}
    switch($item.type) {
        'execution_start' { $script:session='Running';$script:activeNode='-';$script:step=0;$script:stepTotal=0 }
        'executing' {
            if([string]::IsNullOrWhiteSpace($item.node)){$script:session='Idle';$script:activeNode='-'}
            else {$script:session='Running';$script:activeNode=$item.node}
            $script:step=0;$script:stepTotal=0
        }
        'progress' {$script:step=$item.current;$script:stepTotal=$item.total;$script:session='Running'}
        'execution_success' {$script:session='Completed';$script:activeNode='-'}
        'execution_error' {$script:session='ERROR';$script:activeNode='-'}
        'execution_interrupted' {$script:session='Interrupted';$script:activeNode='-'}
        'status' {if($null -ne $item.queue_remaining){$script:queueRemaining=$item.queue_remaining}}
    }
    if($item.type -ne 'status') { Write-LiveEvent $item }
}
function Tick-Comfy {
    if($script:closing){return}
    if($null -eq $script:socket) {
        if(((Get-Date)-$script:lastAttempt).TotalSeconds -lt 5){return}
        $script:lastAttempt=Get-Date
        try {
            $script:socket=[Net.WebSockets.ClientWebSocket]::new()
            $script:connectCts=[Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(3))
            $url='ws://'+$endpoint.Authority+'/ws?clientId='+[guid]::NewGuid().ToString()
            $script:connectTask=$script:socket.ConnectAsync([uri]$url,$script:connectCts.Token)
            $script:wsState='CONNECTING'
        } catch { Disconnect-Comfy }
        return
    }
    if($null -ne $script:connectTask) {
        if(-not $script:connectTask.IsCompleted){return}
        try {
            $script:connectTask.GetAwaiter().GetResult()
            $script:connectTask=$null
            $script:wsState='CONNECTED'
            if($null -ne $script:connectCts){$script:connectCts.Dispose();$script:connectCts=$null}
        } catch {Disconnect-Comfy;return}
    }
    if($script:socket.State -ne [Net.WebSockets.WebSocketState]::Open){Disconnect-Comfy;return}
    if($null -eq $script:receiveTask) {
        try {
            $segment=[ArraySegment[byte]]::new($script:wsBuffer)
            $script:receiveTask=$script:socket.ReceiveAsync($segment,[Threading.CancellationToken]::None)
        } catch {Disconnect-Comfy}
        return
    }
    if(-not $script:receiveTask.IsCompleted){return}
    try {
        $res=$script:receiveTask.GetAwaiter().GetResult()
        $script:receiveTask=$null
        if($res.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close){Disconnect-Comfy;return}
        if($res.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Binary){$script:wsSkip=$true}
        if(-not $script:wsSkip -and $res.Count -gt 0) {
            if($script:wsMessage.Length+$res.Count -gt 131072){$script:wsSkip=$true}
            else {$script:wsMessage.Write($script:wsBuffer,0,$res.Count)}
        }
        if($res.EndOfMessage){
            if(-not $script:wsSkip){Handle-ComfyEvent ([Text.Encoding]::UTF8.GetString($script:wsMessage.ToArray()))}
            $script:wsMessage.SetLength(0)
            $script:wsSkip=$false
        }
    } catch {Disconnect-Comfy}
}
function Number([object]$x){
    [double]$v=0
    if($null -ne $x -and [double]::TryParse(([string]$x),[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$v)){return $v}
    return $null
}
function Update-Monitor {
    $files=@(Get-ChildItem -LiteralPath $DataDir -Filter ('telemetry_'+$Machine+'_*.jsonl') -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending)
    if($files.Count -eq 0){$collectorStatus.Text=Translate 'Сбор: нет данных' 'Collector: no data';return}
    $valid=@()
    foreach($line in @(Get-Content -LiteralPath $files[0].FullName -Tail 90 -ErrorAction SilentlyContinue)){
        try{$valid+=ConvertFrom-Json -InputObject $line -ErrorAction Stop}catch{}
    }
    if($valid.Count -eq 0){$collectorStatus.Text=Translate 'Сбор: нет записей' 'Collector: no records';return}
    $sample=$valid[-1]
    $stale=$true
    try{$stale=(([datetime]::UtcNow-[datetime]::Parse($sample.timestamp_utc).ToUniversalTime()).TotalSeconds -gt 20)}catch{}
    $collectorStatus.Text=if($stale){Translate 'Сбор: устаревшие данные' 'Collector: stale'}else{Translate 'Сбор активен' 'Collector active'}
    $collectorStatus.ForeColor=if($stale){$yellow}else{$green}
    $names=@('GPU','VRAM','CPU','RAM')
    foreach($name in $names){$chart.Series[$name+' %'].Points.Clear();$chart.Series[$name+' %'].LegendText=('{0,-7}{1,6}' -f ($name+' %'),'--')}
    $latest=@($null,$null,$null,$null)
    foreach($entry in $valid) {
        $metrics=@($null,$null,$null,$null)
        if($null -ne $entry.gpu -and $entry.gpu.status -eq 'OK' -and @($entry.gpu.gpus).Count -gt 0) {
            $g=$entry.gpu.gpus[0]
            $metrics[0]=Number $g.util_pct
            $used=Number $g.vram_used_mib;$total=Number $g.vram_total_mib
            if($null -ne $used -and $total -gt 0){$metrics[1]=100*$used/$total}
        }
        if($null -ne $entry.cpu -and $entry.cpu.status -eq 'OK'){$metrics[2]=Number $entry.cpu.util_pct}
        $usedRam=Number $entry.ram.used_mib;$totalRam=Number $entry.ram.total_mib
        if($null -ne $usedRam -and $totalRam -gt 0){$metrics[3]=100*$usedRam/$totalRam}
        for($i=0;$i -lt 4;$i++) {if($null -ne $metrics[$i]){[void]$chart.Series[$names[$i]+' %'].Points.AddY($metrics[$i])}}
        $latest=$metrics
    }
    for($i=0;$i -lt 4;$i++){
        if($null -ne $latest[$i]){
            $formatted=('{0:0.0}%' -f $latest[$i])
            $cards[$i].Text=$formatted
            $chart.Series[$names[$i]+' %'].LegendText=('{0,-7}{1,6}' -f ($names[$i]+' %'),$formatted)
        } else {$cards[$i].Text='—'}
    }
    $maxText='—'
    if($null -ne $sample.max_memory) {
        if($sample.max_memory.status -eq 'NOT_RUNNING'){$maxText=Translate 'не запущен' 'not running'}
        elseif($sample.max_memory.status -eq 'OK'){
            $ws=Number $sample.max_memory.working_set_mib
            if($null -ne $ws){$maxText=('{0:0.0} GiB' -f ($ws/1024))}
        }
    }
    $script:gpu.Text=('GPU: '+$cards[0].Text+'  |  VRAM: '+$cards[1].Text)
    $script:vram.Text=('3ds Max: '+$maxText+'  |  ComfyUI: '+$sample.comfy.status)
}
function Update-Events {
    $lines=@()
    foreach($prefix in @('events','live')){
        $files=@(Get-ChildItem -LiteralPath $DataDir -Filter ($prefix+'_'+$Machine+'_*.jsonl') -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 2)
        foreach($file in $files){
            foreach($line in @(Get-Content -LiteralPath $file.FullName -Tail 30 -ErrorAction SilentlyContinue)){
                try{
                    $ev=ConvertFrom-Json -InputObject $line -ErrorAction Stop
                    $when=if($ev.time_utc){$ev.time_utc}else{$ev.event_utc}
                    $desc=if($prefix -eq 'events'){([string]$ev.provider+' / '+$ev.code)}else{('ComfyUI '+$ev.type+' '+$ev.node)}
                    $lines+=,[pscustomobject]@{time=$when;line=($when+' | '+$desc)}
                }catch{}
            }
        }
    }
    $sorted=@($lines | Sort-Object time -Descending | Select-Object -First 16)
    $incident.Text=($sorted | ForEach-Object {$_.line}) -join [Environment]::NewLine
    $recent=@()
    foreach($file in @(Get-ChildItem -LiteralPath $DataDir -Filter ('live_'+$Machine+'_*.jsonl') -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 2)) {
        foreach($line in @(Get-Content -LiteralPath $file.FullName -Tail 50 -ErrorAction SilentlyContinue)) {
            try{$e=ConvertFrom-Json -InputObject $line;$recent+=,[pscustomobject]@{time=$e.time_utc;line=($e.time_utc+' | '+$e.type+' | node '+$e.node)}}catch{}
        }
    }
    $history.Text=(@($recent|Sort-Object time -Descending|Select-Object -First 25|ForEach-Object{$_.line}) -join [Environment]::NewLine)
}
function Update-Generation {
    $genStatus.Text=if($script:wsState -ne 'CONNECTED'){Translate 'НЕ ПОДКЛЮЧЁН' 'DISCONNECTED'}else{$script:session.ToUpperInvariant()}
    $nodeValue.Text=$script:activeNode
    if($script:stepTotal -gt 0) {
        $pct=[math]::Max(0,[math]::Min(100,[math]::Round(100*$script:step/$script:stepTotal)))
        $bar.Value=[int]$pct
        $progressValue.Text="$($script:step) / $($script:stepTotal)  ($pct%)"
    }else{$bar.Value=0;$progressValue.Text='—'}
}
$script:tick=New-Object Windows.Forms.Timer
$script:tick.Interval=1000
$script:tick.Add_Tick({
    try{Tick-Comfy}catch{}
    $script:ticks++
    if($script:ticks % 3 -eq 0) {
        try{Update-Monitor;Update-Events;Update-Generation}catch{$collectorStatus.Text=Translate 'Ошибка обновления UI' 'UI update error'}
    }
    if($script:hudVisible){$script:hud.Invalidate()}
    if($null -ne $script:captureJob -and $script:captureJob.State -in @('Completed','Failed','Stopped')){
        $out=@(Receive-Job -Job $script:captureJob -ErrorAction SilentlyContinue)
        $bad=$script:captureJob.State -ne 'Completed'
        if($bad){$evStatus.Text=Translate 'Ошибка сбора: проверьте журнал' 'Capture failed: check job log'}
        else {
            $snap=@(Get-ChildItem -LiteralPath (Join-Path $DataDir 'evidence') -Filter 'evidence_*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)
            $evStatus.Text=if($snap.Count -gt 0){'PASS: '+$snap[0].Name}else{Translate 'Отчёт не найден' 'Evidence file not found'}
        }
        Remove-Job -Job $script:captureJob -Force -ErrorAction SilentlyContinue
        $script:captureJob=$null
        $capture.Enabled=$true
    }
})
. (Join-Path $PSScriptRoot 'lib\Hud.ps1')
$script:appIcon=$null
$iconPath=Join-Path $PSScriptRoot 'app.ico'
if(Test-Path -LiteralPath $iconPath){try{$script:appIcon=[Drawing.Icon]::new($iconPath);$form.Icon=$script:appIcon}catch{}}
Initialize-Hud
$form.Add_KeyDown({param($sender,$e);if($e.KeyCode -eq [Windows.Forms.Keys]::F9){Switch-ToHud}})
$form.Add_Resize({if(-not $script:closing -and -not $script:hudVisible -and $form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized){Switch-ToHud}})
$script:tray=New-Object Windows.Forms.NotifyIcon
$script:tray.Icon=if($null -ne $script:appIcon){$script:appIcon}else{[Drawing.SystemIcons]::Application}
$script:tray.Visible=$true
$script:tray.Text='Diagnostics Monitor - restore'
$menu=New-Object Windows.Forms.ContextMenuStrip
$restore=$menu.Items.Add('Restore / Открыть')
$quit=$menu.Items.Add('Exit / Выход')
$restore.Add_Click({Switch-ToFullDashboard})
$quit.Add_Click({$form.Close()})
$trayMenu=$menu
$script:tray.ContextMenuStrip=$menu
$script:tray.Add_DoubleClick({Switch-ToFullDashboard})
$form.Add_FormClosing({
    $script:closing=$true
    $script:tick.Stop()
    Disconnect-Comfy
    if($null -ne $script:captureJob){try{Stop-Job -Job $script:captureJob -ErrorAction SilentlyContinue}catch{};Remove-Job -Job $script:captureJob -Force -ErrorAction SilentlyContinue}
    Stop-ManagedCollector
    $script:tray.Visible=$false;$script:tray.Dispose();$menu.Dispose()
    $script:hud.Close();$script:hud.Dispose();$script:wsMessage.Dispose()
    if($null -ne $script:appIcon){$script:appIcon.Dispose()}
})
Apply-Language
Show-Page 0
if($SelfTest) {
    if($script:pages.Count -ne 4 -or $script:nav.Count -ne 4 -or $cards.Count -ne 4 -or $null -eq $capture -or $cacheButton.Enabled) {
        throw 'FAIL: unified interface controls / safety guard'
    }
    $script:lang='en';Apply-Language
    if($script:nav[2].Text -ne 'Diagnostics'){throw 'FAIL: EN localization'}
    $script:lang='ru';Apply-Language
    if($script:nav[2].Text -ne 'Диагностика'){throw 'FAIL: RU localization'}
    $script:tray.Visible=$false;$script:tray.Dispose();$menu.Dispose()
    $script:hud.Dispose();$form.Dispose();$script:wsMessage.Dispose()
    if($null -ne $script:appIcon){$script:appIcon.Dispose()}
    Write-Host 'PASS: unified v0.9 tabs, RU/EN, memory guard and controls'
    return
}
$form.Add_Shown({Start-ManagedCollector})
$script:tick.Start()
# ApplicationContext keeps the process running when F9 HUD hides the main form.
$ctx=New-Object Windows.Forms.ApplicationContext($form)
[Windows.Forms.Application]::Run($ctx)
