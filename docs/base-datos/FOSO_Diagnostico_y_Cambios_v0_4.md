# Diagnóstico de la auditoría y registro de cambios v0.3 → v0.4
**Proyecto:** FOSOFAMILIA — Control de Papelería y Útiles · 22/09/2026
Corrección focalizada; el modelo de 15 tablas y todas las cardinalidades se conservan.

---

## PROBLEMA 1 — Redundancia de `naturaleza` (normalización)

**Diagnóstico (la auditoría tenía razón).** En v0.3, `movimiento.naturaleza` era un atributo no primo funcionalmente dependiente de `id_tipo_movimiento` (que no es superclave de `movimiento`): violación de 3FN. `compra.naturaleza` era además una constante ('E'). Se habían introducido deliberadamente para lograr coherencia declarativa con FKs compuestas, y el documento de v0.3 lo describía como "copia controlada", pero afirmar a la vez 4FN del esquema completo era incorrecto: una restricción de integridad no convierte en normal una dependencia que no lo es.

**Solución adoptada (alternativa normalizada, no excepción documentada).**
- Se **eliminaron** ambas columnas: la naturaleza reside únicamente en `tipo_movimiento` (su relación de origen según la DF `id_tipo_movimiento → naturaleza`).
- La coherencia pasó a validaciones transaccionales:
  - `trg_compra_solo_entrada`: una compra solo puede extender un movimiento cuyo tipo sea de entrada.
  - `trg_movimiento_valida_requisicion`: una requisición solo puede vincularse a movimientos de salida.
  - `trg_tipomov_naturaleza_inmutable`: la naturaleza de un tipo **en uso** no puede cambiar — cierra el hueco que la FK compuesta cubría (sin esto, cambiar la naturaleza del tipo invalidaría movimientos ya validados).
  - `trg_movimiento_bloquea_cambios` ampliado: un movimiento con líneas **o con compra asociada** no cambia de tipo ni de requisición.
- Trade-off declarado: se cambió garantía declarativa por garantía procedimental; el cierre del conjunto (validación en el hijo + inmutabilidad del padre en uso + bloqueo de mutación) cubre las mismas vías de inconsistencia, y así quedó probado (pruebas R1–R8).
- Consecuencia en documentación: el documento de normalización se reescribió como **v0.4** describiendo el esquema real; ya no hay excepción de desnormalización que documentar, y la afirmación de 4FN vuelve a ser válida sobre el esquema efectivo.

## PROBLEMA 2 — Trigger de saldo rechazaba correcciones válidas

**Diagnóstico (confirmado reproduciéndolo).** La versión v0.3 de `fn_movdet_actualiza_saldo`, en UPDATE, revertía el efecto anterior en una sentencia y aplicaba el nuevo en otra. Con entrada 10, salida 8 (saldo 2), corregir la entrada a 9 ejecutaba primero 2−10=−8 → el CHECK `existencia_actual >= 0` (que se evalúa por sentencia) abortaba una corrección cuyo resultado final (1) era válido.

**Solución.** Cuando la línea corregida mantiene el mismo artículo, se aplica **una sola actualización con el delta neto** (`efecto_nuevo − efecto_anterior`, con la naturaleza leída vía el tipo): 2 + (9−10) = 1 en un paso, sin estado intermedio. Si el UPDATE cambia el artículo de la línea, sí se revierte en el artículo anterior y se aplica en el nuevo — son filas distintas y cada una debe quedar ≥ 0 por sí misma (si revertir deja negativo al artículo viejo, la corrección es genuinamente inválida: ese stock ya se consumió).

**Pruebas ejecutadas (PostgreSQL 16.13):**
- P2: entrada 10 → salida 8 → saldo 2 → `UPDATE` de la entrada a 9 → **saldo final 1**. ✔
- P2b: corrección a 7 (dejaría −1) → **rechazada** por el CHECK y saldo intacto en 1. ✔

## PROBLEMA 3 — Borrado en cascada dejaba al trigger sin el padre

