# ENTREGABLE E — Justificación de normalización hasta 4FN (v0.4)
**Proyecto:** Sistema de Control de Papelería y Útiles — FOSOFAMILIA · 22/09/2026
**Sustituye a la versión v0.2** y describe el **esquema realmente implementado en `01_schema.sql` v0.4**.

**Método.** Para cada relación: claves candidatas, dependencias funcionales (DF), verificación 1FN→2FN→3FN→BCNF y examen de dependencias multivaluadas (DMV) para 4FN. Requisito institucional: mínimo 3FN; meta adicional: 4FN.

**Antecedente relevante (honestidad del historial).** La versión v0.3 del esquema añadió `naturaleza` como columna en `movimiento` y `compra` para lograr coherencia declarativa mediante FKs compuestas. Una auditoría señaló correctamente que eso **violaba 3FN**: en `movimiento`, `naturaleza` (atributo no primo) dependía funcionalmente de `id_tipo_movimiento`, que no es superclave de `movimiento`; y en `compra` era además una constante. Las restricciones de integridad no sustituyen el análisis de DF. **v0.4 eliminó ambas columnas**: la naturaleza vive únicamente en `tipo_movimiento` y la coherencia se garantiza con validaciones transaccionales (triggers), que son procedimiento, no estructura, y por tanto no afectan el análisis de formas normales. El esquema v0.4 **no contiene desnormalizaciones**; las dos materializaciones controladas de `articulo` (saldo y costo vigente) dependen solo de su clave y se analizan en 2.4.

**Distinción previa.** Las hojas del Excel no son un esquema relacional: son reportes de un sistema anterior. Sus defectos motivan el diseño pero no constituyen la prueba formal.

---

## 1. Del Excel al modelo: problemas que se corrigen

| Problema observado (evidencia) | Naturaleza del problema | Solución en el modelo |
|---|---|---|
| Encabezados de grupo intercalados con datos: filas «LINEA: 54105…» (INVENTARIO 5/26/68) | En una tabla única violaría 1FN (orden significativo, valores por posición) | Catálogo `especifico` + FK |
| Costo de cada salida obtenido por VLOOKUP del promedio *vigente*: el historial cambia retroactivamente | Dependencia de un dato externo mutable | `movimiento_detalle.costo_unitario` congelado |
| Mismo artículo repetido en un documento (hoja «DATOS DIGITADOS (3)», 2019) | Colisión con una PK (doc, artículo) | PK del detalle = (doc, `numero_linea`) |
| Saldos y totales guardados y rotos (`#REF!` en INVENTARIO F84:F88) | Redundancia derivada inconsistente | Derivados por vista; conciliación `vw_existencias_calculadas` |
| Descripción del artículo copiada en todas las hojas | Redundancia (violaría 2FN/3FN en tabla única) | Descripción solo en `articulo` |

## 2. Análisis por relación

Notación: A → B = «A determina funcionalmente B».

### 2.1 Catálogos: `rol`, `permiso`, `unidad_organizativa`, `especifico`, `unidad_medida`, `proveedor`, `tipo_movimiento`
- **Claves candidatas:** id sintético + identificador natural UNIQUE (`unidad_medida` tiene dos naturales: abreviatura y nombre).
- **DF:** cada clave → todos los atributos. En `tipo_movimiento`: id → (codigo, nombre, naturaleza) y codigo → ídem. `naturaleza` reside **solo aquí** (v0.4): es un atributo del tipo, determinado por su clave — sin transitividad.
- **1FN** atómicos ✔ · **2FN** trivial (claves simples) ✔ · **3FN** ningún no-clave determina a otro ✔ · **BCNF** todo determinante es clave candidata ✔.

### 2.2 `rol_permiso`(id_rol, id_permiso)
- Relación all-key; única clave candidata: el par. Sin DF no triviales → **BCNF** ✔.
- **4FN:** en una relación all-key binaria toda DMV es trivial (abarca todos los atributos) → cumple 4FN. El riesgo teórico aparecería solo al añadir un tercer atributo independiente (p. ej. `modulo` independiente de la acción): rol ↠ permiso | rol ↠ modulo sería DMV no trivial y exigiría descomponer. No hay evidencia de tal atributo. ✔

### 2.3 `usuario`
- **Claves candidatas:** id_usuario; nombre_usuario; correo (unicidad parcial cuando no es nulo).
- **DF:** cada clave → resto de atributos. `id_rol` es FK: el *nombre* del rol no está aquí (estaría en violación de 3FN si se copiara).
- **2FN/3FN/BCNF** ✔. **4FN:** un rol y una unidad por usuario (cardinalidad provisional pero definida); sin hechos multivaluados independientes. Si se confirmara multi-rol, saldría a `usuario_rol` (caso 2.2). ✔

### 2.4 `articulo`
- **Claves candidatas:** id_articulo; codigo. **DF:** codigo → (descripcion, id_especifico, id_unidad_medida, existencia_actual, costo_promedio_actual, activo).
- **3FN:** ¿descripcion → id_especifico? No: la línea es asignación administrativa («CAJA TROQUELADA» está en 54105 y «CAJA DE FASTENER» en 54114 — INVENTARIO filas 24 y 44); no hay DF transitiva. **BCNF** ✔.
- `existencia_actual` y `costo_promedio_actual` dependen **solo de la clave** en cada instante — no violan 3FN/BCNF. Son *derivables del historial* y se mantienen materializadas por exigencia transaccional (monitoreo de stock del JPG; costo vigente para valorar salidas, como el VLOOKUP del Excel), con trigger transaccional + conciliación por vista. Es redundancia **derivada y controlada**, declarada conforme a la regla 7 del proyecto; no es una violación de forma normal, y se documenta para no confundirla con una.
- **4FN:** cada código vive bajo exactamente una línea en todas las hojas con datos; sin unidades múltiples simultáneas. Sin DMV no triviales. ✔

