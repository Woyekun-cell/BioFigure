#!/usr/bin/env python3
"""Execute preserved original SCGV1.2.6 models/views and freeze exact plotting layers.
No refitting: the input directory must contain completed original SCclust tables.
"""
from pathlib import Path
import sys,json,hashlib,argparse
sys.dont_write_bytecode=True
p=argparse.ArgumentParser();p.add_argument('--case',required=True,type=Path);p.add_argument('--analysis',required=True,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args();C=a.case.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(C/'sources/author/SCGV'))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.colors import to_hex
import numpy as np,pandas as pd,scipy
from scgv.models.model import DataModel
from scgv.views.heatmap import HeatmapViewer
from scgv.views.dendrogram import DendrogramViewer
from scgv.views.clone import CloneViewer
fontfile='/System/Library/Fonts/Supplemental/Arial.ttf';font_manager.fontManager.addfont(fontfile)
plt.rcParams.update({'font.family':'Arial','font.size':7,'pdf.fonttype':42,'ps.fonttype':42,'axes.linewidth':.4,'xtick.major.width':.4,'ytick.major.width':.4})
m=DataModel(str(a.analysis.resolve()));m.make();assert m.samples==185 and m.bins==5000
assert m.data.tree_df is not None,'Never fall back to SCGV ward linkage'
assert sorted(m.ordering.tolist())==list(range(185))
fig=plt.figure(figsize=(180/25.4,135/25.4),dpi=300)
# Same native tree/clone/matrix geometry, publication-sized; no Qt is used.
axd=fig.add_axes([16/180,99/135,134/180,25/135]);DendrogramViewer(m).draw_dendrogram(axd)
axc=fig.add_axes([16/180,96/135,134/180,2/135],sharex=axd);cv=CloneViewer(m);cv.draw_clone(axc)
axh=fig.add_axes([16/180,9/135,134/180,86/135],sharex=axd);hv=HeatmapViewer(m);hv.draw_heatmap(axh)
# Correct the package's human-default labels to the supplied mm9 numeric20=X,21=Y.
chroms=m.data.seg_df.chrom.to_numpy();bounds=np.r_[0,np.flatnonzero(chroms[1:]!=chroms[:-1])+1,len(chroms)];centres=(bounds[:-1]+bounds[1:])/2;labels=[str(i)if i<20 else('X'if i==20 else'Y')for i in chroms[bounds[:-1]]]
axh.set_yticks(centres);axh.set_yticklabels(labels,fontsize=7);axh.set_ylabel('Chromosome',fontsize=8)
for ax in [axd,axc,axh]:ax.tick_params(axis='x',bottom=False,labelbottom=False);ax.tick_params(axis='y',labelsize=7,length=2)
axd.set_ylabel('Distance',fontsize=8);axd.set_title('PDAC (T2)',fontsize=8,pad=5)
# Native05 categorical normalization is0..4, with saturated extremes.
cax=fig.add_axes([158/180,55/135,3/180,40/135]);cb=fig.colorbar(axh.images[0],cax=cax,ticks=[0,1,2,3,4]);cb.ax.tick_params(labelsize=7,length=2);cb.ax.set_yticklabels(['0','1','2','3','4+']);cax.set_title('Copy\nnumber',fontsize=7,pad=5)
fig.canvas.draw();fig.savefig(out/'scgv-native.png',dpi=300,metadata={'Software':'SCGV1.2.6 original models/views, adapted device geometry'});fig.savefig(out/'scgv-native.pdf',metadata={'CreationDate':None,'ModDate':None})
# Preserve every numeric rounded CN and every original ID in original native leaf order.
cn=pd.DataFrame(m.heatmap,columns=m.column_labels);cn.insert(0,'bin_index',np.arange(5000));cn.insert(1,'chrom',chroms);cn.to_csv(out/'rounded-cn.csv',index=False,float_format='%.0f')
lin=pd.read_csv(C/'data/metadata/KPCLOH.Tumor2.DP.SP.ENA.cell-lineage.tsv',sep='\t').set_index('cell_id');order=pd.DataFrame({'cell_id':m.column_labels,'original_column':m.ordering,'cell_x':np.arange(185)+.5,'clone_value':m.clone,'subclone_value':m.subclone});order['clone_color']=[to_hex(cv.cmap(v/cv.vmax))for v in m.clone];order['lineage']=[lin.loc[k,'lineage']if k in lin.index and pd.notna(lin.loc[k,'lineage'])else'Unknown'for k in order.cell_id];order.to_csv(out/'cell-order.csv',index=False)
# Capture actual native DendrogramViewer artist paths after its leaf-hang adjustment.
links=[]
for k,line in enumerate(axd.lines):
 for j in range(len(line.get_xdata())-1):links.append(dict(link=k,segment=j,x=float(line.get_xdata()[j])/10,xend=float(line.get_xdata()[j+1])/10,y=float(line.get_ydata()[j]),yend=float(line.get_ydata()[j+1])))
pd.DataFrame(links).to_csv(out/'tree-segments.csv',index=False);pd.DataFrame({'chromosome':labels,'start':bounds[:-1],'end':bounds[1:],'centre':centres}).to_csv(out/'chromosome-bins.csv',index=False)
colors=[to_hex(hv.cmap.colors(v/4))for v in range(5)];json.dump({'cn_colors':colors,'clone_colors':list(dict.fromkeys(order.clone_color))},open(out/'source-colors.json','w'),indent=2)
texts=[]
for ax in fig.axes:
 for t in ax.findobj(matplotlib.text.Text):
  if t.get_text() and t.get_visible():texts.append({'text':t.get_text(),'font_pt':t.get_fontsize(),'font_family':t.get_fontfamily(),'bbox_px':list(t.get_window_extent().bounds)})
rep=dict(scope='Source native SCGV models/views executed; author average-linkage SCclust tree independently recomputed; not a numeric identity claim to paper NJ tree.',cells=185,bins=5000,tree_links=len(axd.lines),tree_segments=len(links),rounded=np.array_equal(m.heatmap,np.round(m.seg_data)[:,m.ordering]),lineage=order.lineage.value_counts().to_dict(),cn_clip_min=0,cn_clip_max=4,tree_height_max=float(max(max(q)for q in m.Z['dcoord'])),matplotlib=matplotlib.__version__,numpy=np.__version__,pandas=pd.__version__,scipy=scipy.__version__,font_file=fontfile,texts=texts)
json.dump(rep,open(out/'native-mapping-QC.json','w'),indent=2)
print(json.dumps({k:v for k,v in rep.items()if k!='texts'},indent=2));plt.close(fig)
