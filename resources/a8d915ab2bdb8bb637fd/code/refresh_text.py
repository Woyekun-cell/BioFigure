from pathlib import Path
import json,yaml
w=Path(__file__).resolve().parent;p=w/'design-spec.yaml';s=yaml.safe_load(p.read_text());s['text_contract']['allowed_text']=json.loads((w/'text-manifest.json').read_text())['labels'];p.write_text(yaml.safe_dump(s,sort_keys=False,allow_unicode=True))