**Diagnóstico (confirmado por diseño y verificado).** Con `ON DELETE CASCADE`, PostgreSQL borra primero la fila de `movimiento` y después sus detalles; el trigger AFTER DELETE de `movimiento_detalle` consultaba entonces un padre ya inexistente (naturaleza NULL → actualización inválida del saldo).

**Solución.** Se retiró la cascada de la FK `movimiento_detalle → movimiento` y se creó `trg_movimiento_borra_hijos` (BEFORE DELETE en `movimiento`): borra la fila de `compra` y las líneas **mientras el encabezado sigue visible**, de modo que el trigger de saldo lee la naturaleza normalmente y revierte el efecto de cada línea. `requisicion_detalle` conserva su cascada (ningún trigger consulta a su padre).

**Pruebas ejecutadas (PostgreSQL 16.13), distinguiendo los dos casos que pediste:**
- P3 (borrar **encabezado** con detalles): entrada de 30+20 → saldo 50 → `DELETE FROM movimiento` → **saldo 0, cero detalles huérfanos, conciliación diferencia 0**. ✔
- P3b (borrar **una línea** directamente): entrada 30+20 → borrar la línea de 20 → **saldo 30**. ✔
- P3c (caso de guarda): borrar el encabezado de una entrada cuyo stock ya se consumió parcialmente → **rechazado** (dejaría saldo negativo) y saldo intacto; conciliación en 0. ✔

## Otros resultados de la regresión v0.4 (todos ejecutados)

| Prueba | Resultado |
|---|---|
| R1 compra sobre salida | Rechazada (trigger) |
| R2 compra sobre entrada | Aceptada |
| R3 misma factura de un proveedor repetida | Rechazada (UNIQUE) |
| R4 requisición vinculada a entrada | Rechazada (trigger) |
| R5 cambiar naturaleza de tipo en uso / R5b tipo sin uso | Rechazada / permitida |
| R6 despacho de artículo no solicitado | Rechazada |
| R6-bis exceso sobre lo autorizado **con stock suficiente** (4 > 3) | Rechazada por la validación de despacho |
| R6-bis-b despacho válido dentro de lo autorizado | Aceptada, saldo correcto |
| R6-bis-c acumulado 2+2 > 3 autorizadas | Rechazada |
| R7 comprobante duplicado por tipo / distinto tipo | Rechazado / permitido |
| R8 cambiar tipo de movimiento con compra asociada | Rechazado |
| Conciliación final | diferencia 0 en todos los artículos |

**Alcance exacto de la verificación:** `01_schema.sql` v0.4 ejecutado dos veces sobre bases recién creadas con `ON_ERROR_STOP` en **PostgreSQL 16.13** (el objetivo institucional es la 18; no disponible en este entorno, no probada); toda la suite anterior corre sobre esa instancia con datos claramente ficticios que no forman parte de ningún entregable. No se simuló concurrencia real.

## Cambios de archivos v0.3 → v0.4

| Archivo | Cambio |
|---|---|
| `01_schema.sql` | Sin columnas `naturaleza` en `movimiento`/`compra` ni FKs compuestas; nuevas funciones/triggers: `fn_naturaleza_movimiento`, `trg_tipomov_naturaleza_inmutable`, `trg_movimiento_valida_requisicion`, `trg_compra_solo_entrada`, `trg_movimiento_borra_hijos`; `fn_movdet_actualiza_saldo` con delta neto; FK del detalle sin cascada |
| `FOSO_DER_v0_4.mmd` (+SVG y vistas por área) | MOVIMIENTO y COMPRA sin `naturaleza`; comentarios actualizados («validado por trigger», «inmutable si el tipo está en uso») |
| `FOSO_DER_v0_4_institucional.pdf` | Regenerado (7 páginas, verificadas visualmente); página 2 ya no menciona FK compuesta |
| `FOSO_E_Normalizacion_4FN_v0_4.md` | Reescrito sobre el esquema real; incluye el antecedente del error de v0.3 |
| Sin cambios | 15 tablas, cardinalidades, índice de despacho único [P], validación de despacho, unicidades, diccionario v0.2 (las columnas eliminadas de v0.3 nunca entraron al diccionario), matriz de decisiones |
