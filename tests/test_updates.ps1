$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\lib\Updates.ps1')
function Assert($ok,$message) { if (-not $ok) { throw "FAIL: $message" } }
Assert ((Compare-DiagnosticsVersion -Current '0.5.0-LAB' -Latest 'v0.6.0') -eq 'UPDATE_AVAILABLE') 'new version'
Assert ((Compare-DiagnosticsVersion -Current '0.5.0-LAB' -Latest 'v0.5.0') -eq 'UPDATE_AVAILABLE') 'LAB to stable'
Assert ((Compare-DiagnosticsVersion -Current '0.5.0' -Latest 'v0.4.9') -eq 'UP_TO_DATE') 'older version'
Assert ((Compare-DiagnosticsVersion -Current '0.5.0' -Latest 'invalid') -eq 'UNKNOWN') 'invalid release rejected'
Assert ((Get-DiagnosticsUpdateDecision -Current '0.9.0-LAB-CANDIDATE' -Latest 'v0.8.0-LAB') -eq 'LAB_CANDIDATE') 'candidate must not be labelled current release'
Assert ((Get-DiagnosticsUpdateDecision -Current '0.9.0-LAB-CANDIDATE' -Latest 'v0.9.0-LAB') -eq 'LAB_CANDIDATE') 'matching release number cannot identify CI build'
Assert ((Get-DiagnosticsUpdateDecision -Current '0.8.0-LAB' -Latest 'v0.9.0') -eq 'UPDATE_AVAILABLE') 'future published release can be offered'
Write-Host 'PASS: version comparison and unpublished LAB channel semantics (offline)'
