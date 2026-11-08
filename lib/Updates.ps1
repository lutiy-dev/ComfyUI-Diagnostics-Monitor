# GitHub release discovery only. No automatic download, execution, install or policy changes.
# Version comparison is independent from network access for deterministic tests.
function Compare-DiagnosticsVersion {
    param([Parameter(Mandatory=$true)][string]$Current,[Parameter(Mandatory=$true)][string]$Latest)
    $a=[regex]::Match($Current,'(?i)^v?(\d+)\.(\d+)\.(\d+)(?:-[a-z0-9.-]+)?$')
    $b=[regex]::Match($Latest,'(?i)^v?(\d+)\.(\d+)\.(\d+)(?:-[a-z0-9.-]+)?$')
    if (-not $a.Success -or -not $b.Success) { return 'UNKNOWN' }
    $v1=[version]::new([int]$a.Groups[1].Value,[int]$a.Groups[2].Value,[int]$a.Groups[3].Value)
    $v2=[version]::new([int]$b.Groups[1].Value,[int]$b.Groups[2].Value,[int]$b.Groups[3].Value)
    if ($v2 -gt $v1) { return 'UPDATE_AVAILABLE' }
    if ($v2 -eq $v1 -and $Current -match '-LAB' -and $Latest -notmatch '-') { return 'UPDATE_AVAILABLE' }
    return 'UP_TO_DATE'
}
function Get-DiagnosticsReleaseStatus {
    param([string]$CurrentVersion='0.5.0-LAB')
    $uri='https://api.github.com/repos/lutiy-dev/ComfyUI-Diagnostics-Monitor/releases/latest'
    try {
        $release=Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 8 -Headers @{
            'Accept'='application/vnd.github+json'
            'User-Agent'='ComfyUI-Diagnostics-LAB'
        } -ErrorAction Stop
        $link=[string]$release.html_url
        $tag=[string]$release.tag_name
        if ($link -notmatch '^https://github\.com/lutiy-dev/ComfyUI-Diagnostics-Monitor/releases/tag/[a-zA-Z0-9._-]+$') {
            return @{status='INVALID_METADATA';message='Release link failed validation'}
        }
        $decision=Compare-DiagnosticsVersion -Current $CurrentVersion -Latest $tag
        return @{status=$decision; version=$tag; url=$link}
    } catch {
        # Not distinguishable from offline, rate limit or no release without inspecting HTTP status.
        return @{status='UNAVAILABLE';message='No verified release information (offline, no release, or API unavailable).'}
    }
}
