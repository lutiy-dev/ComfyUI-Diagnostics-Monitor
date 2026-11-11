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
 # Mock localhost ComfyUI system stats and keep another read handle open.
 function Invoke-RestMethod {
  [CmdletBinding()]
  param([string]$Uri,[int]$TimeoutSec)
  if($Uri.EndsWith('/system_stats')){
   return [pscustomobject]@{system=[pscustomobject]@{python_version='3.13.12 (main)';pytorch_version='2.10.0+cu130';comfyui_version='0.44.0'}}
  }
  if($Uri.EndsWith('/queue')){
   return [pscustomobject]@{queue_running=@();queue_pending=@()}
  }
  throw 'Unexpected test endpoint'
 }
 $lockedRoot=Join-Path $root 'shared_log'
 $handle=[IO.File]::Open($log,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
 try {
  & (Join-Path $PSScriptRoot '..\evidence.ps1') -Machine HOME -DataRoot $lockedRoot -ComfyLog $log -ComfyUrl 'http://127.0.0.1:8190' -SkipWindows -SkipProcesses -SkipStorage
 } finally { $handle.Dispose() }
 $lockedFile=@(Get-ChildItem -LiteralPath (Join-Path $lockedRoot 'evidence') -Filter 'evidence_*.json' -File)[0]
 $locked=Get-Content -LiteralPath $lockedFile.FullName -Raw|ConvertFrom-Json
 if($locked.sources.environment.data.cuda -ne '13.0'){throw 'PyTorch CUDA build not resolved from API'}
 if($locked.sources.environment.data.python -ne '3.13.12' -or $locked.sources.environment.data.comfyui -ne '0.44.0'){throw 'ComfyUI API identity missing'}
 if($locked.sources.comfy_queue.status -ne 'OK'){throw 'Mock ComfyUI queue not collected'}
 if($locked.sources.comfy_log_evidence.status -ne 'OK'){throw 'Shared log read is not OK'}
 if($locked.sources.comfy_log_evidence.data.file_hash_status -ne 'STABLE_BEST_EFFORT'){throw 'Log hash stability not confirmed'}
 if($locked.sources.comfy_log_evidence.data.file_sha256.Length -ne 64){throw 'Shared log SHA256 absent'}
 Remove-Item Function:\Invoke-RestMethod -ErrorAction SilentlyContinue
 Write-Host 'PASS: ComfyUI system_stats and shared log SHA256'
 # Mock only event retrieval: no real Windows Event Log is modified.
 function Get-WinEvent {
  [CmdletBinding()]
  param([hashtable]$FilterHashtable,[int]$MaxEvents)
  if(-not $FilterHashtable.ContainsKey('ProviderName')){throw 'Provider filter missing from query'}
  if($FilterHashtable.ProviderName -is [array]){throw 'STOP: multiple provider names in one query'}
  if($FilterHashtable.ProviderName -eq 'storport'){
   $ex=[Exception]::new('No matching synthetic provider')
   $er=[System.Management.Automation.ErrorRecord]::new($ex,'NoMatchingProvidersFound',[System.Management.Automation.ErrorCategory]::ObjectNotFound,$null)
   $PSCmdlet.ThrowTerminatingError($er)
  }
  if($FilterHashtable.ProviderName -eq 'Display'){
   $ex=[Exception]::new('No matching synthetic events')
   $er=[System.Management.Automation.ErrorRecord]::new($ex,'NoMatchingEventsFound',[System.Management.Automation.ErrorCategory]::ObjectNotFound,$null)
   $PSCmdlet.ThrowTerminatingError($er)
  }
  if($FilterHashtable.LogName -eq 'System' -and $FilterHashtable.ProviderName -eq 'Microsoft-Windows-Kernel-Power'){
   return [pscustomobject]@{TimeCreated=[DateTime]::Now;ProviderName='Microsoft-Windows-Kernel-Power';Id=41;RecordId=17;Level=2}
  }
  if($FilterHashtable.LogName -eq 'Application' -and $FilterHashtable.ProviderName -eq 'Windows Error Reporting'){
   return [pscustomobject]@{TimeCreated=[DateTime]::Now;ProviderName='Windows Error Reporting';Id=1001;RecordId=19;Level=4}
  }
  return
 }
 $mockRoot=Join-Path $root 'mocked_events'
 & (Join-Path $PSScriptRoot '..\evidence.ps1') -Machine HOME -DataRoot $mockRoot -ComfyLog $log -SkipProcesses -SkipStorage -SkipComfy
 $mockFile=@(Get-ChildItem -LiteralPath (Join-Path $mockRoot 'evidence') -Filter 'evidence_*.json' -File)[0]
 $mock=Get-Content -LiteralPath $mockFile.FullName -Raw|ConvertFrom-Json
 if($mock.sources.events_system.status -ne 'OK' -or $mock.sources.events_system.data[0].code -ne 41){throw 'System event lost when Display has no matching events'}
 if($mock.sources.events_application.status -ne 'OK' -or $mock.sources.events_application.data[0].code -ne 1001){throw 'Application WER informational event missing'}
 if($mock.sources.events_system.status -ne 'OK'){throw 'Absent optional storport incorrectly marks System PARTIAL'}
 Remove-Item Function:\Get-WinEvent -ErrorAction SilentlyContinue
 Write-Host 'PASS: Windows provider isolation, no-match error and informational WER'
 Write-Host 'PASS: evidence atomic snapshots, privacy, source metadata, localhost guard and offline handling'
} finally {
 Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
