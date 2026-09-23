#!/usr/bin/env python3
"""Deriva del DER canonico v0.3: (a) DER general compacto (sin comentarios de
atributo) y (b) diagramas por area funcional, sin reescribir el modelo a mano,
para garantizar consistencia entre diagramas."""
import re, pathlib

SRC = pathlib.Path("/home/claude/foso/entregables/FOSO_DER_v0_4.mmd")
OUT = pathlib.Path("/home/claude/foso/entregables/areas")
OUT.mkdir(exist_ok=True)
text = SRC.read_text()

# --- parse entity blocks ---
blocks = {}
for m in re.finditer(r'^\s{4}(\w+) \{\n(.*?)^\s{4}\}', text, re.M | re.S):
    blocks[m.group(1)] = m.group(0)

# --- parse relationships ---
rels = []
for line in text.splitlines():
    m = re.match(r'\s{4}(\w+) ([|}o{-]+) (\w+) : (".*")', line)
    if m:
        rels.append((m.group(1), m.group(2), m.group(3), m.group(4), line))

def strip_comments(block):
    out = []
    for ln in block.splitlines():
        m = re.match(r'^(\s{8}\S+ \S+(?: (?:PK|FK|UK|PK,FK)(?:,FK)?)?)( ".*")?$', ln)
        if m:
            attr = m.group(1)
            com = m.group(2) or ""
            keep = ' "[P]"' if "[P" in com else ""
            out.append(attr + keep)
        else:
            out.append(ln)
    return "\n".join(out)

def stub(name):
    pk = re.search(r'^\s{8}(\S+ \S+ PK)(?!,)', blocks[name], re.M)
    return f'    {name} {{\n        {pk.group(1)} "ver area correspondiente"\n    }}'

HEAD = '---\ntitle: "{t}"\nconfig:\n  theme: neutral\n---\nerDiagram\n'

# (a) DER general compacto
gen = [HEAD.format(t="FOSOFAMILIA - DER v0.4 - Vista general (atributos comentados en las vistas por area)")]
gen += [r[4] for r in rels]
gen += [strip_comments(blocks[n]) for n in blocks]
pathlib.Path(OUT/"general_compacto.mmd").write_text("\n".join(gen) + "\n")

# (b) areas: (titulo, entidades nucleo con atributos completos)
AREAS = {
 "area1_seguridad": ("Area 1 - Seguridad y organizacion",
    {"ROL","PERMISO","ROL_PERMISO","USUARIO","UNIDAD_ORGANIZATIVA"}),
 "area2_catalogos": ("Area 2 - Catalogos y articulos",
    {"ESPECIFICO","UNIDAD_MEDIDA","ARTICULO"}),
 "area3_requisiciones": ("Area 3 - Requisiciones",
    {"REQUISICION","REQUISICION_DETALLE","UNIDAD_ORGANIZATIVA","USUARIO","ARTICULO"}),
 "area4_movimientos": ("Area 4 - Movimientos de inventario y compras",
    {"TIPO_MOVIMIENTO","MOVIMIENTO","MOVIMIENTO_DETALLE","COMPRA","PROVEEDOR","ARTICULO","REQUISICION","USUARIO"}),
}
# entidades que en cada area se muestran solo como referencia (stub con PK)
STUBS = {
 "area3_requisiciones": {"USUARIO","ARTICULO"},
 "area4_movimientos": {"ARTICULO","REQUISICION","USUARIO"},
}
for fname,(title,ents) in AREAS.items():
    stubs = STUBS.get(fname,set())
    lines=[HEAD.format(t=f"FOSOFAMILIA - DER v0.4 - {title}")]
    for a,card,b,lbl,raw in rels:
        if a in ents and b in ents:
            lines.append(raw)
    for n in blocks:
        if n in ents:
            lines.append(stub(n) if n in stubs else blocks[n])
    pathlib.Path(OUT/f"{fname}.mmd").write_text("\n".join(lines)+"\n")
print("entidades:",len(blocks),"relaciones:",len(rels))
for f in sorted(OUT.iterdir()): print(f.name)
