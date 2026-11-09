# ComfyUI Diagnostics Evidence Capture v0.7 LAB candidate. On-demand, local, read-only.
# Captures normalized technical metadata only. No prompts, raw event messages, dumps or file contents.
[CmdletBinding()]
param(
 [ValidateSet('HOME','WORK')][string]$Machine='HOME',
 [string]$DataRoot=(Join-Path $env:LOCALAPPDATA 'ComfyUI-Diagnostics'),
 [string]$ComfyLog='',
 [string]$ComfyUrl='http://127.0.0.1:8188',
 [ValidateRange(1,24)][int]$Hours=3,
 [switch]$SkipWindows,
 [switch]$SkipProcesses,
 [switch]$SkipStorage,
 [switch]$SkipComfy,
 [switch]$ArchiveComfyLog,
 [switch]$SelfTest
)
$ErrorActionPreference='Stop'
$uri=$null
try { $uri=[Uri]$ComfyUrl } catch { throw 'STOP: invalid ComfyUI URL' }
if ($uri.Scheme -ne 'http' -or $uri.Host -notin @('localhost','127.0.0.1','::1') -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
 throw 'STOP: ComfyUI API must use localhost HTTP without credentials'
}
$now=[DateTime]::UtcNow
$report=[ordered]@{
 schema=2;kind='evidence_snapshot';machine=$Machine;created_utc=$now.ToString('o');collector_version='0.7.0-LAB-CANDIDATE'
 sources=[ordered]@{};notes=@('Evidence is observational; event proximity is not causation.')
}
function SourceResult([string]$source,[scriptblock]$action,[switch]$AllowEmpty) {
 $start=[DateTime]::UtcNow
 try {
  $value=& $action
  $count=0
  if ($null -ne $value) {
   if ($value -is [array]) { $count=$value.Count }
   else { $count=1 }
  }
  $state='OK'
  if ($source -eq 'environment' -and $value -and @($value.Values | Where-Object { $_ -eq 'UNKNOWN' }).Count -gt 0) { $state='PARTIAL' }
  if ($source -eq 'comfy_log_evidence' -and $value -and $value.file_sha256 -eq 'UNKNOWN') { $state='PARTIAL' }
  if ($count -eq 0) { $state=if($AllowEmpty){'EMPTY'}else{'PARTIAL'}; $value=@() }
  $report.sources[$source]=@{status=$state;data=$value;count=$count;collected_utc=([DateTime]::UtcNow.ToString('o'));duration_ms=[int]([DateTime]::UtcNow-$start).TotalMilliseconds}
 } catch {
  # Never persist exception text: it can include paths, prompts, or private messages.
  $type=$_.Exception.GetType().Name
  $reason='READ_FAILED'
  if($type -match 'UnauthorizedAccess|Security'){$reason='ACCESS_DENIED'}
  elseif($type -match 'FileNotFound|DirectoryNotFound|ItemNotFound'){$reason='FILE_MISSING'}
  elseif($type -match 'Timeout'){$reason='TIMEOUT'}
  elseif($source -like 'events_*' -and $_.FullyQualifiedErrorId -like '*NoMatchingEventsFound*'){
   $report.sources[$source]=@{status='EMPTY';data=@();count=0;collected_utc=([DateTime]::UtcNow.ToString('o'));duration_ms=[int]([DateTime]::UtcNow-$start).TotalMilliseconds}
   return
  }
  $report.sources[$source]=@{status='UNAVAILABLE';error_code=$source.ToUpperInvariant()+'_'+$reason;collected_utc=([DateTime]::UtcNow.ToString('o'));duration_ms=[int]([DateTime]::UtcNow-$start).TotalMilliseconds}
 }
}
SourceResult 'os_memory_cpu' {
 $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
 $cpu=@(Get-CimInstance Win32_Processor -ErrorAction Stop)
 $total=[long]$os.TotalVisibleMemorySize
 $free=[long]$os.FreePhysicalMemory
 [ordered]@{
  os_version=[string]$os.Version; os_build=[string]$os.BuildNumber
  physical_total_mib=[math]::Round($total/1024,1)
  physical_used_mib=[math]::Round(($total-$free)/1024,1)
  total_virtual_mib=[math]::Round(([long]$os.TotalVirtualMemorySize)/1024,1)
  free_virtual_mib=[math]::Round(([long]$os.FreeVirtualMemory)/1024,1)
  logical_processors=(@($cpu|Measure-Object -Property NumberOfLogicalProcessors -Sum)[0].Sum)
  cpu_names=@($cpu|ForEach-Object { $_.Name })
  cpu_load_pct=@($cpu|ForEach-Object { $_.LoadPercentage })
 }
}
SourceResult 'gpu' {
 $smi=Get-Command 'nvidia-smi.exe' -ErrorAction Stop
 $lines=@(& $smi.Source '--query-gpu=index,name,driver_version,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,pstate,clocks.sm,clocks.mem' '--format=csv,noheader,nounits' 2>$null)
 if ($LASTEXITCODE -ne 0 -or $lines.Count -eq 0) { throw 'NVIDIA SMI unavailable' }
 $rows=@()
 foreach($line in $lines) {
  $parts=@($line -split '\s*,\s*')
  if ($parts.Count -ne 11) { throw 'Unexpected SMI schema' }
  $rows+=@{index=$parts[0];name=$parts[1];driver=$parts[2];util_pct=$parts[3];vram_used_mib=$parts[4];vram_total_mib=$parts[5];temperature_c=$parts[6];power_w=$parts[7];pstate=$parts[8];core_clock_mhz=$parts[9];memory_clock_mhz=$parts[10]}
 }
 return ,$rows
}
if (-not $SkipProcesses) {
 SourceResult 'process_memory' {
  # Attribute only a unique local listening PID, never infer ComfyUI from a Python process name.
  $owners=@()
  try {
   $owners=@(Get-NetTCPConnection -LocalPort $uri.Port -State Listen -ErrorAction Stop |
     Where-Object { $_.LocalAddress -in @('127.0.0.1','::1','0.0.0.0','::') } |
     Select-Object -ExpandProperty OwningProcess -Unique)
  } catch {}
  $items=@(Get-Process -Name python,pythonw -ErrorAction SilentlyContinue | Select-Object -First 20)
  return ,@($items | ForEach-Object {
   $match=if($owners.Count -eq 1 -and [int]$owners[0] -eq $_.Id){'API_LISTENER_PID_MATCH'}else{'UNCONFIRMED'}
   $started='UNKNOWN'
   try { $started=$_.StartTime.ToUniversalTime().ToString('o') } catch {}
   @{pid=$_.Id;process_name=$_.ProcessName;cpu_seconds=$_.CPU;working_set_mib=[math]::Round($_.WorkingSet64/1MB,1);private_memory_mib=[math]::Round($_.PrivateMemorySize64/1MB,1);association=$match;start_utc=$started}
  })
 }
} else { $report.sources.process_memory=@{status='DISABLED'} }
if (-not $SkipStorage) {
 SourceResult 'storage' {
  return ,@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop | ForEach-Object {
    @{drive_type='FIXED';volume_alias=[string]$_.DeviceID;total_gib=[math]::Round($_.Size/1GB,1);free_gib=[math]::Round($_.FreeSpace/1GB,1)}
  })
 }
} else { $report.sources.storage=@{status='DISABLED'} }
if (-not $SkipWindows) {
 foreach($log in @('System','Application')) {
  $source='events_'+$log.ToLowerInvariant()
  $script:eventQueryFailures=0
  SourceResult $source {
   $begin=(Get-Date).AddHours(-$Hours)
   # Query each provider separately; a no-match must not invalidate other providers.
   $providers=if($log -eq 'System') {
    @('Display','Microsoft-Windows-WHEA-Logger','Microsoft-Windows-Kernel-Power','disk','storport','nvlddmkm','Microsoft-Windows-WER-SystemErrorReporting','volmgr','Ntfs','Microsoft-Windows-Kernel-PnP')
   } else {
    @('Application Error','Windows Error Reporting','Application Hang','.NET Runtime')
   }
   $events=@()
   $succeeded=0
   foreach($provider in $providers) {
    try {
     $found=@(Get-WinEvent -FilterHashtable @{LogName=$log;StartTime=$begin;Level=@(1,2,3,4);ProviderName=$provider} -MaxEvents 100 -ErrorAction Stop)
     $succeeded++
     $events+=@($found)
    } catch {
     $errorId=[string]$_.FullyQualifiedErrorId
     if($errorId -match 'NoMatchingEventsFound|NoProvidersFound|ProviderNotFound'){
      $succeeded++
     } else {
      $script:eventQueryFailures++
     }
    }
   }
   if($succeeded -eq 0){throw 'WINDOWS_EVENT_ALL_PROVIDER_QUERIES_FAILED'}
   $items=@($events | Sort-Object -Property TimeCreated -Descending -Unique | Select-Object -First 100 | ForEach-Object {
    @{time_utc=$_.TimeCreated.ToUniversalTime().ToString('o');provider=[string]$_.ProviderName;code=[int]$_.Id;record_id=[long]$_.RecordId;level=[int]$_.Level;log=$log}
   })
   return ,$items
  } -AllowEmpty
  if($script:eventQueryFailures -gt 0 -and $report.sources[$source].status -in @('OK','EMPTY')) {
   $report.sources[$source].status='PARTIAL'
   $report.sources[$source].error_code='WINDOWS_EVENT_PROVIDER_QUERIES_PARTIAL'
  }
 }
 SourceResult 'reliability' {
  $rows=@(Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ReliabilityRecords -ErrorAction Stop |
    Where-Object { $_.TimeGenerated -ge (Get-Date).AddHours(-$Hours) } | Select-Object -First 60)
  $items=@($rows | ForEach-Object {
   @{time_utc=$_.TimeGenerated.ToUniversalTime().ToString('o');event_id=[string]$_.EventIdentifier;source=[string]$_.SourceName;type=[string]$_.EventType}
  })
  return ,$items
 } -AllowEmpty
} else {
 $report.sources.events_system=@{status='DISABLED'}
 $report.sources.events_application=@{status='DISABLED'}
 $report.sources.reliability=@{status='DISABLED'}
}
# Parse known version fields without exporting full startup log lines.
SourceResult 'environment' {
 $versions=[ordered]@{python='UNKNOWN';pytorch='UNKNOWN';comfyui='UNKNOWN';cuda='UNKNOWN';aimdo='UNKNOWN'}
 if($ComfyLog -and (Test-Path -LiteralPath $ComfyLog -PathType Leaf)){
  foreach($line in @(Get-Content -LiteralPath $ComfyLog -TotalCount 600 -ErrorAction Stop)){
   foreach($key in @($versions.Keys)){
    if($versions[$key] -ne 'UNKNOWN'){continue}
    $pattern=switch($key){
     'python' {'(?i)Python version\s*[:=]\s*([0-9]+\.[0-9]+(?:\.[0-9]+)?)'}
     'pytorch' {'(?i)(?:PyTorch|Torch) version\s*[:=]\s*([0-9]+\.[0-9]+(?:\.[0-9]+)?(?:\+cu[0-9]+)?)'}
     'comfyui' {'(?i)ComfyUI version\s*[:=]\s*([0-9]+\.[0-9]+(?:\.[0-9]+)?)'}
     'cuda' {'(?i)CUDA version\s*[:=]\s*([0-9]+\.[0-9]+(?:\.[0-9]+)?)'}
     'aimdo' {'(?i)comfy-aimdo\s*(?:version)?\s*[:= ]\s*([0-9]+\.[0-9]+(?:\.[0-9]+)?)'}
    }
    if($line -match $pattern){$versions[$key]=$Matches[1]}
   }
  }
 }
 return $versions
}
if (-not $SkipComfy) {
 SourceResult 'comfy_queue' {
  $result=Invoke-RestMethod -Uri ($ComfyUrl.TrimEnd('/')+'/queue') -TimeoutSec 3 -ErrorAction Stop
  @{running=@($result.queue_running).Count;pending=@($result.queue_pending).Count;endpoint='localhost';port=$uri.Port}
 }
 SourceResult 'comfy_log_evidence' {
  if (-not $ComfyLog -or -not (Test-Path -LiteralPath $ComfyLog -PathType Leaf)) { throw [IO.FileNotFoundException]::new('ComfyUI log absent') }
  $file=Get-Item -LiteralPath $ComfyLog
  $hits=@()
  $lineNo=0
  # Read a bounded tail while ComfyUI is still appending to the file.
  $stream=[IO.File]::Open($ComfyLog,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
  try {
   $take=[int][Math]::Min($stream.Length,1048576)
   $offset=$stream.Length-$take
   [void]$stream.Seek($offset,[IO.SeekOrigin]::Begin)
   $buffer=New-Object byte[] $take
   $read=0
   while($read -lt $take){
    $n=$stream.Read($buffer,$read,$take-$read)
    if($n -eq 0){break}
    $read+=$n
   }
  } finally { $stream.Dispose() }
  $text=[Text.Encoding]::UTF8.GetString($buffer,0,$read)
  $lines=@($text -split "`r?`n")
  if($offset -gt 0 -and $lines.Count -gt 0){$lines=@($lines|Select-Object -Skip 1)}
  $lines=@($lines|Select-Object -Last 1500)
  foreach($line in $lines) {
   $lineNo++
   $code=$null
   if($line -match '(?i)CUDA.*(error|out of memory)'){$code='CUDA'}
   elseif($line -match '(?i)out of memory|OOM'){$code='OOM'}
   elseif($line -match '(?i)HostBuffer|aimdo'){$code='AIMDO'}
   elseif($line -match '(?i)exception|traceback'){$code='EXCEPTION'}
   elseif($line -match '(?i)failed to import|module not found'){$code='IMPORT'}
   if($code) {
    $hits+=@{tail_line=$lineNo;code=$code}
    if($hits.Count -gt 100) { $hits=@($hits|Select-Object -Last 100) }
   }
  }
  # Whole-file hashing is best-effort: a changing/locked log must not invalidate parsed error signatures.
  $hash='UNKNOWN'
  try {$hash=(Get-FileHash -LiteralPath $ComfyLog -Algorithm SHA256 -ErrorAction Stop).Hash} catch {}
  @{status='OK';file_size_bytes=$file.Length;file_modified_utc=$file.LastWriteTimeUtc.ToString('o');file_sha256=$hash;tail_bytes_scanned=$read;tail_lines_scanned=$lineNo;signatures=$hits;raw_text_excluded=$true}
 }
} else {
 $report.sources.comfy_queue=@{status='DISABLED'}
 $report.sources.comfy_log_evidence=@{status='DISABLED'}
}
# Optional full private log archive. This file may contain prompts, paths and tokens.
# Never enabled by default; no automatic upload or export outside DataRoot.
if($ArchiveComfyLog -and -not $SkipComfy) {
 $report.sources.private_comfy_log=@{status='UNAVAILABLE';reason='LOG_MISSING_OR_EXCEEDS_QUOTA'}
 if($ComfyLog -and (Test-Path -LiteralPath $ComfyLog -PathType Leaf)) {
  $rawFile=Get-Item -LiteralPath $ComfyLog
  $private=Join-Path $DataRoot 'private'
  $null=New-Item -ItemType Directory -Path $private -Force
  $existingPrivate=@(Get-ChildItem -LiteralPath $private -File -Filter '*.log' -ErrorAction SilentlyContinue)
  $privateSum=(@($existingPrivate|Measure-Object Length -Sum)[0].Sum)
  if($rawFile.Length -le 20MB -and $existingPrivate.Count -lt 20 -and $privateSum -lt 200MB){
   $filename='comfy_private_'+$Machine+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)+'.log'
   $destination=Join-Path $private $filename
   try {
    [IO.File]::Copy($ComfyLog,$destination,$false)
    $report.sources.private_comfy_log=@{
      status='OK';file_name=$filename;subfolder='private'
      size_bytes=(Get-Item -LiteralPath $destination).Length
      sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
      privacy='RAW_CONTAINS_POTENTIAL_SECRETS; LOCAL_ONLY; USER_CONSENT_REQUIRED_BEFORE_SHARING'
    }
   } catch {
    if(Test-Path -LiteralPath $destination){Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue}
    $report.sources.private_comfy_log=@{status='UNAVAILABLE';reason='LOG_COPY_FAILED'}
   }
  }
 }
}
$report.coverage=[ordered]@{available=@();missing=@();disabled=@();empty=@();partial=@()}
foreach($key in @($report.sources.Keys)) {
 $s=$report.sources[$key].status
 if($s -eq 'OK'){$report.coverage.available+= $key}
 elseif($s -eq 'DISABLED'){$report.coverage.disabled+= $key}
 elseif($s -eq 'EMPTY'){$report.coverage.missing+= $key; $report.coverage.empty+= $key}
 elseif($s -eq 'PARTIAL'){$report.coverage.missing+= $key; $report.coverage.partial+= $key}
 else{$report.coverage.missing+=$key}
}
if($SelfTest) {
 $report.kind='evidence_selftest'
 $report.sources.events_system=@{status='TEST_FIXTURE';data=@(@{code=4101;provider='Display'})}
 $report.coverage=@{available=@();missing=@();disabled=@();fixture='synthetic Display 4101; no actual GPU failure implied'}
}
$folder=Join-Path $DataRoot 'evidence'
$null=New-Item -ItemType Directory -Path $folder -Force
$path=Join-Path $folder ("evidence_"+$Machine+"_"+(Get-Date -Format 'yyyyMMdd_HHmmss')+"_"+[guid]::NewGuid().ToString('N').Substring(0,8)+'.json')
$payload=ConvertTo-Json -InputObject $report -Depth 12
$bytes=[Text.Encoding]::UTF8.GetBytes($payload)
if($bytes.Length -gt 3MB) { throw 'STOP: evidence bundle exceeds 3MiB' }
$existing=@(Get-ChildItem -LiteralPath $folder -Filter 'evidence_*.json' -File -ErrorAction SilentlyContinue)
if($existing.Count -ge 300 -or (@($existing|Measure-Object -Property Length -Sum)[0].Sum) -gt 100MB) {throw 'STOP: evidence storage quota reached; archive privately before adding files'}
# Stage in the same directory and move into place only after a complete write.
$temp=Join-Path $folder ('.pending_'+[guid]::NewGuid().ToString('N')+'.tmp')
try {
 $stream=[IO.File]::Open($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try {
  $stream.Write($bytes,0,$bytes.Length)
  $stream.Flush($true)
 } finally { $stream.Dispose() }
 [IO.File]::Move($temp,$path)
} finally {
 if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
}
Write-Host "PASS: Evidence snapshot written: $path"
Write-Host ('AVAILABLE='+$report.coverage.available.Count+' MISSING='+$report.coverage.missing.Count+' DISABLED='+$report.coverage.disabled.Count)
