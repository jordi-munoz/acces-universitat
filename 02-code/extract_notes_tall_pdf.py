import pdfplumber, re, sys, csv
NUM=re.compile(r'^\d{1,2},\d{3}$'); CODE=re.compile(r'^\d{5}$')
rows=[]
pdf=pdfplumber.open(sys.argv[1])
for page in pdf.pages:
    lines={}
    for w in page.extract_words(): lines.setdefault(round(w['top']),[]).append(w)
    for top in sorted(lines):
        toks=sorted(lines[top], key=lambda w:w['x0'])
        code=next((t['text'] for t in toks if CODE.match(t['text']) and t['x0']<60), None)
        if not code: continue
        pau=[t['text'] for t in toks if NUM.match(t['text']) and 355<=t['x0']<=415]
        if pau: rows.append((code, pau[0].replace(',','.')))
pdf.close()
rows.sort(key=lambda r:r[0])
assert len(set(r[0] for r in rows))==len(rows), "duplicate codes!"
with open(sys.argv[2],'w',newline='',encoding='utf-8') as f:
    w=csv.writer(f); w.writerow(['codi','nota'])
    for r in rows: w.writerow(r)
print(f"wrote {len(rows)} studies")
