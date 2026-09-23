#!/usr/bin/env python3
"""Verifica que FOSO_DER_v0_4.mmd coincida con el esquema instalado.
Uso: 1) exportar columnas y claves con las consultas del encabezado a
cols_sql.txt y keys_sql.txt (ver PROCEDIMIENTO_BD.md, paso 4); 2) ejecutar
este script en el mismo directorio. Sale con codigo 1 si hay discrepancias."""
import re, sys, pathlib, collections
mmd = pathlib.Path("FOSO_DER_v0_4.mmd").read_text()
der = collections.OrderedDict(); der_pk = {}; der_fk = collections.defaultdict(list)
for m in re.finditer(r'^\s{4}(\w+) \{\n(.*?)^\s{4}\}', mmd, re.M|re.S):
    ent = m.group(1).lower(); der[ent]=[]
    for ln in m.group(2).splitlines():
        a = re.match(r'^\s{8}(\S+) (\S+)((?: PK| FK| UK|,FK)*)(?: ".*")?$', ln)
        if not a: continue
        der[ent].append((a.group(2), a.group(1)))
        if 'PK' in a.group(3): der_pk.setdefault(ent, []).append(a.group(2))
        if 'FK' in a.group(3): der_fk[ent].append(a.group(2))
sql = collections.defaultdict(list)
for ln in open('cols_sql.txt'):
    t,c,ty = ln.strip().split('|'); sql[t].append((c,ty))
keys = collections.defaultdict(lambda: collections.defaultdict(list))
for ln in open('keys_sql.txt'):
    t,k,cols = ln.strip().split('|'); keys[t][k].append(cols)
err=[]
if set(der)!=set(sql): err.append(f"Tablas: solo DER {set(der)-set(sql)}, solo SQL {set(sql)-set(der)}")
for t in der:
    if [c for c,_ in der[t]]!=[c for c,_ in sql.get(t,[])]:
        err.append(f"{t}: columnas/orden difieren")
    else:
        for (c,dty),(c2,sty) in zip(der[t],sql[t]):
            if dty!=sty: err.append(f"{t}.{c}: tipo DER={dty} SQL={sty}")
    pk = keys[t]['PRIMARY KEY'][0].split(',') if keys[t]['PRIMARY KEY'] else []
    if der_pk.get(t,[])!=pk: err.append(f"{t}: PK DER={der_pk.get(t)} SQL={pk}")
    fk=set()
    for g in keys[t]['FOREIGN KEY']: fk.update(g.split(','))
    if set(der_fk.get(t,[]))!=fk: err.append(f"{t}: FKs DER={sorted(der_fk.get(t,[]))} SQL={sorted(fk)}")
print(f"Entidades DER: {len(der)} | Tablas SQL: {len(sql)} | Atributos: {sum(len(v) for v in der.values())}/{sum(len(v) for v in sql.values())}")
if err:
    print("DISCREPANCIAS:"); [print(" -",e) for e in err]; sys.exit(1)
print("OK: DER y esquema coinciden en tablas, columnas (nombre/tipo/orden), PK y columnas FK.")
