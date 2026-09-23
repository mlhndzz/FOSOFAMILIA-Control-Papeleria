# Informe final — Fase de base de datos (v0.4)
**Proyecto:** Sistema de Control de Papelería y Útiles — FOSOFAMILIA · 22/09/2026
**Alcance de este informe:** exclusivamente la base de datos. Aplicación C#, frontend y despliegue: fases posteriores. DER v0.4 congelado como propuesta preliminar para la entrega institucional del 23/09.

## Entorno de verificación (exacto)
- **Verificación original:** PostgreSQL **16.13** en el entorno de trabajo de desarrollo.
- **Verificación adicional local:** PostgreSQL **18.6 sobre Windows**, realizada el **23/09/2026** mediante `psql`. Se creó una base aislada `foso_test`, se ejecutó `01_schema.sql` desde cero y luego `03_pruebas.sql`, obteniendo **43 PASS / 0 FAIL / 43 total**.
- **Entorno final objetivo:** PostgreSQL 18 sobre Ubuntu Server 24.04 LTS; la aplicación aún no ha sido desplegada ni validada en ese servidor productivo.
- Base de pruebas: `foso_test`, aislada y destruible, con datos ficticios (prefijo PRB).
- Evidencias originales: `04_Resultados_pruebas/salida_03_pruebas_20260922.txt` y `salida_concurrencia_20260922.txt`. Evidencia adicional PostgreSQL 18.6: `04_Resultados_pruebas/verificacion_pg18_43de43_20260923.png` y `VERIFICACION_POSTGRESQL18_20260923.md`.

---

## 1. IMPLEMENTADO Y PROBADO

| Elemento | Prueba / evidencia |
|---|---|
| `01_schema.sql` consolidado: 15 tablas, 5 vistas, 8 funciones/triggers, claves, CHECKs, índices — ejecutable desde cero en base vacía | Ejecutado 2 veces sobre bases recién creadas con `ON_ERROR_STOP`, sin errores |
| **Compatibilidad PostgreSQL 18.6** | Verificación local 23/09/2026: `01_schema.sql` ejecutado desde cero en `foso_test` y suite `03_pruebas.sql` ejecutada con `psql`: **43/43 PASS, 0 FAIL** |
| **Consistencia DER v0.4 ↔ esquema**: 15 entidades, 74 atributos, tipos, orden, PK y columnas FK idénticos | Verificador automatizado `verifica_der_vs_sql.py` → «OK» (22/09) |
| Saldo transaccional (H=E+F−G del Excel), corrección por delta neto, no-negatividad | Suite formal: B1–B2, D3, D6, D8, E1–E3d — **43/43 PASS** |
| Coherencia compra=entrada, requisición=salida, naturaleza inmutable en tipos en uso, movimientos inmutables con líneas/compra | C1, C4–C7 |
| Unicidades: comprobante por tipo [P], proveedor+factura, despacho único [P] | C2, C3, C8, C9, D5 |
| Validación de despacho: artículo ∈ requisición, acumulado ≤ autorizado [P] | D1, D2, D4 |
| Protección de lo ya despachado (modificar/borrar líneas de requisición; borrar requisición con despacho) | F1–F5 |
| Borrado de movimiento con reversión de saldo (sin cascada rota); borrado de línea individual | E4–E7 |
| Obsolescencia y ajustes vía catálogo de tipos (naturaleza E/S) | D7, D8 (tipo demo de obsolescencia) |
| Atomicidad transaccional encabezado+detalle+saldo | G1, G2 (ROLLBACK real) |
| Vistas de reportes del JPG bloque 6 (inventario, compras, requisiciones, salidas) con la aritmética del propio libro | B3, H2–H4; conciliación global H1 |
| **Concurrencia real (2 sesiones psql)**: Z1 — dos salidas que exceden el stock: la segunda espera el bloqueo de fila y es rechazada por el CHECK al ver el saldo final; sin residuos, conciliación 0. Z2 — dos salidas que caben: ambas confirman, saldo exacto | `salida_concurrencia_20260922.txt` (en Z1, el «COMMIT ok» impreso por psql tras el error es el eco del último SELECT: la transacción hizo ROLLBACK, como demuestra que solo Z-A quedó registrada) |

