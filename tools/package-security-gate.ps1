# Windows package security gate - fail-closed checks on the exact ZIP payload.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PackageRoot,[Parameter(Mandatory=$true)][string]$OutputManifest)
$ErrorActionPreference='Stop'
$PackageRoot=(Resolve-Path -LiteralPath $PackageRoot).Path
$files=@(Get-ChildItem -LiteralPath $PackageRoot -File -Recurse)
if ($files.Count -eq 0) {throw 'FAIL: empty payload'}
$allowed=@('.ps1','.py','.md')
$paths=@()
$hashes=@()
foreach ($f in $files) {
    $rel=$f.FullName.Substring($PackageRoot.Length).TrimStart([char]'\',[char]'/').Replace('\','/')
    if ($f.Extension.ToLowerInvariant() -notin $allowed) { throw "FAIL: unexpected extension $rel" }
    if ($f.Length -gt 1MB) { throw "FAIL: unexpected large file $rel" }
    $text=[IO.File]::ReadAllText($f.FullName)
    # Guard obvious credential formats. This is NOT a complete secret scanner.
    if ($text -match '(?i)-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|sk-proj-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9_]{20,}') {
        throw "FAIL: possible embedded secret in $rel"
    }
    $paths+=$rel
    $hashes+=@{path=$rel; sha256=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
}
$expected=@(
 'install.ps1','uninstall.ps1','collector.ps1','dashboard.ps1','merge_to_sqlite.py',
 'lib/ComfyWs.ps1','lib/Hud.ps1','lib/Updates.ps1','lib/AppIcon.ps1','evidence.ps1','configurator.ps1','analyze_evidence.py',
 'docs/WINDOWS_INSTALL.md','docs/HUD_MODE.md','docs/CHATGPT_DIAGNOSTICS_ACCESS.md','docs/DIAGNOSTICS_V06.md'
)
if (@(Compare-Object -ReferenceObject @($expected|Sort-Object) -DifferenceObject @($paths|Sort-Object)).Count -gt 0) {
 throw "FAIL: package file inventory differs from allowlist"
}
$manifest=[ordered]@{
 schema=1; source_sha=$env:GITHUB_SHA; package_files=@($hashes|Sort-Object path);
 provenance='GitHub Actions; integrity manifest, NOT a digital signature'
}
[IO.File]::WriteAllText($OutputManifest,($manifest|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
Write-Host "PASS: file allowlist, size, limited secrets checks, SHA256 manifest ($($files.Count) files)"
