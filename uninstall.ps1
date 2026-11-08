# Uninstall program only. All diagnostic data are deliberately retained.
[CmdletBinding()]
param(
    [string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'Programs\ComfyUI-Diagnostics'),
    [switch]$NoShortcuts
)
$ErrorActionPreference='Stop'
$InstallRoot=[IO.Path]::GetFullPath($InstallRoot)
$marker=Join-Path $InstallRoot 'installation.json'
if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { throw 'STOP: not a managed installation' }
$manifest=Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
if ($manifest.product -ne 'ComfyUI-Diagnostics' -or $manifest.install_root -ne $InstallRoot) {
    throw 'STOP: installation manifest does not match target'
}
# Whitelist files installed by this project; do not remove arbitrary user files.
foreach($f in @('collector.ps1','dashboard.ps1','merge_to_sqlite.py','launch.ps1','config.json','installation.json','lib\ComfyWs.ps1','lib\Hud.ps1','lib\Updates.ps1')) {
    $path=Join-Path $InstallRoot $f
    if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force }
}
$lib=Join-Path $InstallRoot 'lib'
if ((Test-Path -LiteralPath $lib) -and @(Get-ChildItem -LiteralPath $lib -Force).Count -eq 0) {
    Remove-Item -LiteralPath $lib
}
if (@(Get-ChildItem -LiteralPath $InstallRoot -Force).Count -eq 0) {
    Remove-Item -LiteralPath $InstallRoot
}
if (-not $NoShortcuts) {
    $start=Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs\ComfyUI Diagnostics LAB'
    foreach($f in @('Dashboard.lnk','Collector.lnk')) {
        $lnk=Join-Path $start $f
        if (Test-Path -LiteralPath $lnk -PathType Leaf) {
            $shell=New-Object -ComObject WScript.Shell
            $target=$shell.CreateShortcut($lnk).Arguments
            if ($target.Contains((Join-Path $InstallRoot 'launch.ps1'))) { Remove-Item -LiteralPath $lnk -Force }
        }
    }
    if ((Test-Path -LiteralPath $start) -and @(Get-ChildItem -LiteralPath $start -Force).Count -eq 0) { Remove-Item -LiteralPath $start }
}
Write-Host "PASS: program uninstalled from $InstallRoot"
Write-Host "Diagnostic data preserved: $($manifest.data_root)"
Write-Host 'Existing running processes are NOT terminated.'
