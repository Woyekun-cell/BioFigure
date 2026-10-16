"""Public release integrity tests use portable, tiny synthetic filesystem fixtures."""
from __future__ import annotations
import hashlib,importlib.util,json,struct,sys,tempfile,unittest,zlib
from pathlib import Path

sys.dont_write_bytecode=True
SCRIPT=Path(__file__).resolve().parents[1]/'audit_public_release.py'
if SCRIPT.is_file():
    spec=importlib.util.spec_from_file_location('public_release',SCRIPT)
    AUDIT=importlib.util.module_from_spec(spec);spec.loader.exec_module(AUDIT)
else:AUDIT=None

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def png(colour=30,width=2,height=3):
    def chunk(kind,payload):return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',zlib.crc32(kind+payload)&0xffffffff)
    pixels=b''.join(b'\0'+bytes([colour,90,160])*width for _ in range(height))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b'')

class PublicReleaseTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
        self.put('biofigure/manifest.yaml','version: 4.12.3\n')
        self.put('biofigure/SKILL.md','# BioFigure 4.12.3\n')
        self.put('README.md','BioFigure-4.12.3\n')
        self.put('docs/HANDBOOK.zh-CN.md','# BioFigure 4.12.3 中文\n')
        self.put('docs/HANDBOOK.en.md','# BioFigure 4.12.3 Handbook\n')
        script='biofigure/examples/public/render.R';self.put(script,'print(1)\n')
        self.catalog={'schema_version':1,'categories':[{'slug':'heatmaps'},{'slug':'genomes'}],'figures':[]}
        artifacts=[]
        for i in range(3):
            image=f'docs/assets/gallery/{i}.png';pdf=f'docs/gallery/data/{i}.pdf';csv=f'docs/gallery/data/{i}.csv';provenance=f'docs/gallery/data/{i}.json'
            self.put(image,png(30+i));self.put(pdf,b'%PDF-1.7\nfixture\n');self.put(csv,'gene,value\nG1,1\n')
            self.put(provenance,json.dumps({'scope':'Selected author-data panel only; no full-corpus fidelity claim'}))
            self.catalog['figures'].append({'id':f'BF-{i}','image':image,'sha256':digest(self.root/image),'category':'heatmaps' if i<2 else 'genomes','subtype':f'type-{i}','scripts':[script]})
            paths=[image,pdf,csv,provenance,script]
            artifacts.append({'case_id':f'case-{i}','gallery_id':f'BF-{i}','image':image,'pdf':pdf,'scripts':[script],'plot_data':[csv],'provenance':provenance,'files':[{'path':p,'sha256':digest(self.root/p)} for p in paths]})
        archive='docs/gallery/archive/previous.png';self.put(archive,png(80))
        self.refresh={'schema_version':1,'scope':'selected-gallery-release','artifacts':artifacts,'new_figures':2,
            'replacements':[{'gallery_id':'BF-0','previous_sha256':digest(self.root/archive),'current_sha256':self.catalog['figures'][0]['sha256'],'archive_path':archive,'git_snapshot_tag':'gallery-before-refresh'}]}
        self.write_json('docs/gallery/catalog.json',self.catalog);self.write_json('docs/gallery/refresh-20261011.json',self.refresh)
        self.write_json('biofigure/benchmark/registry.json',{'schema_version':2,'cases':[{'case_id':f'case-{i}','bundles':{}} for i in range(3)]})
        self.write_json('biofigure/atlas/unified-capability-graph.json',{'nodes':[{'id':f'case-{i}','kind':'case'} for i in range(3)]})
    def put(self,path,value):
        p=self.root/path;p.parent.mkdir(parents=True,exist_ok=True)
        p.write_bytes(value if isinstance(value,bytes) else value.encode())
    def write_json(self,path,value):self.put(path,json.dumps(value))
    def run_audit(self):
        self.assertIsNotNone(AUDIT,'public auditor is not implemented')
        return AUDIT.audit_public_release(self.root)
    def assert_error(self,code):
        d=self.run_audit();self.assertEqual(d['status'],'FAIL');self.assertTrue(any(code in e for e in d['errors']),d['errors'])
    def rehash(self,path):
        for a in self.refresh['artifacts']:
            for f in a['files']:
                if f['path']==path:f['sha256']=digest(self.root/path)
        for row in self.catalog['figures']:
            if row['image']==path:row['sha256']=digest(self.root/path)
        self.write_json('docs/gallery/catalog.json',self.catalog);self.write_json('docs/gallery/refresh-20261011.json',self.refresh)
    def test_valid_dynamic_inventory_is_public_pass_not_scientific_pass(self):
        d=self.run_audit();self.assertEqual(d['status'],'PASS');self.assertEqual(d['gallery']['figure_count'],3)
        self.assertEqual(d['benchmark']['status'],'INCOMPLETE');self.assertFalse(d['whole_corpus_fidelity_certified'])
    def test_tampered_image_is_rejected(self):
        self.put(self.catalog['figures'][1]['image'],png(140));self.assert_error('gallery_hash_mismatch')
    def test_corrupt_header_even_when_file_hash_is_updated(self):
        path=self.catalog['figures'][1]['image'];raw=bytearray((self.root/path).read_bytes());raw[16]=1
        self.put(path,bytes(raw));self.rehash(path);self.assert_error('gallery_png_header')
    def test_missing_script_is_rejected(self):
        (self.root/self.catalog['figures'][0]['scripts'][0]).unlink();self.assert_error('gallery_script')
    def test_duplicate_category_subtype_is_rejected(self):
        self.catalog['figures'][1]['subtype']=self.catalog['figures'][0]['subtype'];self.write_json('docs/gallery/catalog.json',self.catalog);self.assert_error('gallery_duplicate_subtype')
    def test_same_subtype_in_different_category_is_allowed(self):
        self.catalog['figures'][2]['subtype']=self.catalog['figures'][0]['subtype'];self.write_json('docs/gallery/catalog.json',self.catalog)
        self.assertEqual(self.run_audit()['status'],'PASS')
    def test_stale_version_is_rejected(self):
        self.put('docs/HANDBOOK.en.md','# BioFigure 4.12.2\n');self.assert_error('version_mismatch')
    def test_readme_badge_colour_is_not_a_version_suffix(self):
        self.put('README.md','![Version](https://img.shields.io/badge/BioFigure-4.12.3-28527A)\n')
        self.assertEqual(self.run_audit()['status'],'PASS')
    def test_machine_specific_text_path_is_rejected(self):
        self.put('docs/leak.md','/'+ 'Users/'+'someone/private/data.csv');self.assert_error('absolute_path_leak')
    def test_work_and_cache_are_excluded_from_public_scanning(self):
        for directory in ['work','cache','.git']:
            self.put(directory+'/local.md','/'+ 'home/'+'someone/data.csv')
        self.assertEqual(self.run_audit()['status'],'PASS')
    def test_public_cache_and_platform_junk_are_rejected(self):
        self.put('tools/__pycache__/x.pyc',b'x');self.put('docs/.DS_Store',b'x');self.assert_error('public_file_hygiene')
    def test_registry_graph_id_mismatch_is_rejected(self):
        self.write_json('biofigure/atlas/unified-capability-graph.json',{'nodes':[{'id':'unrelated','kind':'case'}]});self.assert_error('registry_graph_case_ids')
    def test_refresh_all_references_must_be_hash_bound(self):
        self.refresh['artifacts'][1]['files']=self.refresh['artifacts'][1]['files'][:-1];self.write_json('docs/gallery/refresh-20261011.json',self.refresh);self.assert_error('refresh_unbound_reference')
    def test_empty_provenance_scope_is_rejected(self):
        path=self.refresh['artifacts'][1]['provenance'];self.put(path,'{"scope":""}');self.rehash(path);self.assert_error('refresh_provenance_scope')
    def test_empty_plot_data_is_rejected(self):
        path=self.refresh['artifacts'][1]['plot_data'][0];self.put(path,'gene,value\n');self.rehash(path);self.assert_error('refresh_plot_data_empty')
    def test_non_pdf_even_with_correct_hash_is_rejected(self):
        path=self.refresh['artifacts'][1]['pdf'];self.put(path,b'not a PDF');self.rehash(path);self.assert_error('refresh_pdf_header')
    def test_archive_hash_is_checked(self):
        self.put(self.refresh['replacements'][0]['archive_path'],png(55));self.assert_error('replacement_archive_hash')
    def test_replacement_current_hash_must_match_catalog(self):
        self.refresh['replacements'][0]['current_sha256']='0'*64;self.write_json('docs/gallery/refresh-20261011.json',self.refresh);self.assert_error('replacement_current_hash')
    def test_declared_new_figure_count_is_checked(self):
        self.refresh['new_figures']=7;self.write_json('docs/gallery/refresh-20261011.json',self.refresh);self.assert_error('refresh_new_figure_count')
    def test_path_escape_is_rejected(self):
        self.catalog['figures'][1]['image']='../external.png';self.write_json('docs/gallery/catalog.json',self.catalog);self.assert_error('gallery_image_path')
    def test_missing_refresh_is_rejected(self):
        (self.root/'docs/gallery/refresh-20261011.json').unlink();self.assert_error('refresh_manifest')
    def test_current_release_manifest_does_not_rewrite_historical_refresh(self):
        self.write_json('docs/gallery/current-release.json',{'schema_version':1,'current_refresh_manifest':'docs/gallery/refresh-current.json'})
        self.write_json('docs/gallery/refresh-current.json',self.refresh)
        (self.root/'docs/gallery/refresh-20261011.json').unlink()
        self.assertEqual(self.run_audit()['status'],'PASS')
    def test_current_release_marker_cannot_escape_repository(self):
        self.write_json('docs/gallery/current-release.json',{'schema_version':1,'current_refresh_manifest':'../outside.json'})
        self.assert_error('refresh_manifest')

if __name__=='__main__':unittest.main()
