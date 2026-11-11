$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\lib\ComfyHistory.ps1')
function Assert([bool]$ok,[string]$message){if(-not $ok){throw "FAIL: $message"}}
$synthetic='{"abc-123":{"outputs":{"5":{"images":[{"filename":"test.png","subfolder":"","type":"output"}]}},"prompt":[0,"abc-123",{"2":{"inputs":{"text":"SYNTHETIC_PRIVATE_PROMPT"}}}]}}' | ConvertFrom-Json
$items=@(ConvertFrom-ComfyHistory -History $synthetic -MaxItems 5)
Assert ($items.Count -eq 1) 'one output image'
Assert ($items[0].filename -eq 'test.png') 'image filename'
Assert ($items[0].prompt_text -match 'SYNTHETIC_PRIVATE_PROMPT') 'prompt visible only in memory'
Assert (($items[0] | ConvertTo-Json) -notmatch 'C:\\Users') 'no absolute paths'
$invalid='{"abc-123":{"outputs":{"5":{"images":[{"filename":"..\\secrets.png","subfolder":"","type":"output"},{"filename":"clean.png","subfolder":"../../client","type":"output"}]}}}}' | ConvertFrom-Json
Assert (@(ConvertFrom-ComfyHistory -History $invalid).Count -eq 0) 'reject invalid file paths'
$blocked=$false
try{Get-LocalComfyHistory -ComfyUrl 'https://example.org'|Out-Null}catch{$blocked=$true}
Assert $blocked 'reject non-local endpoints'
Write-Host 'PASS: opt-in ComfyUI history mapping, privacy and path safety (synthetic)'
