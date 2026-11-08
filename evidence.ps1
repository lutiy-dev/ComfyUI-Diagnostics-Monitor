# ComfyUI Diagnostics Evidence Capture v0.6 LAB. On-demand, local, read-only.
# Captures normalized technical metadata only. No prompts, raw event messages, dumps or file contents.
[CmdletBinding()]
param(
 [ValidateSet('HOME','WORK')][string]$Machine='HOME',
 [string]$DataRoot=(Join-Path $env:LOCALAPPDATA 'ComfyUI-Diagnostics'),
 [string]$ComfyLog='',
 [ValidateRange(1,24)][int]$Hours=3,
 [switch]$SkipWindows,
 [switch]$SkipProcesses,
 [switch]$SkipStorage,
 [switch]$SkipComfy,
 [switch]$SelfTest
)
$ErrorActionPreference='Stop'
$now=[DateTime]::UtcNow
$report=[ordered]@{
 schema=2;kind='evidence_snapshot';machine=$Machine;created_utc=$now.ToString('o')
 sources=[ordered]@{};notes=@('Evidence is observational; event proximity is not causation.')
}
function SourceResult([string]$source,[scriptblock]$action) {
 try {
  $value=& $action
  $report.sources[$source]=@{status='OK';data=$value}
 } catch {
  # Do not persist potentially sensitive exception message or paths.
  $report.sources[$source]=@{status='UNAVAILABLE';error_code=$source.ToUpperInvariant()+'_READ_FAILED'}
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
 return $rows
}
if (-not $SkipProcesses) {
 SourceResult 'process_memory' {
  # Python workers are possible ComfyUI candidates, NOT an attribution without PID verification.
  $items=@(Get-Process -Name python,pythonw -ErrorAction SilentlyContinue | Select-Object -First 20)
  return @($items | ForEach-Object {
   @{pid=$_.Id;process_name=$_.ProcessName;cpu_seconds=$_.CPU;working_set_mib=[math]::Round($_.WorkingSet64/1MB,1);private_memory_mib=[math]::Round($_.PrivateMemorySize64/1MB,1);association='UNCONFIRMED'}
  })
 }
} else { $report.sources.process_memory=@{status='DISABLED'} }
if (-not $SkipStorage) {
 SourceResult 'storage' {
  return @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop | ForEach-Object {
    @{drive_type='FIXED';total_gib=[math]::Round($_.Size/1GB,1);free_gib=[math]::Round($_.FreeSpace/1GB,1)}
  })
 }
} else { $report.sources.storage=@{status='DISABLED'} }
if (-not $SkipWindows) {
 foreach($log in @('System','Application')) {
  SourceResult ('events_'+$log.ToLowerInvariant()) {
   $start=(Get-Date).AddHours(-$Hours)
   $records=@(Get-WinEvent -FilterHashtable @{LogName=$log;StartTime=$start;Level=@(1,2,3)} -MaxEvents 350 -ErrorAction Stop)
   $items=@()
   foreach($ev in $records) {
    if($log -eq 'System' -and $ev.ProviderName -notmatch 'Display|WHEA|Kernel-Power|disk|storport|nvlddmkm|BugCheck|volmgr|Ntfs|Kernel-PnP') { continue }
    if($log -eq 'Application' -and $ev.ProviderName -notmatch 'Application Error|Windows Error Reporting|Application Hang|\.NET Runtime|Python') { continue }
    $items+=@{time_utc=$ev.TimeCreated.ToUniversalTime().ToString('o');provider=[string]$ev.ProviderName;code=[int]$ev.Id;record_id=[long]$ev.RecordId;level=[int]$ev.Level;log=$log}
    if($items.Count -ge 100) {break}
   }
   return $items
  }
 }
 SourceResult 'reliability' {
  $rows=@(Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ReliabilityRecords -ErrorAction Stop |
    Where-Object { $_.TimeGenerated -ge (Get-Date).AddHours(-$Hours) } | Select-Object -First 60)
  return @($rows|ForEach-Object {
    # No Message/InsertionStrings/ProductName/FullPath in exported data.
    @{time_utc=$_.TimeGenerated.ToUniversalTime().ToString('o');event_id=[string]$_.EventIdentifier;source=[string]$_.SourceName;type=[string]$_.EventType}
  })
 }
} else {
 $report.sources.events_system=@{status='DISABLED'}
 $report.sources.events_application=@{status='DISABLED'}
 $report.sources.reliability=@{status='DISABLED'}
}
if (-not $SkipComfy) {
 SourceResult 'comfy_queue' {
  $result=Invoke-RestMethod -Uri 'http://127.0.0.1:8188/queue' -TimeoutSec 3 -ErrorAction Stop
  @{running=@($result.queue_running).Count;pending=@($result.queue_pending).Count;endpoint='localhost'}
 }
 SourceResult 'comfy_log_evidence' {
  if (-not $ComfyLog -or -not (Test-Path -LiteralPath $ComfyLog -PathType Leaf)) { throw 'ComfyUI log absent' }
  $file=Get-Item -LiteralPath $ComfyLog
  $hits=@()
  $lineNo=0
  foreach($line in @(Get-Content -LiteralPath $ComfyLog -Tail 1500 -ErrorAction Stop)) {
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
  @{status='OK';file_size_bytes=$file.Length;file_modified_utc=$file.LastWriteTimeUtc.ToString('o');file_sha256=(Get-FileHash -LiteralPath $ComfyLog -Algorithm SHA256).Hash;tail_lines_scanned=$lineNo;signatures=$hits;raw_text_excluded=$true}
 }
} else {
 $report.sources.comfy_queue=@{status='DISABLED'}
 $report.sources.comfy_log_evidence=@{status='DISABLED'}
}
$report.coverage=[ordered]@{available=@();missing=@();disabled=@()}
foreach($key in @($report.sources.Keys)) {
 $s=$report.sources[$key].status
 if($s -eq 'OK'){$report.coverage.available+= $key}
 elseif($s -eq 'DISABLED'){$report.coverage.disabled+= $key}
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
[IO.File]::WriteAllText($path,$payload,[Text.UTF8Encoding]::new($false))
Write-Host "PASS: Evidence snapshot written: $path"
Write-Host ('AVAILABLE='+$report.coverage.available.Count+' MISSING='+$report.coverage.missing.Count+' DISABLED='+$report.coverage.disabled.Count)
