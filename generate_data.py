import csv,json,pathlib
p=pathlib.Path(__file__).parent
rows=list(csv.reader((p/'cheats.tsv').open(encoding='utf-8'),delimiter='\t'))
assert all(len(r)==4 and r[1].isascii() and r[1].isalpha() and r[1].isupper() for r in rows)
assert len({r[1] for r in rows})==len(rows)
s='// Generated from cheats.tsv. UTF-8.\nstatic const Cheat cheats[] = {\n'
for r in rows:s+='    {'+', '.join('L'+json.dumps(x,ensure_ascii=False) for x in r)+'},\n'
s+='};\n'
(p/'src'/'cheats.h').write_text(s,encoding='utf-8')
print(len(rows),'validated cheats')
