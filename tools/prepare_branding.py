"""Mechanical export of source artwork to Android/Play dimensions."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(root / 'shared/branding/icon-source.png').convert('RGBA')
for target, size in [('shared/branding/icon.png',512),
                     ('shared/branding/adaptive_foreground.png',432),
                     ('exports/play-store/icon-512.png',512)]:
    source.resize((size,size),Image.Resampling.LANCZOS).save(root / target,optimize=True)
Image.new('RGB',(432,432),(5,91,111)).save(root/'shared/branding/adaptive_background.png')
for name in ['icon-512.png']:
    path=root/'exports/play-store'/name
    print(name,Image.open(path).size,path.stat().st_size)
feature = root/'docs/play-store/feature-source.png'
if feature.exists():
    Image.open(feature).convert('RGB').resize((1024,500),Image.Resampling.LANCZOS).save(root/'exports/play-store/feature-1024x500.png',optimize=True)
