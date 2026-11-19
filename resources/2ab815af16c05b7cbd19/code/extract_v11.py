from pathlib import Path
import re,csv,json,hashlib
W=Path(__file__).resolve().parent;P=W.parents[2]
s=(W/'v11_kcdc_table_layout.txt').read_text()
alias={'Seoul':'Seoul','Busan':'Busan','Daegu':'Daegu','Incheon':'Incheon','Gwangju':'Gwangju','Daejeon':'Daejeon','Ulsan':'Ulsan','Sejong':'Sejong','Gyeonggi':'Gyeonggi-do','Gangwon':'Gangwon-do','Chungbuk':'Chungcheongbuk-do','Chungnam':'Chungcheongnam-do','Jeonbuk':'Jeollabuk-do','Jeonnam':'Jeollanam-do','Gyeongbuk':'Gyeongsangbuk-do','Gyeongnam':'Gyeongsangnam-do','Jeju':'Jeju'}
rows=[]
for line in s.splitlines():
 m=re.match(r'^\s*(\w+)\s+(\d+)\s+(\d+)\s+([\d,]+)\s+\(([\d.]+)\)',line)
 if m and m[1] in alias:
  rows.append({'source_region':m[1],'gadm_name':alias[m[1]],'cumulative_cases':int(m[4].replace(',','')),'as_of':'2020-09-30T00:00:00+09:00','unit':'confirmed cases','source_pdf_page':2})
assert len(rows)==17 and len({r['gadm_name'] for r in rows})==17
expected={'Seoul':5293,'Busan':421,'Daegu':7132,'Incheon':916,'Gwangju':495,'Daejeon':360,'Ulsan':147,'Sejong':76,'Gyeonggi':4384,'Gangwon':224,'Chungbuk':171,'Chungnam':484,'Jeonbuk':128,'Jeonnam':169,'Gyeongbuk':1551,'Gyeongnam':291,'Jeju':59}
assert {r['source_region']:r['cumulative_cases'] for r in rows}==expected
assert sum(r['cumulative_cases']for r in rows)==23812-1511==22301
for p in [W/'v11_kcdc_province_cases.csv',P/'results/plot_data/asf11_kcdc_province_cases_20261029.csv']:
 with p.open('w')as f:w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
q={'status':'PASS','rows':17,'unique_province_keys':17,'regional_cases':22301,'border_screening_excluded':1511,'national_total':23812,'closure':True,'all_17_match_original_Fig1B_labels':True,'value_source':'Text-table extraction of KCDC press release page2; no pixel-to-value reconstruction.','source_pdf_sha256':hashlib.sha256((W/'v11_KCDC_Press_Release_September30.pdf').read_bytes()).hexdigest(),'source_url':'https://kdischool.ac.kr/boardDownload.es?mid=a10602000000&bid=0041&list_no=7556&seq=31307','statistical_unit':'province-level reporting unit; not experimental replicates','as_of':'2020-09-30T00:00:00+09:00'}
(W/'numerical-audit.json').write_text(json.dumps(q,ensure_ascii=False,indent=2)+'\n');print(q)
