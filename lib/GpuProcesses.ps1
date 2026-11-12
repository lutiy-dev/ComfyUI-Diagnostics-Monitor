# GPU Process Memory (WDDM): read-only live snapshot, NOT persistent telemetry.
# Only process short names, PIDs and Windows per-process GPU memory counters are used.
function Convert-GpuProcessMemoryRows {
 [CmdletBinding()]
 param([object[]]$Rows)
 $totals=@{}
 foreach($r in @($Rows)){
  $name=[string]$r.Name
  if($name -notmatch '(?i)(?:^|_)pid_(\d+)(?:_|$)'){continue}
  $pid=[int]$Matches[1]
  # Windows GPU perf counters can have multiple LUID/phys instances per process.
  # Values are counter allocations and may not sum to nvidia-smi device used VRAM.
  $d=0.0;$shared=0.0
  try{$d=[math]::Max(0,[double]$r.DedicatedUsage)}catch{}
  try{$shared=[math]::Max(0,[double]$r.SharedUsage)}catch{}
  if(-not $totals.ContainsKey($pid)){
   $totals[$pid]=[pscustomobject]@{Pid=$pid;DedicatedBytes=0.0;SharedBytes=0.0}
  }
  $totals[$pid].DedicatedBytes+=$d
  $totals[$pid].SharedBytes+=$shared
 }
 return @($totals.Values | Sort-Object DedicatedBytes -Descending)
}
function Get-GpuProcessSnapshot {
 [CmdletBinding()]
 param()
 try{
  # Standard WDDM performance-counter WMI class: independent of localized counter path names.
  $rows=@(Get-CimInstance -ClassName Win32_PerfRawData_GPUPerformanceCounters_GPUProcessMemory -Namespace root/cimv2 -ErrorAction Stop)
  $aggregated=@(Convert-GpuProcessMemoryRows -Rows $rows)
  $items=@()
  foreach($a in $aggregated){
   if($a.DedicatedBytes -le 0 -and $a.SharedBytes -le 0){continue}
   $name='[restricted]'
   try{
    $p=Get-Process -Id $a.Pid -ErrorAction Stop
    $name=[string]$p.ProcessName
   }catch{}
   $items+=[pscustomobject]@{
    Name=$name
    Pid=$a.Pid
    DedicatedMiB=[math]::Round($a.DedicatedBytes/1MB,1)
    SharedMiB=[math]::Round($a.SharedBytes/1MB,1)
   }
  }
  return [pscustomobject]@{
   Status='OK';Source='Windows WDDM GPU Process Memory';TimeUtc=[DateTime]::UtcNow.ToString('o')
   Processes=@($items | Sort-Object DedicatedMiB -Descending | Select-Object -First 60)
  }
 }catch{
  # Failing to read Windows counters must never be represented as zero usage.
  return [pscustomobject]@{Status='UNAVAILABLE';Source='Windows WDDM GPU Process Memory';TimeUtc=[DateTime]::UtcNow.ToString('o');Processes=@()}
 }
}
