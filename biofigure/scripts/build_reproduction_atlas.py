#!/usr/bin/env python3
"""Build a provenance-bound, code-free atlas from curated reproduction cases."""
from __future__ import annotations
import argparse, hashlib, json, re
from collections import Counter
from pathlib import Path
from PIL import Image

FEATURES=['geom_point','geom_line','geom_col','geom_bar','geom_tile','geom_boxplot','geom_violin','geom_density','geom_ribbon','geom_segment','geom_text','geom_label','Heatmap','circos','ggtree','ggsurvplot','survfit','plot_ly','facet_wrap','facet_grid','inset_element','plot_layout']

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def chart_tags(title):
 t=title.lower(); tags=[]
 groups=[('matrix',['热图','matrix']),('time-to-event',['生存']),('time-series',['时间序列','折线']),('distribution',['箱线','小提琴','云雨','山脊']),('network',['网络']),('tree',['系统发育','树']),('circular',['环状','和弦','饼图','旭日','花瓣']),('composition',['堆积','占比']),('association',['相关','散点']),('clinical',['泳道','森林','临床']),('enrichment',['富集','gsea']),('single-cell',['单细胞','umap']),('genome',['染色体','突变']),('map',['地图'])]
 for tag,keys in groups:
  if any(k in t for k in keys): tags.append(tag)
 return tags or ['general-statistical']

def analyze_code_texts(parts):
 joined='\n'.join(text for _,text in parts); packages=set()
 for name,text in parts:
  if name.lower().endswith('.r'):
   packages.update(re.findall(r'(?:library|require)\s*\(\s*["\']?([A-Za-z0-9_.]+)',text))
   packages.update(re.findall(r'([A-Za-z][A-Za-z0-9_.]+)::[A-Za-z0-9_.]+',text))
  elif name.lower().endswith('.py'):
   packages.update(re.findall(r'^\s*(?:from|import)\s+([A-Za-z0-9_.]+)',text,re.M))
 rules=[('layered-grammar',r'ggplot\s*\(|geom_[A-Za-z0-9_]+\s*\('),('explicit-palette',r'#[0-9A-Fa-f]{6}\b|scale_(?:color|colour|fill)_manual'),
        ('faceted-small-multiples',r'facet_(?:wrap|grid)'),('coordinate-transformation',r'coord_(?:polar|fixed|flip|equal)'),
        ('plot-composition',r'plot_layout|wrap_plots|inset_element|ggarrange'),('annotation-layering',r'geom_(?:text|label|segment)|annotate\s*\('),
        ('statistical-summary-layer',r'stat_summary|geom_(?:errorbar|ribbon)|survfit'),('label-collision-control',r'geom_(?:text|label)_repel')]
 techniques=[name for name,pattern in rules if re.search(pattern,joined,re.I)]
 return {'file_count':len(parts),'packages':sorted(packages),'primitives':[x for x in FEATURES if x.lower() in joined.lower()],
         'coding_techniques':techniques,
         'hex_colors':list(dict.fromkeys(re.findall(r'#[0-9A-Fa-f]{6}\b',joined)))[:16],
         'combined_sha256':hashlib.sha256('\n'.join(f'{n}\0{t}' for n,t in parts).encode()).hexdigest(),
         'raw_code_embedded':False}

def visual_profile(path,text=''):
 p=Path(path)
 with Image.open(p) as im:
  rgb=im.convert('RGB'); thumb=rgb.copy();thumb.thumbnail((240,240)); colors=Counter(thumb.get_flattened_data())
 palette=[]
 for color,_ in colors.most_common(80):
  if max(color)>245 and min(color)>245: continue
  hx='#%02X%02X%02X'%color
  if hx not in palette and all(sum(abs(a-b) for a,b in zip(color,tuple(int(x[i:i+2],16) for i in (1,3,5))))>45 for x in palette): palette.append(hx)
  if len(palette)==8: break
 claims=[]
 mapping=[('trend-display',['趋势','随时间']),('group-comparison',['组间','分组','比较']),('dense-comparison',['多维','矩阵','密度']),('hierarchy-display',['层级','分类']),('proportion-display',['占比','组成']),('relationship-display',['关联','相关','关系']),('trajectory-display',['轨迹','进程']),('spatial-display',['地理','空间'])]
 for tag,keys in mapping:
  if any(k in text for k in keys):claims.append(tag)
 return {'sha256':sha(p),'width_px':rgb.width,'height_px':rgb.height,'aspect_ratio':round(rgb.width/rgb.height,4),
         'dominant_nonwhite':palette,'palette_roles':{'background':'#FFFFFF','structure':'#333333','candidate_accents':palette[:6]},
         'source_claim_tags':claims}

def build(source_root,metadata,curation):
 records=json.loads(Path(metadata).read_text()); decisions={d['path']:d for d in json.loads(Path(curation).read_text())['decisions']}
 cases=[]
 for r in records:
  parts=[]
  for item in r.get('code_files',[]):
   p=Path(source_root)/item['path'];parts.append((item['path'],p.read_text(errors='replace')))
  visuals=[];claims=set()
  for item in r.get('image_files',[]):
   d=decisions.get(item['path'],{});v=visual_profile(Path(source_root)/item['path'],d.get('ocr_excerpt',''));v['source_path']=item['path'];visuals.append(v);claims.update(v['source_claim_tags'])
  cases.append({'case_id':f"REPRO-{r['issue']:03d}",'issue':r['issue'],'title':r['title'],'source_url':r['article_url'],
   'chart_tags':chart_tags(r['title']),'advantage_tags':sorted(claims),'layout_tags':['original-over-reproduction','annotated-explanation'],
   'code_analysis':analyze_code_texts(parts),'visuals':visuals,'pairing_status':'article-level-candidate-unverified'})
 return {'schema_version':'1.0','policy':{'raw_code_embedded':False,'source_images_embedded':False,'execution_performed':False,'license_status':'not_verified'},'coverage':{'cases':len(cases),'visuals':sum(len(x['visuals']) for x in cases),'code_files':sum(x['code_analysis']['file_count'] for x in cases)},'cases':cases}

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-root',type=Path,required=True);p.add_argument('--metadata',type=Path,required=True);p.add_argument('--curation',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 result=build(a.source_root,a.metadata,a.curation);a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result['coverage'],ensure_ascii=False))
