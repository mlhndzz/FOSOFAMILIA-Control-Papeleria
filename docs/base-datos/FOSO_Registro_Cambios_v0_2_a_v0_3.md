# Registro de cambios — DER/SQL v0.2 → v0.3
**Proyecto:** FOSOFAMILIA — Control de Papelería y Útiles · 22/09/2026
Motivo: auditoría técnica externa recibida el 22/09. El modelo lógico de v0.2 se conserva como base; no hubo reconstrucción, solo correcciones puntuales.

## Cambios estructurales (afectan DER y SQL)

| # | Cambio | Motivo (punto de auditoría) |
|---|---|---|
| 1 | `tipo_movimiento`: nuevo `UNIQUE (id_tipo_movimiento, naturaleza)` | Soporte del patrón de FK compuesta (punto 2) |
| 2 | `movimiento`: nueva columna `naturaleza char(1) NOT NULL` como **copia controlada** del tipo, atada por FK compuesta `(id_tipo_movimiento, naturaleza)`; nuevo `UNIQUE (id_movimiento, naturaleza)` de soporte | La PK compartida de v0.2 no impedía compras sobre salidas; se reconoció y corrigió (punto 2) |
| 3 | `movimiento`: nuevo `CHECK (id_requisicion IS NULL OR naturaleza='S')` | Una requisición no puede vincularse a una entrada (punto 2) — en v0.2 esto era solo una nota |
| 4 | `movimiento`: nuevo índice único parcial `ux_movimiento_despacho_unico` sobre `id_requisicion` — **[P] provisional** | Sin confirmación sobre despachos parciales, garantiza no-duplicidad de salidas por requisición; reversible (punto 3) |
| 5 | `compra`: nueva columna `naturaleza char(1) NOT NULL DEFAULT 'E' CHECK ('E')` + FK compuesta `(id_movimiento, naturaleza) → movimiento` | Compra solo puede extender un movimiento de entrada, de forma declarativa (punto 2) |

## Lógica transaccional nueva (SQL)

| # | Cambio | Motivo |
|---|---|---|
| 6 | Trigger `trg_movdet_saldo` (`fn_movdet_actualiza_saldo`): mantiene `articulo.existencia_actual` en INSERT/UPDATE/DELETE de líneas (+E/−S) | Con el CHECK ≥ 0 ya existente, el stock negativo queda imposible a nivel de BD (punto 3); reproduce H=E+F−G del Excel. No toca el costo promedio |
| 7 | Trigger `trg_movimiento_bloquea_cambios`: prohíbe cambiar tipo/naturaleza/requisición de un movimiento con líneas | Evita recálculos opacos de saldo; las correcciones se hacen con movimientos de ajuste (punto 2) |
| 8 | Trigger `trg_movdet_valida_despacho` (`fn_valida_despacho`): (a) artículo debe estar en la requisición; (b) despachado acumulado ≤ autorizado, con "autorizado" = `COALESCE(cantidad_aprobada, cantidad_solicitada)` **[P]** | Puntos 3a y 3b de la auditoría |

## Documentación y presentación

| # | Cambio | Motivo |
|---|---|---|
| 9 | PDF rediseñado (7 páginas A3 apaisado): portada+leyenda, página de provisionales/decisiones, DER general compacto y 4 vistas por área con atributos legibles. Sin páginas semivacías; verificado visualmente página por página | Punto 1 de la auditoría |
| 10 | Los diagramas por área y la vista general **se derivan por script** (`genera_areas.py`) del archivo canónico `FOSO_DER_v0_3.mmd` | Garantía de un único modelo lógico consistente entre diagramas (punto 1) |
| 11 | Nuevo documento `FOSO_Integridad_y_Migracion_v0_3.md`: análisis de integridad compras/movimientos y requisiciones/despachos, plan de carga inicial con conciliación contra los totales del libro, y declaración de alcance del SQL (estructura / restricciones / reglas pendientes / procesos no desarrollados) | Puntos 2, 3, 4 y 5 |
| 12 | Encabezado de `01_schema.sql` reescrito con el estado del script en 4 categorías; se retiró la sección "huecos" dispersa en favor de esa declaración | Punto 5 |

## Sin cambios (decisiones de v0.2 que se conservan)
- Las 15 entidades, sus claves y todas las cardinalidades de v0.2 (las nuevas columnas `naturaleza` no alteran relaciones).
- PK de detalles por `(documento, numero_linea)`; costo histórico congelado por línea; saldo y costo vigente materializados; catálogos con baja lógica; derivados no almacenados; vista de conciliación (ahora usa `movimiento.naturaleza` directamente).
- Todos los huecos institucionales declarados en la matriz F de v0.2 siguen abiertos; ninguno se rellenó con reglas inventadas.

## Verificación
`01_schema.sql` v0.3 ejecutado 2 veces sobre bases limpias en **PostgreSQL 16.13** (objetivo: 18; no disponible en el entorno) + suite de 13 escenarios de integridad, todos con el resultado esperado. Detalle exacto y una incidencia del proceso de prueba (corregida) en `FOSO_Integridad_y_Migracion_v0_3.md`, sección 5.

## Impacto sobre documentos v0.2
- **Diccionario de datos v0.2**: sigue válido salvo las adiciones de los cambios 1–5 (columnas `naturaleza` en `movimiento` y `compra`, y las nuevas restricciones); se consolidará como diccionario v1.0 cuando FOSOFAMILIA responda las decisiones pendientes, para no versionar dos veces en un día.
- **Normalización 4FN v0.2**: sigue válida; la columna `naturaleza` es una copia controlada por FK (la DF `id_tipo_movimiento → naturaleza` se conserva y la FK compuesta impide divergencia), excepción documentada en `FOSO_Integridad_y_Migracion_v0_3.md` §1.
- **Matriz de decisiones v0.2**: sin cambios de fondo; el punto 4 (despachos) pasa de "sin restricción" a "restricción provisional de despacho único [P]".
