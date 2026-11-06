#!/usr/bin/env python3
"""QA contact sheet: equal1000px CN-body width, no scientific image content altered."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
C=Path(__file__).resolve().parents[1];F=C/'results/figures/fig3a-t2';N=C/'results/figures/scgv-native';font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',24)
# Original publisher figure is retained whole; only this explicitly documented QA crop isolates T2.
items=[('Published Fig.3a left (T2)',Image.open(C/'sources/publisher-Fig3.png').convert('RGB').crop((0,0,1000,640)),124,860),('Original SCGV views; recomputed public-code tree',Image.open(N/'scgv-native.png').convert('RGB'),16/180*2125,134/180*2125),('Final R layout port; same frozen CN and tree coordinates',Image.open(F/'fig3a-t2.png').convert('RGB'),218,133.256653777422/180*2125)]
blocks=[];records=[]
for title,im,left,bw in items:
 ratio=1000/bw;scaled=im.resize((round(im.width*ratio),round(im.height*ratio)),Image.Resampling.LANCZOS);offset=round(200-left*ratio);block=Image.new('RGB',(1500,scaled.height+48),'white');block.paste(scaled,(offset,48));ImageDraw.Draw(block).text((20,10),title,font=font,fill='#252A31');blocks.append(block);records.append(dict(label=title,input_size=list(im.size),source_body_width_px=bw,scale=ratio,target_body_width_px=1000,body_left_px=200,source_crop=[0,0,1000,640]if title.startswith('Published')else None))
canvas=Image.new('RGB',(1500,sum(x.height for x in blocks)+20*(len(blocks)-1)),'#E7EBEE');y=0
for b in blocks:canvas.paste(b,(0,y));y+=b.height+20
canvas.save(F/'source-comparison.png');(C/'validation/fig3a-t2/source-comparison-layout.json').write_text(json.dumps({'purpose':'equal-CN-body-width source/native/R visual review; does not assert original numerical NJ-tree identity','records':records},indent=2))
