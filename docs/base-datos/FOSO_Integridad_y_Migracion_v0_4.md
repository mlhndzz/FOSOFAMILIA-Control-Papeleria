# Integridad de movimientos, despachos y carga inicial — v0.4
**Proyecto:** Sistema de Control de Papelería y Útiles — FOSOFAMILIA · 22/09/2026
**Sustituye a la versión v0.3**: aquella describía las FKs compuestas sobre columnas `naturaleza` que fueron retiradas del esquema por la corrección de normalización (ver diagnóstico v0.4). Este documento describe los mecanismos vigentes en `01_schema.sql` v0.4. `[P]` = provisional.

---

## 1. Integridad compras ↔ movimientos

La naturaleza E/S reside **únicamente** en `tipo_movimiento` (3FN). La coherencia se garantiza así:

| Riesgo | Mecanismo v0.4 | Clase | Verificado |
|---|---|---|---|
| Compra asociada a un movimiento de salida | `trg_compra_solo_entrada`: al insertar/reasignar una compra, el tipo del movimiento debe ser de entrada | Técnica (trigger) | R1 rechazado / R2 aceptado |
| Requisición vinculada a una entrada | `trg_movimiento_valida_requisicion` | Técnica (flujo del JPG: la requisición desemboca en despacho/salida) | R4 rechazado |
| Cambio de naturaleza del tipo que invalidaría movimientos ya validados | `trg_tipomov_naturaleza_inmutable`: la naturaleza de un tipo **en uso** no cambia | Técnica — cierre del conjunto de triggers | R5 rechazado / R5b (tipo sin uso) permitido |
| Cambio de tipo/requisición de un movimiento con líneas o compra | `trg_movimiento_bloquea_cambios` (correcciones = movimientos de ajuste, no mutación de historia) | Técnica | R8, T9 rechazados |
| Doble fila de compra para el mismo movimiento | PK = FK (`id_movimiento`) | Técnica | T4b rechazado |
| Misma compra lógica dos veces | Parcial: `UNIQUE (id_proveedor, numero_factura)` (R3). **Límite honesto:** la definición completa depende del formato real de factura (GUIDs sin interpretar) y de si una factura puede ingresar por partes | Técnica parcial + [P] | R3 rechazado |

Trade-off declarado: v0.4 cambió garantía declarativa (FKs compuestas de v0.3, que violaban 3FN) por garantía procedimental (triggers). El conjunto {validación en el hijo + inmutabilidad del padre en uso + bloqueo de mutación} cubre las mismas vías de inconsistencia y está probado.

## 2. Integridad requisiciones ↔ despachos

Sin asumir ni prohibir despachos parciales (pregunta institucional abierta):

| Garantía | Mecanismo v0.4 | Clase | Verificado |
|---|---|---|---|
| Solo artículos de la requisición | `fn_valida_despacho` (a) | Técnica | R6, T6a-bis rechazados sin efecto residual |
| Cantidades ≤ autorizadas (autorizado = COALESCE(aprobada, solicitada) [P]) | `fn_valida_despacho` (b), acumulado por artículo | Técnica + [P] | R6-bis-a/c rechazados; R6-bis-b aceptado |
| Sin salidas duplicadas de la misma requisición | [P] **Despacho único provisional**: índice único parcial sobre `movimiento(id_requisicion)` | [P] | T7 rechazado |
| Stock nunca negativo | `trg_movdet_saldo` (delta neto en correcciones) + CHECK ≥ 0 | Técnica | T8, P2b rechazados; P2 correcto |
| **Lo ya entregado nunca excede lo autorizado, tampoco retroactivamente** | `trg_reqdet_protege_despachado`: rechaza reducir `cantidad_aprobada`/`cantidad_solicitada`, borrar líneas o cambiar el artículo de una línea cuando lo despachado del artículo excedería la autorización restante. Además, una requisición **con despachos no puede eliminarse** (FK de `movimiento.id_requisicion` sin acción de borrado) y una sin despachos sí (cascada de líneas) | Técnica (solo impide la incoherencia aritmética; no inventa flujo de aprobación) | **Q1–Q7** (sección 5) |
| Concurrencia | El UPDATE de `articulo` en el trigger serializa por bloqueo de fila; el CHECK decide sobre el valor final | Técnica (argumento por bloqueo; sin simulación de concurrencia real) | — |

Fuera a propósito: exigir estado «aprobado» para despachar — imposible sin la lista oficial de estados (matriz, decisión 4).

## 3. Carga inicial del inventario y conciliación

Principio: **la existencia inicial entra como movimiento**, nunca editando el saldo, para que `existencia = Σ movimientos` se cumpla desde el día cero.

