# LAB v0.3 - local-only Windows/NVIDIA/ComfyUI collector. No admin or uploads.
param(
  [ValidateSet('HOME','WORK')][string]$Machine='HOME',
  [string]$ComfyLog='',
  [string]$ComfyUrl='http://127.0.0.1:8188',
  [string]$DataDir="$env:LOCALAPPDATA\ComfyUI-Diagnostics",
  [ValidateRange(3,300)][int]$IntervalSeconds=5,
  [ValidateRange(30,3600)][int]$EventIntervalSeconds=60,
  [ValidateRange(1,100)][int]$MaxFileMiB=20
)
$ErrorActionPreference='Continue'
$ProgressPreference='SilentlyContinue'
try { $uri=[uri]$ComfyUrl } catch { throw 'Invalid ComfyUrl' }
if ($uri.Scheme -ne 'http' -or $uri.Host -notin @('localhost','127.0.0.1','::1')) {
  throw 'ComfyUrl must use local HTTP'
}
$null=New-Item -ItemType Directory -Force -Path $DataDir
$stamp=Get-Date -Format 'yyyyMMdd'
$telemetry=Join-Path $DataDir "telemetry_${Machine}_$stamp.jsonl"
$events=Join-Path $DataDir "events_${Machine}_$stamp.jsonl"
$cursorPath=Join-Path $DataDir "cursor_$Machine.txt"
[long]$script:cursor=0
if (Test-Path -LiteralPath $cursorPath) {
  [long]$parsed=0
  if ([long]::TryParse(([IO.File]::ReadAllText($cursorPath)).Trim(),[ref]$parsed)) { $script:cursor=$parsed }
}
$script:lastQuery=[datetime]::MinValue
function Append-Record([string]$path,[object]$value) {
  $target=$path
  if ((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path).Length -ge ($MaxFileMiB*1MB))) {
    $target=Join-Path (Split-Path -Parent $path) (([IO.Path]::GetFileNameWithoutExtension($path)) + '_' + (Get-Date -Format 'HHmmssfff') + '.jsonl')
  }
  $json=ConvertTo-Json -InputObject $value -Compress -Depth 7
  [IO.File]::AppendAllText($target,$json+[Environment]::NewLine,(New-Object Text.UTF8Encoding($false)))
}
function Read-Gpu {
  $cmd=Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
  if (-not $cmd) { return @{status='UNAVAILABLE'} }
  try {
    $raw=& $cmd.Source '--query-gpu=index,name,driver_version,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw' '--format=csv,noheader,nounits' 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) { throw 'SMI returned no data' }
    $gpus=@()
    foreach ($line in @($raw)) {
      $p=@($line -split '\s*,\s*')
      if ($p.Count -eq 8) {
        $gpus+=@{index=$p[0];name=$p[1];driver=$p[2];util_pct=$p[3];vram_used_mib=$p[4];vram_total_mib=$p[5];temperature_c=$p[6];power_w=$p[7]}
      }
    }
    if ($gpus.Count -eq 0) { throw 'Unexpected SMI format' }
    return @{status='OK';gpus=$gpus}
  } catch { return @{status='ERROR';error_code='SMI_FAILED'} }
}
function Read-Comfy {
  try {
    $q=Invoke-RestMethod -Uri ($ComfyUrl.TrimEnd('/')+'/queue') -TimeoutSec 2 -ErrorAction Stop
    $running=0; $pending=0
    if ($null -ne $q.queue_running) { $running=@($q.queue_running).Count }
    if ($null -ne $q.queue_pending) { $pending=@($q.queue_pending).Count }
    return @{status='ONLINE';running=$running;pending=$pending}
  } catch { return @{status='OFFLINE'} }
}
function Read-Ram {
  try {
    $o=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    return @{used_mib=[math]::Round(($o.TotalVisibleMemorySize-$o.FreePhysicalMemory)/1024);total_mib=[math]::Round($o.TotalVisibleMemorySize/1024)}
  } catch { return @{status='UNAVAILABLE'} }
}
function Read-Cpu {
  try {
    $cpus=@(Get-CimInstance Win32_Processor -ErrorAction Stop)
    if ($cpus.Count -eq 0) { return @{status='UNAVAILABLE'} }
    $loads=@($cpus | ForEach-Object { if ($null -ne $_.LoadPercentage) { [double]$_.LoadPercentage } })
    if ($loads.Count -eq 0) { return @{status='UNAVAILABLE'} }
    $mean=[math]::Round((($loads | Measure-Object -Average).Average),1)
    return @{status='OK';util_pct=$mean}
  } catch { return @{status='UNAVAILABLE'} }
}
function Read-3dsMaxMemory {
  try {
    $procs=@(Get-Process -Name '3dsmax' -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) { return @{status='NOT_RUNNING';count=0} }
    [double]$ws=0
    [double]$private=0
    foreach($p in $procs) {
      $ws+=[double]$p.WorkingSet64
      $private+=[double]$p.PrivateMemorySize64
    }
    return @{status='OK';count=$procs.Count;working_set_mib=[math]::Round($ws/1MB);private_mib=[math]::Round($private/1MB)}
  } catch { return @{status='UNAVAILABLE'} }
}
function Read-LogSignature {
  if (-not $ComfyLog -or -not (Test-Path -LiteralPath $ComfyLog)) { return @{status='MISSING'} }
  try {
    $hits=@(Get-Content -LiteralPath $ComfyLog -Tail 250 -ErrorAction Stop | Where-Object {
      $_ -match 'CUDA error|out of memory|aimdo memory compile error|HostBuffer\.truncate failed|Exception during processing'
    })
    $signature=''
    if ($hits.Count -gt 0) {
      $last=$hits[-1]
      if ($last -match 'aimdo|HostBuffer') { $signature='AIMDO' }
      elseif ($last -match 'out of memory') { $signature='OOM' }
      elseif ($last -match 'CUDA') { $signature='CUDA' }
      else { $signature='PROCESSING_EXCEPTION' }
    }
    return @{status='OK';recent_matches=$hits.Count;last_signature=$signature}
  } catch { return @{status='ERROR'} }
}
function Read-WindowsEvents {
  if (((Get-Date)-$script:lastQuery).TotalSeconds -lt $EventIntervalSeconds) { return }
  $script:lastQuery=Get-Date
  try {
    $records=@(Get-WinEvent -FilterHashtable @{LogName='System';StartTime=(Get-Date).AddHours(-24)} -ErrorAction Stop |
      Where-Object {($_.ProviderName -eq 'Display' -and $_.Id -eq 4101) -or
        ($_.ProviderName -match 'WHEA-Logger') -or
        ($_.ProviderName -eq 'Microsoft-Windows-Kernel-Power' -and $_.Id -eq 41)} |
      Sort-Object RecordId)
    foreach ($ev in $records) {
      if ([long]$ev.RecordId -le $script:cursor) { continue }
      Append-Record $events @{schema=1;machine=$Machine;source='Windows';event_utc=$ev.TimeCreated.ToUniversalTime().ToString('o');record_id=$ev.RecordId;provider=$ev.ProviderName;code=$ev.Id;severity=$ev.LevelDisplayName}
      $script:cursor=[long]$ev.RecordId
    }
    [IO.File]::WriteAllText($cursorPath,[string]$script:cursor)
  } catch { Write-Warning 'Windows Event Log collection unavailable' }
}
Write-Host "ComfyUI Diagnostics LAB v0.3 | $Machine | local only"
Write-Host "Data: $DataDir | Ctrl+C to stop"
while ($true) {
  try {
    Append-Record $telemetry @{schema=1;machine=$Machine;source='collector';timestamp_utc=(Get-Date).ToUniversalTime().ToString('o');gpu=(Read-Gpu);ram=(Read-Ram);cpu=(Read-Cpu);max_memory=(Read-3dsMaxMemory);comfy=(Read-Comfy);comfy_log=(Read-LogSignature)}
    Read-WindowsEvents
  } catch { Write-Warning 'Collection cycle failed' }
  Start-Sleep -Seconds $IntervalSeconds
}