**Transparencia del proceso:** la primera corrida de la suite dio 34/40 — los 6 fallos eran **defectos del guion de pruebas** (reutilización de un movimiento con compra, stock 0 que enmascaraba la validación de despacho, y un escenario negativo aritméticamente imposible que arrastró 3 comprobaciones); el esquema se comportó correctamente en los 6. Corregido el guion, la corrida definitiva es **43/43 PASS**. Ambas salidas están archivadas.

**Verificación adicional del 23/09/2026:** la suite formal fue repetida localmente en **PostgreSQL 18.6** sobre Windows mediante `psql`, con resultado **43/43 PASS**. La prueba de concurrencia real de dos sesiones no se repitió en 18.6 durante esta validación; su evidencia sigue correspondiendo a PostgreSQL 16.13.

## 2. IMPLEMENTADO, PERO NO PROBADO

| Elemento | Por qué no está probado |
|---|---|
| **Entorno final Ubuntu Server 24.04 LTS + PostgreSQL 18** | PostgreSQL 18.6 ya fue validado funcionalmente en Windows, pero todavía falta repetir instalación/ejecución en el servidor Ubuntu objetivo y validar configuración productiva |
| Concurrencia de **borrados/correcciones** simultáneos (solo se probó concurrencia de salidas) y cargas de alto volumen | Fuera del alcance de esta jornada; el mecanismo (bloqueo de fila + CHECK) es el mismo |
| Índice parcial de correo único con datos reales masivos, rendimiento de vistas con volúmenes grandes | Sin datos reales (61 artículos esperados: volumen trivial) |

## 3. PENDIENTE DE CONFIRMACIÓN INSTITUCIONAL
(Detalle y clasificación completa: `FOSO_F_Matriz_Decisiones_Pendientes_v0_4.md`, 12 decisiones)

- **Fórmula del costo promedio** — no implementada a propósito; el Excel evidencia (anterior+compra)/2. Bloquea: recálculo automático y sus pruebas.
- **Estados de la requisición y aprobadores** — bloquea: CHECK de `estado` y la regla «solo aprobadas se despachan».
- **Despachos parciales** — mientras tanto rige el despacho único provisional [P].
- **Catálogos reales**: tipos de movimiento (SM/S5), unidades de medida (**bloquea la carga inicial**), roles/permisos (¿administrables?), unidades organizativas, proveedores (campos fiscales, formato de factura).
- **Alcance del correlativo** de comprobantes (por tipo vs. global).
- Semántica de `cantidad_aprobada`; obligatoriedad del proveedor en compra; mecanismo de recuperación de clave.

## 4. PENDIENTE DE DESARROLLO (fases posteriores, no bloqueado por decisiones)
- Script de carga inicial (`02_carga_inicial.sql`): **diseñado y documentado** (procedimiento §2 y migración §3) pero no escrito, porque depende del catálogo de unidades de medida y del tipo de movimiento de carga — pendientes institucionales.
- Recálculo de costo promedio (tras la decisión 1) y sus pruebas de consistencia.
- Aplicación C#, autenticación, interfaz de reportes (las vistas base ya existen), despliegue en Ubuntu/PostgreSQL 18.

## Archivos del paquete final
Ver `00_LEEME.md` del ZIP: scripts (`01_schema.sql`, `03_pruebas.sql`), procedimiento, verificador DER↔SQL, DER v0.4 (mmd/SVG/PDF institucional), documentación (diccionario, matriz, normalización, integridad/migración, diagnósticos) y resultados crudos de pruebas.
