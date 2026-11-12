$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\lib\GpuProcesses.ps1')
function Assert($condition,[string]$message){if(-not $condition){throw "FAIL: $message"}}
$rows=@(
 [pscustomobject]@{Name='pid_1408_luid_0x000001_0x000000_physical_0';DedicatedUsage=104857600;SharedUsage=10485760},
 [pscustomobject]@{Name='pid_1408_luid_0x000001_0x000000_physical_1';DedicatedUsage=52428800;SharedUsage=0},
 [pscustomobject]@{Name='pid_2000_luid_0x000001_0x000000_physical_0';DedicatedUsage=20971520;SharedUsage=5242880},
 [pscustomobject]@{Name='not-a-gpu-instance';DedicatedUsage=1000000;SharedUsage=0}
)
$results=@(Convert-GpuProcessMemoryRows -Rows $rows)
Assert ($results.Count -eq 2) 'invalid instance is rejected and repeated PID is grouped'
Assert ($results[0].Pid -eq 1408) 'largest dedicated VRAM should sort first'
Assert ($results[0].DedicatedBytes -eq 157286400) 'same PID allocation aggregation'
Assert ($results[0].SharedBytes -eq 10485760) 'shared bytes are retained separately'
Assert ($results[1].DedicatedBytes -eq 20971520) 'second process allocation'
$empty=@(Convert-GpuProcessMemoryRows -Rows @())
Assert ($empty.Count -eq 0) 'empty counter input'
# On Windows without a GPU driver/counter, a snapshot must fail neutral, not pretend 0 usage.
$snapshot=Get-GpuProcessSnapshot
Assert ($snapshot.Status -in @('OK','UNAVAILABLE')) 'source has explicit status'
Assert ($snapshot.Source -eq 'Windows WDDM GPU Process Memory') 'source is explicit'
if ($snapshot.Status -eq 'UNAVAILABLE') {
 Assert (@($snapshot.Processes).Count -eq 0) 'unavailable must not invent processes'
}
Write-Host 'PASS: per-process WDDM grouping, null-source fallback, source and privacy fields'
