"""Original, text-free bitmap glyph artwork. No OS font/emoji dependency."""
from pathlib import Path
from PIL import Image, ImageDraw
import math
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'shared/ui/fonts/symbols'; OUT.mkdir(parents=True,exist_ok=True)
CHARS='·×–—•…‹›←↑→↓↗−▲▼◆○●✓'
SCALE=4; CELL=96
atlas=Image.new('RGBA',(CELL*8*SCALE,CELL*3*SCALE))
records=[]
for i,ch in enumerate(CHARS):
 tile=Image.new('RGBA',(64*SCALE,64*SCALE)); d=ImageDraw.Draw(tile)
 def poly(points): d.polygon([(round(x*SCALE),round(y*SCALE)) for x,y in points],fill='white')
 def line(points,width=6):
  points=[(round(x*SCALE),round(y*SCALE)) for x,y in points]
  d.line(points,fill='white',width=width*SCALE,joint='curve')
  r=width*SCALE/2
  for x,y in points: d.ellipse((x-r,y-r,x+r,y+r),fill='white')
 def circle(box,solid=True):
  box=tuple(round(v*SCALE) for v in box)
  d.ellipse(box,fill='white' if solid else None,outline=None if solid else 'white',width=5*SCALE)
 if ch in '←↑→↓↗':
  angle={'→':0,'↓':math.pi/2,'←':math.pi,'↑':-math.pi/2,'↗':-math.pi/4}[ch]
  pts=[(8,27),(38,27),(38,15),(57,32),(38,49),(38,37),(8,37)]
  poly([(32+(x-32)*math.cos(angle)-(y-32)*math.sin(angle),32+(x-32)*math.sin(angle)+(y-32)*math.cos(angle)) for x,y in pts])
 elif ch=='✓': line([(10,33),(25,47),(55,15)],7)
 elif ch in '‹›': line([(40,12),(21,32),(40,52)] if ch=='‹' else [(24,12),(43,32),(24,52)],6)
 elif ch=='×': line([(16,16),(48,48)]);line([(48,16),(16,48)])
 elif ch in '–—−': line([(8,32),(56,32)],5)
 elif ch in '·•': circle((26,26,38,38) if ch=='·' else (23,23,41,41))
 elif ch=='…':
  for x in [12,32,52]: circle((x-4,40,x+4,48))
 elif ch=='▲':poly([(32,8),(59,55),(5,55)])
 elif ch=='▼':poly([(5,9),(59,9),(32,56)])
 elif ch=='◆':poly([(32,5),(59,32),(32,59),(5,32)])
 elif ch in '○●':circle((9,9,55,55),ch=='●')
 tile=tile.resize((64,64),Image.Resampling.LANCZOS)
 x=(i%8)*CELL+16;y=(i//8)*CELL+16
 # Store at final size after all artwork is supersampled.
 atlas.alpha_composite(tile.resize((256,256),Image.Resampling.NEAREST),(x*SCALE,y*SCALE))
 advance=32 if ch in '·•' else 64
 # Small punctuation crops maintain sensible inline spacing.
 cropx=16 if ch in '·•' else 0
 records.append(f'char id={ord(ch)} x={x+cropx} y={y} width={advance} height=64 xoffset=0 yoffset=8 xadvance={advance} page=0 chnl=15')
atlas=atlas.resize((CELL*8,CELL*3),Image.Resampling.LANCZOS)
atlas.save(OUT/'ui_symbols.png')
(OUT/'ui_symbols.fnt').write_text('info face="Lakebound UI Symbols" size=64 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=0,0\ncommon lineHeight=88 base=68 scaleW=768 scaleH=288 pages=1 packed=0\npage id=0 file="ui_symbols.png"\nchars count=%d\n%s\n'%(len(records),'\n'.join(records)),encoding='utf-8')
print('Authored',len(records),'bitmap symbols')
