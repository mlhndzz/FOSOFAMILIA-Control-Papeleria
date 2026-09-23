# ENTREGABLE F — Matriz de decisiones pendientes de validación institucional (v0.4)
**Proyecto:** Sistema de Control de Papelería y Útiles — FOSOFAMILIA · 22/09/2026
**Sustituye a la matriz v0.2.** Estado del proyecto: **DER v0.4 congelado como propuesta preliminar** para la entrega del 23/09; esquema `01_schema.sql` v0.4 verificado originalmente en PostgreSQL 16.13 y adicionalmente el **23/09/2026 en PostgreSQL 18.6 sobre Windows**, con suite formal **43/43 PASS**.

**Clases:** **T** = resuelta técnicamente (reversible) · **I** = requiere confirmación institucional · **B** = bloquea una restricción o proceso específico.

## Decisiones pendientes

| # | Decisión | Clase | Estado actual en el modelo v0.4 | Qué cambia al confirmarse |
|---|---|---|---|---|
| 1 | **Fórmula del costo promedio** | I + B (para el proceso de costeo) | Las tablas sirven a cualquier política (costo histórico por línea + costo vigente por artículo). La fórmula del Excel — (costo anterior + costo compra)/2, promedio simple — está documentada como evidencia, **sin implementar** | Trigger/procedimiento de recálculo + pruebas de consistencia del costo |
| 2 | Significado de «SM»/«S5» y catálogo de tipos de movimiento | I | `tipo_movimiento` es catálogo abierto sin filas; naturaleza E/S inmutable en uso | Seed del catálogo oficial |
| 3 | Alcance del correlativo de comprobantes (global o por tipo) | B (para la restricción UNIQUE) | UNIQUE (tipo, comprobante) — opción menos restrictiva | Si es global: UNIQUE(numero_comprobante) |
| 4 | Estados de la requisición y quién aprueba | B (CHECK de `estado`; validación «solo aprobadas se despachan») | Columna `estado` NOT NULL **sin CHECK**; el despacho no exige estado (no se inventó la regla) | CHECK de estados + validación de estado en el despacho + permisos del flujo |
| 5 | **¿Despachos parciales?** | B (cardinalidad requisición↔movimiento) | **Restricción provisional de despacho único**: índice único parcial `ux_movimiento_despacho_unico` sobre `movimiento(id_requisicion)`. Garantiza además la no-duplicidad de salidas por requisición. La validación de cantidades ya acumula por artículo, así que la transición a parciales es pequeña | Si hay parciales: se elimina el índice y el control pasa al acumulado por línea (ya existente) más, si se desea, `cantidad_despachada` materializada |
| 6 | Semántica de la aprobación (¿puede aprobar menos de lo solicitado?) | I + B (definición de «autorizado») | `cantidad_aprobada` nullable; autorizado = COALESCE(aprobada, solicitada) en las validaciones | Fijar la regla y, si procede, NOT NULL tras revisión |
| 7 | Datos reales de proveedor y factura; obligatoriedad del proveedor en compra | I | `id_proveedor` NOT NULL [P]; unicidad (proveedor, factura); GUIDs del Excel documentados sin interpretar | Campos fiscales; formato de factura; definición completa de «compra lógica» |
| 8 | Alcance de artículos (¿solo 54105/54114/54115?) | I | `especifico` catálogo abierto | Solo datos |
| 9 | ¿Usuarios propios por unidad? ¿Roles reales? ¿Multi-rol? | I; multi-rol es B (cardinalidad rol-usuario) | Rol único [P]; `id_unidad_organizativa` nullable [P] | Multi-rol → tabla `usuario_rol` |
| 10 | **¿Permisos administrables o fijos en la aplicación?** | I | `permiso` + `rol_permiso` existen (JPG trata «roles y permisos» como configuración) | Si son fijos: ambas tablas pueden retirarse (→13) sin pérdida — única reducción sin costo identificada |
| 11 | Mecanismo de recuperación de clave y política de bloqueo | I | Solo `correo` opcional; sin tablas de tokens | Tablas/columnas del mecanismo elegido |
| 12 | Catálogo de unidades de medida | I + **B para la carga inicial** | `articulo.id_unidad_medida` NOT NULL [P] sin datos disponibles: **la migración de artículos queda bloqueada hasta recibirlo** | Seed y desbloqueo de la carga |

## Decisiones técnicas ya tomadas (T) — reversibles, con sustento

| Decisión | Sustento | Verificación |
|---|---|---|
| Movimiento genérico + detalle; `compra` subtipo 1:1 solo sobre entradas; requisición solo en salidas (triggers + naturaleza inmutable en tipos en uso) | 4 comportamientos con estructura común en el Excel; flujo del JPG | Pruebas R1–R8 (v0.4) |
| Costo histórico congelado por línea | VLOOKUP + nota RESUMEN 44–47 | Suite v0.4 |
| PK de detalles por (documento, numero_linea) | Artículo repetido por documento (histórico 2019) | Suite v0.4 |
| Saldo materializado por trigger con **delta neto** + CHECK ≥ 0 + vista de conciliación | H=E+F−G y bloque de conciliación del Excel | Escenarios P2/P2b |
| Borrado de movimiento orquestado por trigger (sin cascada), reversión de saldo garantizada | Corrección del defecto de cascada | Escenarios P3/P3b/P3c |
| **Protección de líneas de requisición ya despachadas**: no se puede reducir/borrar/cambiar una línea si lo entregado excedería lo autorizado; requisición con despachos no se borra (FK) | Integridad de lo ya entregado; sin regla institucional inventada (solo impide la incoherencia aritmética) | Escenarios Q1–Q7 |
| Baja lógica en catálogos; derivados no almacenados | Histórico con artículos descontinuados; `#REF!` del libro | — |

## No incluido por falta de evidencia (sin cambios)
Multi-bodega; entregas parciales estructuradas; historial de costo promedio como tabla; notificaciones automáticas; SSO/GitHub/Redis; framework concreto (ASP.NET Core sigue siendo propuesta para la fase de desarrollo).

## Fuentes pendientes
Audios `primera/proyecto/skills/carta.m4a`: sin transcribir; ninguna fila de esta matriz se apoya en ellos. La cifra «10–11 entidades» atribuida al licenciado permanece como dato reportado sin criterio conocido (ver documento de defensa de entidades).
