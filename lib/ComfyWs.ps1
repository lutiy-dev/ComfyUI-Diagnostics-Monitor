# Read-only normalization of ComfyUI WebSocket messages. Does not persist prompts.
function ConvertFrom-ComfyWsEvent {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Json)
    try { $m = ConvertFrom-Json -InputObject $Json -ErrorAction Stop } catch { return $null }
    if ($null -eq $m -or $null -eq $m.type) { return $null }
    $kind = [string]$m.type
    $data = $m.data
    $record = [ordered]@{
        type = $kind
        node = $null
        prompt_id = $null
        current = $null
        total = $null
        error_code = $null
        queue_remaining = $null
    }
    if ($null -ne $data) {
        if ($null -ne $data.node) {
            $candidate = [string]$data.node
            $record.node = if ($candidate -match '^[A-Za-z0-9_:-]{1,80}
        if ($null -ne $data.prompt_id) {
            $candidate = [string]$data.prompt_id
            $record.prompt_id = if ($candidate -match '^[A-Za-z0-9_-]{1,80}
    }
    switch ($kind) {
        'executing' { return [pscustomobject]$record }
        'execution_start' { return [pscustomobject]$record }
        'execution_success' { return [pscustomobject]$record }
        'execution_interrupted' { return [pscustomobject]$record }
        'execution_error' {
            $candidate = [string]$data.exception_type
            $record.error_code = if ($candidate -match '^[A-Za-z0-9_.]{1,100}
            return [pscustomobject]$record
        }
        'progress' {
            if ($null -eq $data.value -or $null -eq $data.max) { return $null }
            $record.current = [int]$data.value
            $record.total = [int]$data.max
            return [pscustomobject]$record
        }
        'progress_state' {
            # Some ComfyUI versions send per-node progress here; ignore unknown schema safely.
            return $null
        }
        'status' {
            if ($null -ne $data.status -and $null -ne $data.status.exec_info) {
                if ($null -ne $data.status.exec_info.queue_remaining) {
                    $record.queue_remaining = [int]$data.status.exec_info.queue_remaining
                }
            }
            return [pscustomobject]$record
        }
        default { return $null }
    }
}
) { $candidate } else { 'REDACTED' }
        }
        if ($null -ne $data.prompt_id) { $record.prompt_id = [string]$data.prompt_id }
    }
    switch ($kind) {
        'executing' { return [pscustomobject]$record }
        'execution_start' { return [pscustomobject]$record }
        'execution_success' { return [pscustomobject]$record }
        'execution_interrupted' { return [pscustomobject]$record }
        'execution_error' {
            $record.error_code = if ($null -ne $data.exception_type) { [string]$data.exception_type } else { 'EXECUTION_ERROR' }
            return [pscustomobject]$record
        }
        'progress' {
            if ($null -eq $data.value -or $null -eq $data.max) { return $null }
            $record.current = [int]$data.value
            $record.total = [int]$data.max
            return [pscustomobject]$record
        }
        'progress_state' {
            # Some ComfyUI versions send per-node progress here; ignore unknown schema safely.
            return $null
        }
        'status' {
            if ($null -ne $data.status -and $null -ne $data.status.exec_info) {
                if ($null -ne $data.status.exec_info.queue_remaining) {
                    $record.queue_remaining = [int]$data.status.exec_info.queue_remaining
                }
            }
            return [pscustomobject]$record
        }
        default { return $null }
    }
}
) { $candidate } else { 'REDACTED' }
        }
    }
    switch ($kind) {
        'executing' { return [pscustomobject]$record }
        'execution_start' { return [pscustomobject]$record }
        'execution_success' { return [pscustomobject]$record }
        'execution_interrupted' { return [pscustomobject]$record }
        'execution_error' {
            $record.error_code = if ($null -ne $data.exception_type) { [string]$data.exception_type } else { 'EXECUTION_ERROR' }
            return [pscustomobject]$record
        }
        'progress' {
            if ($null -eq $data.value -or $null -eq $data.max) { return $null }
            $record.current = [int]$data.value
            $record.total = [int]$data.max
            return [pscustomobject]$record
        }
        'progress_state' {
            # Some ComfyUI versions send per-node progress here; ignore unknown schema safely.
            return $null
        }
        'status' {
            if ($null -ne $data.status -and $null -ne $data.status.exec_info) {
                if ($null -ne $data.status.exec_info.queue_remaining) {
                    $record.queue_remaining = [int]$data.status.exec_info.queue_remaining
                }
            }
            return [pscustomobject]$record
        }
        default { return $null }
    }
}
) { $candidate } else { 'REDACTED' }
        }
        if ($null -ne $data.prompt_id) { $record.prompt_id = [string]$data.prompt_id }
    }
    switch ($kind) {
        'executing' { return [pscustomobject]$record }
        'execution_start' { return [pscustomobject]$record }
        'execution_success' { return [pscustomobject]$record }
        'execution_interrupted' { return [pscustomobject]$record }
        'execution_error' {
            $record.error_code = if ($null -ne $data.exception_type) { [string]$data.exception_type } else { 'EXECUTION_ERROR' }
            return [pscustomobject]$record
        }
        'progress' {
            if ($null -eq $data.value -or $null -eq $data.max) { return $null }
            $record.current = [int]$data.value
            $record.total = [int]$data.max
            return [pscustomobject]$record
        }
        'progress_state' {
            # Some ComfyUI versions send per-node progress here; ignore unknown schema safely.
            return $null
        }
        'status' {
            if ($null -ne $data.status -and $null -ne $data.status.exec_info) {
                if ($null -ne $data.status.exec_info.queue_remaining) {
                    $record.queue_remaining = [int]$data.status.exec_info.queue_remaining
                }
            }
            return [pscustomobject]$record
        }
        default { return $null }
    }
}
) { $candidate } else { 'EXECUTION_ERROR' }
            return [pscustomobject]$record
        }
        'progress' {
            if ($null -eq $data.value -or $null -eq $data.max) { return $null }
            $record.current = [int]$data.value
            $record.total = [int]$data.max
            return [pscustomobject]$record
        }
        'progress_state' {
            # Some ComfyUI versions send per-node progress here; ignore unknown schema safely.
            return $null
        }
        'status' {
            if ($null -ne $data.status -and $null -ne $data.status.exec_info) {
                if ($null -ne $data.status.exec_info.queue_remaining) {
                    $record.queue_remaining = [int]$data.status.exec_info.queue_remaining
                }
            }
            return [pscustomobject]$record
        }
        default { return $null }
    }
}
) { $candidate } else { 'REDACTED' }
        }
        if ($null -ne $data.prompt_id) { $record.prompt_id = [string]$data.prompt_id }
    }
    switch ($kind) {
        'executing' { return [pscustomobject]$record }
        'execution_start' { return [pscustomobject]$record }
        'execution_success' { return [pscustomobject]$record }
        'execution_interrupted' { return [pscustomobject]$record }
        'execution_error' {
            $record.error_code = if ($null -ne $data.exception_type) { [string]$data.exception_type } else { 'EXECUTION_ERROR' }
            return [pscustomobject]$record
        }
        'progress' {
            if ($null -eq $data.value -or $null -eq $data.max) { return $null }
            $record.current = [int]$data.value
            $record.total = [int]$data.max
            return [pscustomobject]$record
        }
        'progress_state' {
            # Some ComfyUI versions send per-node progress here; ignore unknown schema safely.
            return $null
        }
        'status' {
            if ($null -ne $data.status -and $null -ne $data.status.exec_info) {
                if ($null -ne $data.status.exec_info.queue_remaining) {
                    $record.queue_remaining = [int]$data.status.exec_info.queue_remaining
                }
            }
            return [pscustomobject]$record
        }
        default { return $null }
    }
}
) { $candidate } else { 'REDACTED' }
        }
    }
    switch ($kind) {
        'executing' { return [pscustomobject]$record }
        'execution_start' { return [pscustomobject]$record }
        'execution_success' { return [pscustomobject]$record }
        'execution_interrupted' { return [pscustomobject]$record }
        'execution_error' {
            $record.error_code = if ($null -ne $data.exception_type) { [string]$data.exception_type } else { 'EXECUTION_ERROR' }
            return [pscustomobject]$record
        }
        'progress' {
            if ($null -eq $data.value -or $null -eq $data.max) { return $null }
            $record.current = [int]$data.value
            $record.total = [int]$data.max
            return [pscustomobject]$record
        }
        'progress_state' {
            # Some ComfyUI versions send per-node progress here; ignore unknown schema safely.
            return $null
        }
        'status' {
            if ($null -ne $data.status -and $null -ne $data.status.exec_info) {
                if ($null -ne $data.status.exec_info.queue_remaining) {
                    $record.queue_remaining = [int]$data.status.exec_info.queue_remaining
                }
            }
            return [pscustomobject]$record
        }
        default { return $null }
    }
}
) { $candidate } else { 'REDACTED' }
        }
        if ($null -ne $data.prompt_id) { $record.prompt_id = [string]$data.prompt_id }
    }
    switch ($kind) {
        'executing' { return [pscustomobject]$record }
        'execution_start' { return [pscustomobject]$record }
        'execution_success' { return [pscustomobject]$record }
        'execution_interrupted' { return [pscustomobject]$record }
        'execution_error' {
            $record.error_code = if ($null -ne $data.exception_type) { [string]$data.exception_type } else { 'EXECUTION_ERROR' }
            return [pscustomobject]$record
        }
        'progress' {
            if ($null -eq $data.value -or $null -eq $data.max) { return $null }
            $record.current = [int]$data.value
            $record.total = [int]$data.max
            return [pscustomobject]$record
        }
        'progress_state' {
            # Some ComfyUI versions send per-node progress here; ignore unknown schema safely.
            return $null
        }
        'status' {
            if ($null -ne $data.status -and $null -ne $data.status.exec_info) {
                if ($null -ne $data.status.exec_info.queue_remaining) {
                    $record.queue_remaining = [int]$data.status.exec_info.queue_remaining
                }
            }
            return [pscustomobject]$record
        }
        default { return $null }
    }
}