### 2.5 `movimiento` (v0.4: sin columna naturaleza)
- **Claves candidatas:** id_movimiento; (id_tipo_movimiento, numero_comprobante) [P alcance del correlativo].
- **DF:** cada clave → (fecha, id_usuario_registra, id_requisicion, observacion, fecha_registro). La naturaleza del movimiento **no es un atributo de esta relación**: se obtiene navegando la FK al tipo (`fn_naturaleza_movimiento`). ¿id_requisicion → id_movimiento? Solo si el despacho fuera único — eso es hoy una **restricción provisional** (índice único parcial [P]), no una DF de negocio confirmada; el análisis no depende de ella y, si se confirma, id_requisicion pasaría a clave candidata *alternativa parcial* sin afectar la normalización.
- **3FN/BCNF** ✔ (determinantes = claves candidatas). **4FN:** atributos monovaluados; líneas en el detalle. ✔

### 2.6 `movimiento_detalle`
- **Clave candidata:** (id_movimiento, numero_linea) — no (id_movimiento, id_articulo): el histórico 2019 demuestra artículo repetido por documento.
- **2FN real:** ¿numero_linea → id_articulo? No. ¿id_movimiento → cantidad? No. ✔
- **3FN:** ¿id_articulo → costo_unitario? **No** — el costo es el histórico del momento (la nota del Excel, RESUMEN 44–47, confirma que el promedio cambia por mes). `costo_total` no se almacena porque (cantidad, costo_unitario) → costo_total tendría determinante no clave. **BCNF** ✔.
- **4FN:** cantidad y costo describen conjuntamente el mismo hecho-línea; no hay dos hechos multivaluados independientes. ✔

### 2.7 `compra` (v0.4: sin columna naturaleza)
- **Claves candidatas:** id_movimiento (subtipo 1:1, PK=FK); (id_proveedor, numero_factura) si se confirma que una factura no se registra dos veces [P].
- **DF:** id_movimiento → (id_proveedor, numero_factura). ¿numero_factura → id_proveedor? Sin evidencia (GUIDs); por eso la unicidad es compuesta. **3FN/BCNF** ✔.
- La regla «compra solo sobre entradas» es una **restricción de integridad entre relaciones** (trigger `fn_compra_solo_entrada` + inmutabilidad de la naturaleza del tipo en uso): no introduce atributos ni DF nuevas.
- **4FN:** dos atributos monovaluados. ✔

### 2.8 `requisicion` / 2.9 `requisicion_detalle`
- `requisicion`: claves id_requisicion y numero; sin DF entre no-clave (¿estado → fecha_revision? no). **BCNF** ✔; monovaluados → **4FN** ✔.
- `requisicion_detalle`: clave (id_requisicion, numero_linea); 2FN verificada igual que 2.6; ¿id_articulo → cantidad_solicitada? No (PABONDTC pedido en 8 comprobantes con cantidades 1–10). **BCNF** ✔; cantidades solicitada/aprobada describen la misma línea → **4FN** ✔.

## 3. Conclusión

1. Todas las relaciones del esquema v0.4 están en **BCNF** (demostrado arriba con las DF concretas). La violación de 3FN que la auditoría identificó en v0.3 (`movimiento.naturaleza`, `compra.naturaleza`) fue **eliminada del esquema**, no excusada.
2. **No existe ninguna DMV no trivial**: las relaciones donde estructuralmente podría haberlas (`rol_permiso` all-key; detalles con varios atributos por línea) se examinaron y sus atributos son mutuamente dependientes del hecho registrado. Una relación en BCNF sin DMV no triviales satisface 4FN por definición.
3. Por tanto, **el esquema v0.4 cumple 4FN**, sin excepciones de desnormalización. La integridad inter-relacional (compra=entrada, requisición=salida, saldo≥0, despacho⊆requisición) se garantiza por triggers y restricciones, lo cual es ortogonal al análisis de formas normales y está probado empíricamente (ver documento de diagnóstico y pruebas v0.4).
4. Cambios de cardinalidad pendientes (multi-rol, permisos por módulo×acción, despachos parciales) tienen indicado su impacto exacto en 2.2, 2.3 y 2.5.

**Límites honestos:** el análisis usa las DF observables en Excel, JPG y correo; los audios siguen sin transcribir. Los saldos materializados de `articulo` son redundancia derivada controlada (no violación), con su mecanismo de conciliación; si FOSOFAMILIA prefiriera todo derivado, basta eliminar dos columnas sin tocar el resto.

**Nota sobre las vistas (añadido en la consolidación de BD):** las 5 vistas del esquema (`vw_existencias_calculadas` y las 4 de reportes) son consultas derivadas sin almacenamiento propio: no constituyen relaciones base y no participan del análisis de formas normales; su denormalización aparente (joins aplanados) es la presentación del reporte, no el diseño de las tablas.
