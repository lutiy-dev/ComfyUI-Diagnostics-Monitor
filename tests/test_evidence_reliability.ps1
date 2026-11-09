# Windows PowerShell 5.1 integration regression: no ComfyUI, admin or GPU required.
$ErrorActionPreference='Stop'
$root=Join-Path $env:RUNNER_TEMP ('EvidenceReliability_'+[guid]::NewGuid().ToString('N'))
$log=Join-Path $root 'synthetic_comfy.log'
$null=New-Item -ItemType Directory -Path $root -Force
try {
 [IO.File]::WriteAllText($log, "Python version: 3.12.1`nCUDA error: SYNTHETIC_PRIVATE_SECRET_NEVER_EXPORT`n", [Text.UTF8Encoding]::new($false))
 & (Join-Path $PSScriptRoot '..\evidence.ps1') -Machine HOME -DataRoot $root -ComfyLog $log -SkipWindows -SkipProcesses -SkipStorage
 $files=@(Get-ChildItem -LiteralPath (Join-Path $root 'evidence') -Filter 'evidence_*.json' -File)
 if($files.Count -ne 1){throw 'First snapshot not produced'}
 $raw=[IO.File]::ReadAllText($files[0].FullName)
 if($raw -match 'SYNTHETIC_PRIVATE_SECRET_NEVER_EXPORT'){throw 'Private data leaked'}
 $item=$raw|ConvertFrom-Json
 if($item.schema -ne 2 -or $item.kind -ne 'evidence_snapshot'){throw 'Unsupported schema'}
 if($item.sources.comfy_log_evidence.status -ne 'OK'){throw 'Synthetic ComfyUI log not processed'}
 if($item.sources.comfy_log_evidence.data.signatures.Count -lt 1){throw 'Missing synthetic CUDA signature'}
 if($item.sources.comfy_queue.status -ne 'UNAVAILABLE'){throw 'Offline ComfyUI should be UNAVAILABLE'}
 if(-not $item.sources.gpu.collected_utc){throw 'Missing source timestamp'}
 if(@(Get-ChildItem (Join-Path $root 'evidence') -Filter '*.tmp' -Force).Count -ne 0){throw 'Pending temp remained'}
 & (Join-Path $PSScriptRoot '..\evidence.ps1') -Machine HOME -DataRoot $root -ComfyLog $log -SkipWindows -SkipProcesses -SkipStorage
 if(@(Get-ChildItem (Join-Path $root 'evidence') -Filter 'evidence_*.json').Count -ne 2){throw 'Second capture did not use unique path'}
 $blocked=$false
 try {
  & (Join-Path $PSScriptRoot '..\evidence.ps1') -Machine HOME -DataRoot $root -ComfyUrl 'http://example.com:8188' -SkipWindows -SkipProcesses -SkipStorage -SkipComfy
 } catch { $blocked=$true }
 if(-not $blocked){throw 'Non-local ComfyURL not rejected'}
 # Mock only event retrieval: no real Windows Event Log is modified.
 function Get-WinEvent {
  [CmdletBinding()]
  param([hashtable]$FilterHashtable,[int]$MaxEvents)
  if(-not $FilterHashtable.ContainsKey('ProviderName')){throw 'Provider filter missing from query'}
  if($FilterHashtable.LogName -eq 'System'){
   return [pscustomobject]@{TimeCreated=[DateTime]::Now;ProviderName='Display';Id=4101;RecordId=17;Level=2}
  }
  return
 }
 $mockRoot=Join-Path $root 'mocked_events'
 & (Join-Path $PSScriptRoot '..\evidence.ps1') -Machine HOME -DataRoot $mockRoot -ComfyLog $log -SkipProcesses -SkipStorage -SkipComfy
 $mockFile=@(Get-ChildItem -LiteralPath (Join-Path $mockRoot 'evidence') -Filter 'evidence_*.json' -File)[0]
 $mock=Get-Content -LiteralPath $mockFile.FullName -Raw|ConvertFrom-Json
 if($mock.sources.events_system.status -ne 'OK' -or $mock.sources.events_system.data[0].code -ne 4101){throw 'Synthetic Display 4101 not captured'}
 if($mock.sources.events_application.status -ne 'EMPTY'){throw 'Empty Application events not classified EMPTY'}
 if($mock.coverage.empty -notcontains 'events_application'){throw 'EMPTY source missing in coverage'}
 Remove-Item Function:\Get-WinEvent -ErrorAction SilentlyContinue
 Write-Host 'PASS: Windows filtered synthetic 4101 and explicit EMPTY events'
 Write-Host 'PASS: evidence atomic snapshots, privacy, source metadata, localhost guard and offline handling'
} finally {
 Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
