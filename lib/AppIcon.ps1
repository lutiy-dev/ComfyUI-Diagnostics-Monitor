# Original ComfyUI Diagnostics Monitor icon generator (PowerShell 5.1 / System.Drawing).
# Produces local .ico without requiring external binary assets, fonts or downloads.
function New-ComfyDiagnosticsIcon {
 [CmdletBinding()]
 param([Parameter(Mandatory=$true)][string]$Path)
 Add-Type -AssemblyName System.Drawing
 $images=New-Object 'System.Collections.Generic.List[byte[]]'
 foreach($size in @(32,48,256)) {
  $bitmap=New-Object System.Drawing.Bitmap($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics=[Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.Clear([Drawing.Color]::Transparent)
  $dark=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255,20,26,34))
  $cyan=New-Object Drawing.Pen([Drawing.Color]::FromArgb(255,36,195,249),([single]($size*0.065)))
  $orange=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255,246,151,40))
  $rim=New-Object Drawing.Pen([Drawing.Color]::FromArgb(255,84,100,117),([single]($size*0.04)))
  try {
   $graphics.FillRectangle($dark,0,0,$size,$size)
   $margin=[single]($size*0.09)
   $graphics.DrawRectangle($rim,$margin,$margin,([single]($size-2*$margin)),([single]($size-2*$margin)))
   $points=[Drawing.PointF[]]@(
    [Drawing.PointF]::new([single]($size*0.16),[single]($size*0.57)),
    [Drawing.PointF]::new([single]($size*0.34),[single]($size*0.57)),
    [Drawing.PointF]::new([single]($size*0.43),[single]($size*0.33)),
    [Drawing.PointF]::new([single]($size*0.53),[single]($size*0.70)),
    [Drawing.PointF]::new([single]($size*0.65),[single]($size*0.48)),
    [Drawing.PointF]::new([single]($size*0.84),[single]($size*0.48))
   )
   $graphics.DrawLines($cyan,$points)
   $d=[single]($size*0.15)
   $graphics.FillEllipse($orange,([single]($size*0.74)),([single]($size*0.19)),$d,$d)
   $stream=New-Object IO.MemoryStream
   try {
    $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
    $images.Add($stream.ToArray())
   } finally { $stream.Dispose() }
  } finally {
   $rim.Dispose();$orange.Dispose();$cyan.Dispose();$dark.Dispose()
   $graphics.Dispose();$bitmap.Dispose()
  }
 }
 $directory=Split-Path -Parent $Path
 if(-not (Test-Path -LiteralPath $directory)){ $null=New-Item -ItemType Directory -Force -Path $directory }
 $file=[IO.File]::Open($Path,[IO.FileMode]::Create,[IO.FileAccess]::Write)
 $writer=New-Object IO.BinaryWriter($file)
 try {
  $writer.Write([uint16]0)
  $writer.Write([uint16]1)
  $writer.Write([uint16]$images.Count)
  [uint32]$offset=6+16*$images.Count
  for($i=0;$i -lt $images.Count;$i++){
   $size=@(32,48,256)[$i]
   $writer.Write([byte]($size % 256))
   $writer.Write([byte]($size % 256))
   $writer.Write([byte]0)
   $writer.Write([byte]0)
   $writer.Write([uint16]1)
   $writer.Write([uint16]32)
   $writer.Write([uint32]$images[$i].Length)
   $writer.Write([uint32]$offset)
   $offset+=[uint32]$images[$i].Length
  }
  foreach($img in $images){$writer.Write([byte[]]$img)}
 } finally {$writer.Dispose();$file.Dispose()}
 # Fail closed if .NET cannot parse the icon it just generated.
 $icon=[Drawing.Icon]::new($Path)
 try {
  if($icon.Width -lt 16 -or $icon.Height -lt 16){throw 'Icon dimensions invalid'}
 } finally {$icon.Dispose()}
 Write-Host "PASS: icon generated and validated at $Path"
}
