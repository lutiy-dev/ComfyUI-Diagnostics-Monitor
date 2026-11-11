# ComfyUI Diagnostics Configurator LAB v0.7 — on-demand safe local evidence capture.
# No privilege elevation, no auto-send, no driver/ComfyUI mutation.
[CmdletBinding()]
param(
 [ValidateSet('HOME','WORK')][string]$Machine='HOME',
 [string]$DataRoot=(Join-Path $env:LOCALAPPDATA 'ComfyUI-Diagnostics'),
 [string]$ComfyLog='',
 [switch]$SelfTest,
 [switch]$CaptureSelfTest
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if($ComfyLog -eq '') {
 $cfg=Join-Path $PSScriptRoot 'config.json'
 if(Test-Path -LiteralPath $cfg) {
  try { $obj=Get-Content -LiteralPath $cfg -Raw|ConvertFrom-Json; $ComfyLog=[string]$obj.comfy_log } catch {}
 }
}
$window=New-Object Windows.Forms.Form
$script:configIcon=$null
$iconPath=Join-Path $PSScriptRoot 'app.ico'
if(Test-Path -LiteralPath $iconPath -PathType Leaf){
 $script:configIcon=[Drawing.Icon]::new($iconPath)
 $window.Icon=$script:configIcon
}
$uiVersion='0.7.0-LAB-CANDIDATE'
$uiManifest=Join-Path $PSScriptRoot 'installation.json'
if(Test-Path -LiteralPath $uiManifest -PathType Leaf){
 try { $uiVersion=[string]((Get-Content -LiteralPath $uiManifest -Raw|ConvertFrom-Json).version) } catch {}
}
$window.Text="ComfyUI Diagnostics Configurator | $Machine | $uiVersion"
$window.Size=[Drawing.Size]::new(720,690)
$window.MinimumSize=$window.Size
$window.MaximumSize=$window.Size
$window.AutoScaleMode=[Windows.Forms.AutoScaleMode]::Font
$window.StartPosition='CenterScreen'
$window.Font=[Drawing.Font]::new('Segoe UI',10)
$window.BackColor=[Drawing.Color]::FromArgb(20,24,30)
$window.ForeColor=[Drawing.Color]::FromArgb(235,240,245)
$uiPanel=[Drawing.Color]::FromArgb(31,38,47)
$uiStroke=[Drawing.Color]::FromArgb(71,84,99)
$uiText=[Drawing.Color]::FromArgb(235,240,245)
$uiMuted=[Drawing.Color]::FromArgb(169,184,199)
$uiYellow=[Drawing.Color]::FromArgb(255,212,0)
function Set-DiagnosticsButton([Windows.Forms.Button]$control,[switch]$Primary) {
 $control.UseVisualStyleBackColor=$false
 $control.FlatStyle=[Windows.Forms.FlatStyle]::Flat
 $control.FlatAppearance.BorderSize=1
 $control.FlatAppearance.BorderColor=$uiStroke
 $control.FlatAppearance.MouseOverBackColor=[Drawing.Color]::FromArgb(59,71,83)
 $control.FlatAppearance.MouseDownBackColor=[Drawing.Color]::FromArgb(76,88,100)
 $control.BackColor=$uiPanel
 $control.ForeColor=$uiText
 $control.Cursor=[Windows.Forms.Cursors]::Hand
 $control.Font=[Drawing.Font]::new('Segoe UI',10)
 if($Primary){
  $control.BackColor=$uiYellow
  $control.ForeColor=[Drawing.Color]::FromArgb(20,24,30)
  $control.FlatAppearance.BorderColor=$uiYellow
  $control.FlatAppearance.MouseOverBackColor=[Drawing.Color]::FromArgb(255,224,70)
  $control.FlatAppearance.MouseDownBackColor=[Drawing.Color]::FromArgb(223,184,0)
 }
}
$window.TopMost=$true
function LabelText([string]$s,[int]$x,[int]$y,[int]$w,[int]$h) {
 $o=New-Object Windows.Forms.Label
 $o.Text=$s;$o.Location=[Drawing.Point]::new($x,$y);$o.Size=[Drawing.Size]::new($w,$h)
 $o.AutoEllipsis=$true
 $window.Controls.Add($o);return $o
}
$heading=LabelText 'Diagnostics Evidence Center' 20 18 620 30
$heading.Font=[Drawing.Font]::new('Segoe UI',15,[Drawing.FontStyle]::Bold)
$subtitle=LabelText 'Read-only capture | Local JSON | No cloud upload or repairs' 20 49 655 24
$subtitle.ForeColor=$uiMuted
$null=LabelText "Machine: $Machine" 20 88 300 25
$null=LabelText 'History (hours)' 21 123 158 24
$hours=New-Object Windows.Forms.NumericUpDown
$hours.Minimum=1;$hours.Maximum=24;$hours.Value=3
$hours.Location=[Drawing.Point]::new(184,121);$hours.Size=[Drawing.Size]::new(90,27)
$hours.BackColor=$uiPanel;$hours.ForeColor=$uiText
$window.Controls.Add($hours)
$null=LabelText 'ComfyUI log path (local only, never exported as text)' 21 164 630 22
$logBox=New-Object Windows.Forms.TextBox
$logBox.Location=[Drawing.Point]::new(21,191);$logBox.Size=[Drawing.Size]::new(640,28)
$logBox.Text=$ComfyLog
$logBox.BackColor=$uiPanel
$logBox.ForeColor=$uiText
$logBox.BorderStyle=[Windows.Forms.BorderStyle]::FixedSingle
$logBox.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$window.Controls.Add($logBox)
$null=LabelText 'Sources included in snapshot:' 21 235 500 26
$checks=[ordered]@{}
$items=@(
 @('Windows Events / WER','Windows',21,269),
 @('Python process memory (unverified ComfyUI association)','Processes',21,306),
 @('Storage capacity','Storage',21,343),
 @('ComfyUI localhost queue and log signatures','Comfy',21,380)
)
foreach($item in $items) {
 $cb=New-Object Windows.Forms.CheckBox
 $cb.Text=$item[0];$cb.Checked=$true
 $cb.Location=[Drawing.Point]::new([int]$item[2],[int]$item[3])
 $cb.Size=[Drawing.Size]::new(640,28)
 $cb.BackColor=$window.BackColor
 $cb.ForeColor=$uiText
 $cb.FlatStyle=[Windows.Forms.FlatStyle]::Standard
 $window.Controls.Add($cb);$checks[$item[1]]=$cb
}
$rawLog=New-Object Windows.Forms.CheckBox
$rawLog.Text='Include private RAW ComfyUI log (may contain secrets; never auto-upload)'
$rawLog.Checked=$false
$rawLog.Location=[Drawing.Point]::new(21,413)
$rawLog.Size=[Drawing.Size]::new(655,31)
$rawLog.ForeColor=[Drawing.Color]::FromArgb(255,177,92)
$window.Controls.Add($rawLog)
$button=New-Object Windows.Forms.Button
$button.Text='Capture Evidence'
$button.Location=[Drawing.Point]::new(21,458)
$button.Size=[Drawing.Size]::new(208,41)
Set-DiagnosticsButton $button -Primary
$window.Controls.Add($button)
$open=New-Object Windows.Forms.Button
$open.Text='Open Evidence Folder'
$open.Location=[Drawing.Point]::new(245,458)
$open.Size=[Drawing.Size]::new(214,41)
Set-DiagnosticsButton $open
$window.Controls.Add($open)
$logsButton=New-Object Windows.Forms.Button
$logsButton.Text='Open Logs Folder'
$logsButton.Location=[Drawing.Point]::new(475,458)
$logsButton.Size=[Drawing.Size]::new(194,41)
Set-DiagnosticsButton $logsButton
$window.Controls.Add($logsButton)
$logsButton.Add_Click({
    if (-not (Test-Path -LiteralPath $DataRoot -PathType Container)) {
        [void][Windows.Forms.MessageBox]::Show('Diagnostics folder is not available.','ComfyUI Diagnostics')
        return
    }
    [void][Diagnostics.Process]::Start('explorer.exe',('"'+$DataRoot+'"'))
})
$status=LabelText 'Ready - all captures are manually triggered.' 21 515 645 72
$status.ForeColor=$uiMuted
$status.Anchor=[Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Right
$open.Add_Click({
 $path=Join-Path $DataRoot 'evidence'
 $null=New-Item -ItemType Directory -Path $path -Force
 [void][Diagnostics.Process]::Start('explorer.exe','"'+$path+'"')
})
$button.Add_Click({
 $button.Enabled=$false
 $status.Text='Capturing evidence...'
 $window.Refresh()
 try {
  $evidenceDir=Join-Path $DataRoot 'evidence'
  $before=@(Get-ChildItem -LiteralPath $evidenceDir -Filter 'evidence_*.json' -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
  $params=@{
   Machine=$Machine
   DataRoot=$DataRoot
   ComfyLog=$logBox.Text
   Hours=[int]$hours.Value
   SkipWindows=(-not $checks.Windows.Checked)
   SkipProcesses=(-not $checks.Processes.Checked)
   SkipStorage=(-not $checks.Storage.Checked)
   SkipComfy=(-not $checks.Comfy.Checked)
   ArchiveComfyLog=[bool]$rawLog.Checked
  }
  $path=Join-Path $PSScriptRoot 'evidence.ps1'
  if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "Evidence script missing: $path"}
  & $path @params
  $new=@(Get-ChildItem -LiteralPath $evidenceDir -Filter 'evidence_*.json' -File -ErrorAction Stop | Where-Object { $_.FullName -notin $before })
  if($new.Count -eq 0) {throw 'No new evidence JSON file was created'}
  $latest=$new|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 1
  $record=Get-Content -LiteralPath $latest.FullName -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop
  if($record.kind -ne 'evidence_snapshot' -or $record.schema -ne 2){throw 'Created JSON failed evidence schema verification'}
  $status.ForeColor=[Drawing.Color]::FromArgb(139,218,173)
  $status.Text="PASS: $($latest.Name) - $($latest.Length) bytes"
 } catch {
  $status.ForeColor=[Drawing.Color]::FromArgb(255,177,92)
  $localMessage=$_.Exception.Message
  if($localMessage.Length -gt 350){$localMessage=$localMessage.Substring(0,350)+'...'}
  $status.Text="FAIL: $localMessage"
  if(-not $SelfTest){[void][Windows.Forms.MessageBox]::Show($localMessage,'Capture Evidence — FAILED',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error)}
 } finally { $button.Enabled=$true }
})
if($SelfTest) {
 if($null -eq $checks.Windows -or -not $button.Enabled -or -not $logsButton.Enabled -or $hours.Value -ne 3){throw 'FAIL: Configurator controls'}
 if($CaptureSelfTest){
  foreach($key in @($checks.Keys)){$checks[$key].Checked=$false}
  $before=@(Get-ChildItem -LiteralPath (Join-Path $DataRoot 'evidence') -Filter 'evidence_*.json' -File -ErrorAction SilentlyContinue).Count
  $window.Show()
  [Windows.Forms.Application]::DoEvents()
  $button.PerformClick()
  $after=@(Get-ChildItem -LiteralPath (Join-Path $DataRoot 'evidence') -Filter 'evidence_*.json' -File -ErrorAction SilentlyContinue).Count
  if($after -le $before -or -not $status.Text.StartsWith('PASS:')){throw ('FAIL: Configurator capture test: '+$status.Text)}
  $window.Hide()
  Write-Host 'PASS: Configurator button created and verified an evidence snapshot'
 }

 $window.Dispose()
 if($null -ne $script:configIcon){$script:configIcon.Dispose()}
 Write-Host 'PASS: Configurator controls initialized'
 return
}
[void]$window.ShowDialog()
if($null -ne $script:configIcon){$script:configIcon.Dispose()}
