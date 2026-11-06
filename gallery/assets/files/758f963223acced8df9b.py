import zipfile,xml.etree.ElementTree as E,posixpath
N={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
def sheets(p,names=None):
 z=zipfile.ZipFile(p);strings=[]
 if 'xl/sharedStrings.xml' in z.namelist():
  strings=[''.join(x.itertext()) for x in E.fromstring(z.read('xl/sharedStrings.xml'))]
 rel={x.attrib['Id']:x.attrib['Target'] for x in E.fromstring(z.read('xl/_rels/workbook.xml.rels'))}
 out={}
 for sh in E.fromstring(z.read('xl/workbook.xml')).find('s:sheets',N):
  name=sh.attrib['name']
  if names and name not in names:continue
  target=rel[sh.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']]
  path=target.lstrip('/') if target.startswith('/') else posixpath.normpath('xl/'+target)
  rows=[]
  for row in E.fromstring(z.read(path)).find('s:sheetData',N):
   vals={}
   for c in row:
    v=c.find('s:v',N);raw=v.text if v is not None else ''
    if c.attrib.get('t')=='s':val=strings[int(raw)] if raw else ''
    elif c.attrib.get('t')=='inlineStr':val=''.join(c.find('s:is',N).itertext())
    elif raw:
     try:val=float(raw)
     except:val=raw
    else:val=''
    vals[c.attrib.get('r')]=val
   rows.append(vals)
  out[name]=rows
 return out
if __name__=='__main__':
 import pathlib
 b=pathlib.Path('workspace/Project_001_生物科研绘图Skill/biofigure/benchmark/library')
 for p,n in [(b/'spatial/liana-plus-2024/sources/MOESM8.xlsx',['Fig5C','Fig5D','Fig5L']), (b/'single-cell/nichenet-2020/sources/MOESM13.xlsx',None)]:
  for name,rows in sheets(p,n).items():
   print(name,'rows',len(rows),'cols',max(map(len,rows)))
   print(rows[:3])
