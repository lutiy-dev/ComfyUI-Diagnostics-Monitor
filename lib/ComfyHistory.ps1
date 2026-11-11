# Local-only read-only ComfyUI history adapter for user-triggered result review.
# Prompts and images are NEVER written to diagnostic JSONL or GitHub.
function ConvertFrom-ComfyHistory {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$History,[ValidateRange(1,100)][int]$MaxItems=30)
    $results=New-Object 'System.Collections.Generic.List[object]'
    foreach($entry in @($History.PSObject.Properties)) {
        if($results.Count -ge $MaxItems){break}
        $id=[string]$entry.Name
        if($id -notmatch '^[A-Za-z0-9_-]{1,80}$'){continue}
        $run=$entry.Value
        if($null -eq $run.outputs){continue}
        $promptText=''
        if($null -ne $run.prompt -and @($run.prompt).Count -ge 3){
            $nodes=$run.prompt[2]
            if($null -ne $nodes){
                $texts=New-Object 'System.Collections.Generic.List[string]'
                foreach($node in @($nodes.PSObject.Properties)){
                    if($null -eq $node.Value.inputs){continue}
                    foreach($key in @('text','positive','negative','prompt')){
                        $value=$node.Value.inputs.$key
                        if($value -is [string] -and $value.Length -gt 0 -and $texts.Count -lt 30){
                            $texts.Add(($key+': '+$value))
                        }
                    }
                }
                $promptText=($texts -join [Environment]::NewLine)
                if($promptText.Length -gt 20000){$promptText=$promptText.Substring(0,20000)+'...'}
            }
        }
        foreach($output in @($run.outputs.PSObject.Properties)){
            if($results.Count -ge $MaxItems){break}
            foreach($img in @($output.Value.images)){
                if($null -eq $img -or $results.Count -ge $MaxItems){break}
                $filename=[string]$img.filename
                $subfolder=[string]$img.subfolder
                $type=[string]$img.type
                if([string]::IsNullOrWhiteSpace($filename) -or $filename.Length -gt 180 -or
                   $filename -match '[\\/:*?"<>|]' -or $subfolder -match '(^|[\\/])\.\.([\\/]|$)' -or
                   $subfolder -match '[:*?"<>|]' -or $type -notin @('output','temp')){continue}
                $results.Add([pscustomobject]@{
                    prompt_id=$id
                    filename=$filename
                    subfolder=$subfolder
                    type=$type
                    prompt_text=$promptText
                })
            }
        }
    }
    return @($results)
}
function Get-LocalComfyHistory {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$ComfyUrl)
    $uri=[uri]$ComfyUrl
    if($uri.Scheme -ne 'http' -or $uri.Host -notin @('localhost','127.0.0.1','::1') -or $uri.UserInfo){
        throw 'STOP: only unauthenticated localhost ComfyUI is allowed'
    }
    $response=Invoke-RestMethod -Uri ($ComfyUrl.TrimEnd('/')+'/history?max_items=30') -Method Get -TimeoutSec 6 -ErrorAction Stop
    ConvertFrom-ComfyHistory -History $response -MaxItems 30
}
function Get-LocalComfyPreview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ComfyUrl,
        [Parameter(Mandatory=$true)][string]$Filename,
        [string]$Subfolder='',
        [ValidateSet('output','temp')][string]$Type='output'
    )
    $uri=[uri]$ComfyUrl
    if($uri.Scheme -ne 'http' -or $uri.Host -notin @('localhost','127.0.0.1','::1') -or $uri.UserInfo){throw 'STOP: localhost only'}
    if($Filename -match '[\\/:*?"<>|]' -or $Filename.Length -gt 180 -or
       $Subfolder -match '(^|[\\/])\.\.([\\/]|$)' -or $Subfolder -match '[:*?"<>|]'){throw 'STOP: invalid asset name'}
    $url=$ComfyUrl.TrimEnd('/')+'/view?filename='+[uri]::EscapeDataString($Filename)+
         '&subfolder='+[uri]::EscapeDataString($Subfolder)+'&type='+[uri]::EscapeDataString($Type)
    $req=[Net.HttpWebRequest]::Create($url)
    $req.AllowAutoRedirect=$false
    $req.Timeout=6000
    $req.ReadWriteTimeout=6000
    $response=$req.GetResponse()
    try {
        if($response.ContentLength -gt 16MB){throw 'STOP: preview exceeds 16 MiB'}
        $stream=$response.GetResponseStream()
        $memory=New-Object IO.MemoryStream
        try {
            $buf=New-Object byte[] 32768
            $total=0
            while(($n=$stream.Read($buf,0,$buf.Length)) -gt 0){
                $total+=$n
                if($total -gt 16MB){throw 'STOP: preview exceeds 16 MiB'}
                $memory.Write($buf,0,$n)
            }
            return ,$memory.ToArray()
        } finally {$stream.Dispose();$memory.Dispose()}
    } finally {$response.Dispose()}
}
