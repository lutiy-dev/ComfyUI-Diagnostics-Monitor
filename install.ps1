# ComfyUI Diagnostics LAB - non-admin portable installer. No services, startup or outbound calls.
[CmdletBinding()]
param(
    [ValidateSet('HOME','WORK')][string]$Machine='HOME',
    [string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'Programs\ComfyUI-Diagnostics'),
    [string]$DataRoot=(Join-Path $env:LOCALAPPDATA 'ComfyUI-Diagnostics'),
    [string]$ComfyLog='',
    [switch]$Upgrade,
    [switch]$NoShortcuts
)
$ErrorActionPreference='Stop'
$source=(Resolve-Path -LiteralPath $PSScriptRoot).Path
$InstallRoot=[IO.Path]::GetFullPath($InstallRoot)
$DataRoot=[IO.Path]::GetFullPath($DataRoot)
if ($InstallRoot.TrimEnd('\') -eq $DataRoot.TrimEnd('\')) { throw 'Install and data folders must differ' }
if ($InstallRoot -eq [IO.Path]::GetPathRoot($InstallRoot) -or $DataRoot -eq [IO.Path]::GetPathRoot($DataRoot)) {
    throw 'A filesystem root is not an acceptable destination'
}
if ($InstallRoot -eq $source) { throw 'InstallRoot must differ from source' }
$payload=@('collector.ps1','dashboard.ps1','merge_to_sqlite.py','lib\ComfyWs.ps1','lib\Hud.ps1','lib\Updates.ps1','lib\AppIcon.ps1','evidence.ps1','configurator.ps1','analyze_evidence.py')
foreach($file in $payload) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $file) -PathType Leaf)) { throw "Missing payload file: $file" }
}
$marker=Join-Path $InstallRoot 'installation.json'
if (Test-Path -LiteralPath $InstallRoot) {
    if (-not (Test-Path -LiteralPath $marker)) { throw "STOP: destination exists but is not a managed installation: $InstallRoot" }
    if (-not $Upgrade) { throw 'Already installed. Specify -Upgrade to update program files; data stays untouched.' }
}
$null=New-Item -ItemType Directory -Force -Path (Join-Path $InstallRoot 'lib')
$null=New-Item -ItemType Directory -Force -Path $DataRoot
foreach ($file in $payload) {
    Copy-Item -LiteralPath (Join-Path $source $file) -Destination (Join-Path $InstallRoot $file) -Force
}
# Brand icon is generated locally from inspectable PowerShell source.
. (Join-Path $InstallRoot 'lib\AppIcon.ps1')
New-ComfyDiagnosticsIcon -Path (Join-Path $InstallRoot 'app.ico')
$launch=@'
[CmdletBinding()]
param([ValidateSet('Dashboard','Collector','Configurator','Evidence')][string]$Mode='Dashboard',[switch]$SelfTest)
$ErrorActionPreference='Stop'
$config=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'config.json') -Raw | ConvertFrom-Json
if ($Mode -eq 'Dashboard') {
    & (Join-Path $PSScriptRoot 'dashboard.ps1') -Machine $config.machine -DataDir $config.data_root -SelfTest:$SelfTest
} elseif ($Mode -eq 'Configurator') {
    & (Join-Path $PSScriptRoot 'configurator.ps1') -Machine $config.machine -DataRoot $config.data_root -ComfyLog $config.comfy_log -SelfTest:$SelfTest
} elseif ($Mode -eq 'Evidence') {
    & (Join-Path $PSScriptRoot 'evidence.ps1') -Machine $config.machine -DataRoot $config.data_root -ComfyLog $config.comfy_log -SkipWindows -SkipStorage -SkipProcesses -SkipComfy -SelfTest:$SelfTest
} elseif (-not $SelfTest) {
    & (Join-Path $PSScriptRoot 'collector.ps1') -Machine $config.machine -DataDir $config.data_root -ComfyLog $config.comfy_log
} else { Write-Host 'PASS: collector configuration available' }
'@
[IO.File]::WriteAllText((Join-Path $InstallRoot 'launch.ps1'),$launch,(New-Object Text.UTF8Encoding($false)))
$config=[ordered]@{
    schema=1
    machine=$Machine
    data_root=$DataRoot
    comfy_log=$ComfyLog
}
[IO.File]::WriteAllText((Join-Path $InstallRoot 'config.json'),($config|ConvertTo-Json -Depth 3),(New-Object Text.UTF8Encoding($false)))
$manifest=[ordered]@{
    product='ComfyUI-Diagnostics'
    version='0.6.0-LAB'
    installed_utc=[DateTime]::UtcNow.ToString('o')
    install_root=$InstallRoot
    data_root=$DataRoot
    machine=$Machine
    payload=$payload
}
[IO.File]::WriteAllText($marker,($manifest|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
if (-not $NoShortcuts) {
    $start=Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs\ComfyUI Diagnostics LAB'
    $null=New-Item -ItemType Directory -Force -Path $start
    $shell=New-Object -ComObject WScript.Shell
    foreach($entry in @(@('Dashboard','Dashboard'),@('Collector','Collector'),@('Configurator','Configurator'))) {
        $lnk=$shell.CreateShortcut((Join-Path $start ($entry[0]+'.lnk')))
        $lnk.TargetPath=(Join-Path $PSHOME 'powershell.exe')
        $lnk.Arguments='-NoProfile -STA -ExecutionPolicy Bypass -File "'+(Join-Path $InstallRoot 'launch.ps1')+'" -Mode '+$entry[1]
        $lnk.WorkingDirectory=$InstallRoot
        $lnk.IconLocation=(Join-Path $InstallRoot 'app.ico')+',0'
        $lnk.Save()
    }
}
Write-Host "PASS: installed LAB program in $InstallRoot"
Write-Host "Diagnostic data retained in $DataRoot"
Write-Host 'Start Menu > ComfyUI Diagnostics LAB > Dashboard / Collector'
Write-Host 'Collector runs only when explicitly launched. Do not run multiple collectors for the same machine.'
