from pathlib import Path
import numpy as np,pandas as pd,h5py,json,hashlib
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scvelo.plotting.velocity_embedding_grid import compute_velocity_on_grid
P=Path(__file__).resolve().parents[3];W=P/'work/2026-10-28-batch-six/cellrank';L=P/'biofigure/benchmark/library/single-cell/cellrank-fig6abd-20261028';O=L/'results/plot_data';O.mkdir(parents=True,exist_ok=True)
C=P/'work/2026-10-15-cellrank-reproduction/checkpoints/04_full_fates.h5ad'
decode=lambda x:np.array([v.decode()if isinstance(v,bytes)else str(v)for v in x])
with h5py.File(C)as f:
 ids=decode(f['obs/_index'][:]);X=f['obsm/X_umap'][:];V=f['obsm/velocity_umap'][:];prob=f['obsm/to_terminal_states'][:];membership=f['obsm/terminal_states_memberships'][:]
 ct=decode(f['obs/__categories/clusters'][:]);ts=decode(f['obs/__categories/terminal_states'][:]);ci=f['obs/clusters'][:];si=f['obs/terminal_states'][:]
 print('OBS',len(ids),ct,ts);print('Xrange',X.min(0),X.max(0))
 assert len(ids)==24882 and X.shape==V.shape==(24882,2) and prob.shape==(24882,9) and np.allclose(prob.sum(1),1)
 # Fate matrix column order is bound by nested AnnData lineage names.
 side=f['uns/biofigure_nested_anndata_sidecars']
 print('sidecar',list(side))
 def walk(name,o):
  if isinstance(o,h5py.Dataset) and any(x in name for x in ['names','colors','columns']):print(name,o[:])
 side.visititems(walk)
 meta=json.loads((P/'biofigure/benchmark/library/single-cell/cellrank-2022/data/derived/lung-fate-metadata.json').read_text());assert list(ts)==meta['lineage_names'];basal=meta['lineage_names'].index('Basal')
 df=pd.DataFrame(dict(cell_id=ids,UMAP1=X[:,0],UMAP2=X[:,1],velocity1=V[:,0],velocity2=V[:,1],cluster=ct[ci],state=np.where(si>=0,ts[np.maximum(si,0)],'Unassigned'),basal_probability=prob[:,basal]))
 df.to_csv(O/'cellrank_lung_cells.csv',index=False)
 pd.DataFrame(prob,index=ids,columns=ts).to_csv(O/'cellrank_lung_fate_probabilities.csv',index_label='cell_id')
 pd.DataFrame(membership,index=ids,columns=ts).to_csv(O/'cellrank_lung_macrostate_memberships.csv',index_label='cell_id')
Xg,Vg=compute_velocity_on_grid(X_emb=X,V_emb=V,density=1,smooth=None,min_mass=None,n_neighbors=None,autoscale=False,adjust_for_stream=True,cutoff_perc=None)
lengths=np.sqrt((Vg**2).sum(0));lw=2*lengths/lengths[~np.isnan(lengths)].max()
fig,ax=plt.subplots();sp=ax.streamplot(Xg[0],Xg[1],Vg[0],Vg[1],density=2,linewidth=lw,color='black',arrowsize=1,arrowstyle='-|>',maxlength=4,integration_direction='both')
segs=sp.lines.get_segments();points=[];arrows=[];paths=[];curr=[]
for seg in segs:
 if curr and not np.allclose(curr[-1],seg[0],rtol=0,atol=1e-10):paths.append(np.array(curr));curr=[]
 if not curr:curr.append(seg[0])
 curr.append(seg[1])
if curr:paths.append(np.array(curr))
for j,xy in enumerate(paths):
 for k,pt in enumerate(xy):points.append(dict(path_id=j,point_order=k,x=pt[0],y=pt[1]))
 if len(xy)>2:
  s=np.cumsum(np.hypot(np.diff(xy[:,0]),np.diff(xy[:,1])));n=np.searchsorted(s,s[-1]/2);n=min(n,len(xy)-2)
  arrows.append(dict(path_id=j,x=xy[n,0],y=xy[n,1],xend=xy[n:n+2,0].mean(),yend=xy[n:n+2,1].mean()))
pd.DataFrame(points).to_csv(O/'cellrank_velocity_streamlines.csv',index=False);pd.DataFrame(arrows).to_csv(O/'cellrank_velocity_arrows.csv',index=False);plt.close(fig)
bound=lambda p:dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest())
qc=dict(status='COMPUTED_NOT_RENDERED',checkpoint=bound(C),cells=len(df),clusters=df.cluster.value_counts().to_dict(),terminal_counts=df.state.value_counts().to_dict(),source_umap_range=[X.min(0).tolist(),X.max(0).tolist()],stream_paths=len(paths),stream_points=len(points),arrow_count=len(arrows),native_scvelo_grid_defaults=dict(density=1,smooth=None,min_mass=None,autoscale=False,adjust_for_stream=True),matplotlib_stream_defaults=dict(density=2,maxlength=4,integration_direction='both'),scope='Original-method seed-repaired reanalysis checkpoint, unchanged UMAP and velocity_umap. Python computes source stream geometry only; no final Python figure produced.')
(W/'input-qc.json').write_text(json.dumps(qc,indent=2)+'\n');print('EXPORTED',len(points),'points',len(paths),'paths')
