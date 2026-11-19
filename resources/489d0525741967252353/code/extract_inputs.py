"""Extract unchanged source sheets; requires openpyxl. Does not fetch new data."""
from pathlib import Path
import csv, openpyxl
S=Path(__file__).resolve().parent/'sources'
for filename,sheets in {
 'reverse-SourceDataFig2.xlsx':{'Fig. 2c and d':'reverse-Fig_2c_and_d.csv','Metadata Fig. 2a-2d':'reverse-final-metadata.csv'},
 '42255_2020_278_MOESM2_ESM.xlsx':{'Supp. Table 8':'lipid-Supp._Table_8.csv','Supp. Table 9':'lipid-Supp._Table_9.csv'}
}.items():
 book=openpyxl.load_workbook(S/filename,read_only=True,data_only=True)
 for sheet,target in sheets.items():
  with (S/target).open('w',newline='')as stream:csv.writer(stream).writerows(book[sheet].values)
 book.close()
