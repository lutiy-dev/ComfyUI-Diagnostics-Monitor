$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\lib\ComfyWs.ps1')
function Assert($condition,$message) {
    if (-not $condition) { throw "FAIL: $message" }
}
$executing=ConvertFrom-ComfyWsEvent '{"type":"executing","data":{"node":"42","prompt_id":"abc-123"}}'
Assert ($executing.type -eq 'executing' -and $executing.node -eq '42') 'executing node'
$progress=ConvertFrom-ComfyWsEvent '{"type":"progress","data":{"value":3,"max":20}}'
Assert ($progress.current -eq 3 -and $progress.total -eq 20) 'sampler progress'
$completion=ConvertFrom-ComfyWsEvent '{"type":"executing","data":{"node":null}}'
Assert ($null -eq $completion.node) 'idle node'
$err=ConvertFrom-ComfyWsEvent '{"type":"execution_error","data":{"exception_type":"torch.AcceleratorError","exception_message":"PRIVATE PROMPT PATH C:\\Users\\client","node_id":"42"}}'
Assert ($err.error_code -eq 'torch.AcceleratorError') 'normalized error'
Assert ((($err | ConvertTo-Json) -notmatch 'PRIVATE|client')) 'private exception message discarded'
$masked=ConvertFrom-ComfyWsEvent '{"type":"executing","data":{"node":"private prompt text"}}'
Assert ($masked.node -eq 'REDACTED') 'node sanitized'
$invalid=ConvertFrom-ComfyWsEvent 'not json'
Assert ($null -eq $invalid) 'invalid JSON ignored'
$unrecognized=ConvertFrom-ComfyWsEvent '{"type":"b_preview","data":{"prompt":"secret"}}'
Assert ($null -eq $unrecognized) 'unknown message ignored'
Write-Host 'PASS: WebSocket normalization and redaction'