1. **Catálogos mínimos reales**: específicos 54105/54114/54115 con sus nombres del Excel y los 61 artículos de INVENTARIO (cols. B/C), normalizando espacios de borde en códigos y documentando cada normalización. **No se cargan** proveedores (columna vacía), unidades de medida (sin datos), roles ni unidades organizativas (sin catálogo). La FK `articulo.id_unidad_medida` NOT NULL [P] **bloquea la carga de artículos hasta recibir ese catálogo** — bloqueo real a decidir, no a rellenar.
2. **Corte**: la hoja INVENTARIO está «AL 31 DE AGOSTO DE 2026» (J2).
3. **Movimiento de carga inicial**: un movimiento de tipo *ajuste de entrada — carga inicial* (código por confirmar) con una línea por artículo con existencia > 0: `cantidad` = col. **H**, `costo_unitario` = col. **I**; `costo_promedio_actual` se inicializa con la col. I.
4. **Histórico**: los comprobantes 0590–0602 de agosto ya están dentro del saldo H; **no se re-cargan** (duplicarían salidas). Si FOSOFAMILIA quisiera el histórico dentro del sistema, se cargaría **en lugar de** el saldo de corte partiendo de la col. E — decisión [P]; se recomienda la opción 3.

**Comprobación contra el libro:** `vw_existencias_calculadas.diferencia = 0` en todos los artículos; sumas por específico = 2,641 / 1,351 / 42 y total 4,034 (filas 25/67/71/72); valoración por línea ≈ 3,992.36 + 901.66 + 22.03 = 4,916.05 contra la col. K (el propio libro tiene una discrepancia interna de 3.29 entre J72 y K72 por redondeos; la referencia es K); códigos y descripciones = cols. B/C (diff automatizable).

## 4. Estado del SQL — declaración de alcance

| Categoría | Contenido |
|---|---|
| **Estructura creada** | 15 tablas, 1 vista, 1 función auxiliar, PKs, FKs, UNIQUEs, CHECKs, índices |
| **Restricciones implementadas** | Las de las secciones 1 y 2, incluida la protección de líneas despachadas |
| **Reglas pendientes** | Fórmula de costo; CHECK de estados; catálogo de tipos; alcance del correlativo; semántica de aprobación y parciales; obligatoriedad real de proveedor |
| **Procesos no desarrollados** | Recálculo de costo; flujo de aprobación; script de carga inicial (documentado arriba); reportes; aplicación C# |

**No es una base de datos operativa terminada**: es el cierre estructural de la fase de diseño con huecos declarados.

## 5. Verificación realizada (exacta)

- Verificación original: **PostgreSQL 16.13** local. Script ejecutado **dos veces sobre bases recién creadas** con `ON_ERROR_STOP`, sin errores.
- Verificación adicional: **PostgreSQL 18.6 sobre Windows**, 23/09/2026. `01_schema.sql` ejecutado desde cero y `03_pruebas.sql` ejecutado mediante `psql`, con **43/43 PASS**. Esta validación no sustituye la futura prueba del entorno final Ubuntu Server 24.04 LTS. La concurrencia de dos sesiones conserva como evidencia la ejecución original en 16.13.
- **Q1–Q7 (protección de líneas despachadas, nuevas en esta revisión)** — requisición con dos líneas del mismo artículo (aprobadas 12+8=20), despacho de 10:
  - Q1 reducir aprobada de línea 1 a 1 (autorizado 9 < 10) → **rechazado**;
  - Q2 reducir a 4 (autorizado 12 ≥ 10) → aceptado;
  - Q3 borrar la línea 2 (autorizado quedaría 4) → **rechazado**;
  - Q4 restaurar a 12 y borrar la línea 2 (queda 12 ≥ 10) → aceptado;
  - Q5 cambiar el artículo de la línea despachada → **rechazado**;
  - Q6 borrar la requisición con despacho → **rechazado por FK**;
  - Q7 borrar una requisición sin despachos → aceptado, líneas en cascada;
  - estado final: autorizado 12 ≥ despachado 10; conciliación en diferencia 0.
- **Regresión** en el mismo build: P2 (corrección 10→9 con saldo 2 → 1) y P3 (borrar encabezado de salida → saldo 9; borrar encabezado de entrada → saldo 0, sin huérfanos, diferencia 0) — correctos. Las suites completas previas (T1–T11, R1–R8, P2b, P3b/c, R6-bis) se ejecutaron sobre v0.4 en esta misma jornada; resultados tabulados en el diagnóstico v0.4.
- Datos de prueba claramente ficticios; no forman parte de ningún entregable. No se simuló concurrencia real.
