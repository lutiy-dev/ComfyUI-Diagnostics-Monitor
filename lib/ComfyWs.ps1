# Read-only normalization of ComfyUI WebSocket messages. No prompts or exception text.
function ConvertFrom-ComfyWsEvent {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Json)
    try { $m=ConvertFrom-Json -InputObject $Json -ErrorAction Stop } catch { return $null }
    if ($null -eq $m -or $null -eq $m.type) { return $null }
    $kind=[string]$m.type
    $data=$m.data
    $record=[ordered]@{
        type=$kind
        node=$null
        prompt_id=$null
        current=$null
        total=$null
        error_code=$null
        queue_remaining=$null
    }
    if ($null -ne $data) {
        if ($null -ne $data.node) {
            $candidate=[string]$data.node
            if ($candidate -match '^[A-Za-z0-9_:-]{1,80}$') {
                $record.node=$candidate
            } else {
                $record.node='REDACTED'
            }
        }
        if ($null -ne $data.prompt_id) {
            $candidate=[string]$data.prompt_id
            if ($candidate -match '^[A-Za-z0-9_-]{1,80}$') {
                $record.prompt_id=$candidate
            } else {
                $record.prompt_id='REDACTED'
            }
        }
    }
    switch ($kind) {
        'executing' { return [pscustomobject]$record }
        'execution_start' { return [pscustomobject]$record }
        'execution_success' { return [pscustomobject]$record }
        'execution_interrupted' { return [pscustomobject]$record }
        'execution_error' {
            $candidate=[string]$data.exception_type
            if ($candidate -match '^[A-Za-z0-9_.]{1,100}$') {
                $record.error_code=$candidate
            } else {
                $record.error_code='EXECUTION_ERROR'
            }
            return [pscustomobject]$record
        }
        'progress' {
            if ($null -eq $data.value -or $null -eq $data.max) { return $null }
            try {
                $record.current=[int]$data.value
                $record.total=[int]$data.max
            } catch { return $null }
            return [pscustomobject]$record
        }
        'status' {
            if ($null -ne $data.status -and $null -ne $data.status.exec_info -and $null -ne $data.status.exec_info.queue_remaining) {
                try { $record.queue_remaining=[int]$data.status.exec_info.queue_remaining } catch {}
            }
            return [pscustomobject]$record
        }
        default { return $null }
    }
}
