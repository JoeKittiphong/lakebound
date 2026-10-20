param([string]$Manifest = "$PSScriptRoot/../../art/fish/collection-icons/manifest.json")
Add-Type -AssemblyName System.Drawing
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$entries = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$out = Join-Path $project 'assets/fish/icons'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$atlas = [Drawing.Bitmap]::new(1024,1024,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [Drawing.Graphics]::FromImage($atlas)
$graphics.Clear([Drawing.Color]::Transparent)
$graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
$graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
for ($i=0; $i -lt $entries.Count; $i++) {
 $entry = $entries[$i]
 $image = [Drawing.Image]::FromFile($entry.source)
 $x = ($i % 4)*256
 $y = [math]::Floor($i/4)*256
 $scale = [math]::Min(240.0/$image.Width,240.0/$image.Height)
 $width = [int]($image.Width*$scale)
 $height = [int]($image.Height*$scale)
 $rect = [Drawing.Rectangle]::new([int]($x+(256-$width)/2),[int]($y+(256-$height)/2),$width,$height)
 $graphics.DrawImage($image,$rect,0,0,$image.Width,$image.Height,[Drawing.GraphicsUnit]::Pixel)
 $image.Dispose()
 $resource = @"
[gd_resource type="AtlasTexture" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/fish/icons/fish_collection_atlas.png" id="atlas"]

[resource]
atlas = ExtResource("atlas")
region = Rect2($x, $($y + 40), 256, 176)
filter_clip = true
"@
 [IO.File]::WriteAllText((Join-Path $out ($entry.id+'.tres')),$resource,[Text.UTF8Encoding]::new($false))
 $path=Join-Path $project ('data/fish/'+$entry.id+'.tres')
 $text=[IO.File]::ReadAllText($path)
 if (-not $text.Contains('id="icon"')) {
  $text=$text.Replace('load_steps=3','load_steps=4').Replace('[resource]',('[ext_resource type="Texture2D" path="res://assets/fish/icons/'+$entry.id+'.tres" id="icon"]'+"`n`n[resource]"))
  $text=$text.Replace('model_scene = ExtResource("model")',('model_scene = ExtResource("model")'+"`n"+'collection_icon = ExtResource("icon")'))
  [IO.File]::WriteAllText($path,$text,[Text.UTF8Encoding]::new($false))
 }
}
$graphics.Dispose()
$atlas.Save((Join-Path $out 'fish_collection_atlas.png'),[Drawing.Imaging.ImageFormat]::Png)
$atlas.Dispose()
Write-Output "Packed $($entries.Count) icons into 1024x1024 atlas."

