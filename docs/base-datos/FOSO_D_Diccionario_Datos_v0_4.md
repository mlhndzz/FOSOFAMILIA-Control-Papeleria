# ENTREGABLE D — Diccionario de datos v0.4
**Proyecto:** Sistema de Control de Papelería y Útiles — FOSOFAMILIA
**Fecha:** 22/09/2026 · **Motor objetivo:** PostgreSQL 18 (18.6); verificado originalmente en PostgreSQL 16.13 y adicionalmente el **23/09/2026 en PostgreSQL 18.6 sobre Windows** (esquema completo + suite formal 43/43 PASS)
**Sustituye al diccionario v0.2** y coincide exactamente con `01_schema.sql` v0.4 (con la protección de líneas despachadas). El DER v0.4 institucional está **congelado como propuesta preliminar** para la entrega del 23/09.
**Convención:** `snake_case` español. `[P]` = provisional pendiente de confirmación institucional (ver matriz v0.4). Evidencias: `JPG` = diagrama del proceso; `XLSX!Hoja` = libro CONTROL DE PAPELERIA Y UTILES; `Correo` = correo institucional.

---

## 1. rol — catálogo de roles (JPG bloque 7)
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_rol | smallint | NO | identity | PK | Identificador interno |
| nombre | varchar(60) | NO | — | UNIQUE | Nombre del rol (lista real POR CONFIRMAR) |
| descripcion | varchar(255) | SÍ | — | — | Descripción funcional |
| activo | boolean | NO | true | — | Baja lógica |

## 2. permiso — catálogo de permisos (JPG bloque 7)
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_permiso | smallint | NO | identity | PK | Identificador interno |
| codigo | varchar(60) | NO | — | UNIQUE | Código estable (p. ej. modulo.accion) |
| descripcion | varchar(255) | SÍ | — | — | Descripción |

## 3. rol_permiso — asociación N:M
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_rol | smallint | NO | — | PK, FK→rol | Rol |
| id_permiso | smallint | NO | — | PK, FK→permiso | Permiso concedido |

## 4. usuario — usuarios del sistema (JPG bloque 1; Correo req. 3)
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_usuario | integer | NO | identity | PK | Identificador interno |
| nombre_usuario | varchar(60) | NO | — | UNIQUE | Credencial de acceso |
| nombre_completo | varchar(120) | NO | — | — | Nombre de la persona |
| correo | varchar(120) | SÍ | — | UNIQUE parcial sobre lower(correo) cuando no es nulo | [P] Necesario si la recuperación de clave es por correo — mecanismo POR CONFIRMAR |
| hash_contrasena | varchar(255) | NO | — | — | Hash con sal; nunca texto plano. Algoritmo se decide en desarrollo |
| id_rol | smallint | NO | — | FK→rol | [P] Un solo rol por usuario |
| id_unidad_organizativa | integer | SÍ | — | FK→unidad_organizativa | [P] Adscripción del usuario |
| activo | boolean | NO | true | — | Baja lógica |
| fecha_creacion | timestamptz | NO | now() | — | Auditoría mínima |

## 5. unidad_organizativa — unidades solicitantes (JPG bloques 4/6/7)
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_unidad_organizativa | integer | NO | identity | PK | Identificador interno |
| nombre | varchar(120) | NO | — | UNIQUE | Nombre (catálogo real POR CONFIRMAR; el Excel no trae unidades) |
| activo | boolean | NO | true | — | Baja lógica |

## 6. especifico — clasificador/línea (XLSX!INVENTARIO filas 5/26/68; JPG bloque 7)
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_especifico | integer | NO | identity | PK | Identificador interno |
| codigo | varchar(10) | NO | — | UNIQUE | Ej. «54105» (alcance del clasificador POR CONFIRMAR) |
| nombre | varchar(120) | NO | — | — | Ej. «PRODUCTOS DE PAPEL Y CARTON» |
| activo | boolean | NO | true | — | Baja lógica |

## 7. unidad_medida — catálogo (JPG bloque 7; sin datos en el Excel)
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_unidad_medida | smallint | NO | identity | PK | Identificador interno |
| abreviatura | varchar(10) | NO | — | UNIQUE | Valores reales POR CONFIRMAR |
| nombre | varchar(60) | NO | — | UNIQUE | Nombre completo |

## 8. articulo — artículos (XLSX!INVENTARIO, 61 códigos activos)
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_articulo | integer | NO | identity | PK | Identificador interno estable |
| codigo | varchar(30) | NO | — | UNIQUE; CHECK `codigo = btrim(codigo) AND codigo <> ''` | Código visible tipo «PABONDTC» (col B); el CHECK rechaza espacios de borde observados en el libro |
| descripcion | varchar(200) | NO | — | — | Descripción (col C) |
| id_especifico | integer | NO | — | FK→especifico | Línea (filas «LINEA:») |
| id_unidad_medida | smallint | NO | — | FK→unidad_medida | [P] Obligatoria por diseño; el Excel no la trae — **bloquea la carga inicial hasta recibir el catálogo** |
| existencia_actual | numeric(12,2) | NO | 0 | CHECK ≥ 0 | Saldo materializado por `trg_movdet_saldo` (delta neto en correcciones) en la misma transacción del movimiento. Fuente de verdad: movimientos (H=E+F−G del Excel) |
| costo_promedio_actual | numeric(12,4) | NO | 0 | CHECK ≥ 0 | Costo vigente (col I, 4 decimales). REGLA PENDIENTE: recálculo no implementado; el Excel evidencia (anterior+compra)/2 |
| activo | boolean | NO | true | — | Baja lógica |

## 9. proveedor (JPG bloques 6/7; XLSX!COMPRAS C5 con columna vacía)
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_proveedor | integer | NO | identity | PK | Identificador interno |
| nombre | varchar(150) | NO | — | UNIQUE | Razón social |
| registro_fiscal | varchar(30) | SÍ | — | — | [P] Campos fiscales exactos POR CONFIRMAR |
| activo | boolean | NO | true | — | Baja lógica |

## 10. tipo_movimiento — catálogo de tipos (códigos «SM»/«S5» observados sin significado confirmado)
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_tipo_movimiento | smallint | NO | identity | PK | Identificador interno |
| codigo | varchar(10) | NO | — | UNIQUE | Catálogo definitivo POR CONFIRMAR (no se insertan filas) |
| nombre | varchar(80) | NO | — | — | Denominación |
| naturaleza | char(1) | NO | — | CHECK IN ('E','S'); **inmutable si el tipo tiene movimientos** (`trg_tipomov_naturaleza_inmutable`) | E suma stock, S resta. Única residencia de la naturaleza en el esquema (3FN) |

## 11. movimiento — encabezado de todo evento que modifica existencias
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_movimiento | bigint | NO | identity | PK | Identificador interno |
| id_tipo_movimiento | smallint | NO | — | FK→tipo_movimiento | Tipo; **no cambia** si el movimiento tiene líneas o compra (`trg_movimiento_bloquea_cambios`) |
| numero_comprobante | varchar(20) | NO | — | UNIQUE (id_tipo_movimiento, numero_comprobante) | [P] Correlativo por tipo (alcance POR CONFIRMAR) |
| fecha | date | NO | — | — | Fecha del documento |
| id_usuario_registra | integer | NO | — | FK→usuario | Trazabilidad (práctica evidenciada: «ELABORADO: …») |
| id_requisicion | integer | SÍ | — | FK→requisicion; **solo tipos de naturaleza S** (`trg_movimiento_valida_requisicion`); índice UNIQUE parcial `ux_movimiento_despacho_unico` [P] | Despacho de una requisición. El índice único es la **restricción provisional de despacho único** |
| observacion | varchar(255) | SÍ | — | — | Observaciones |
| fecha_registro | timestamptz | NO | now() | — | Auditoría mínima |

Comportamiento de borrado: `trg_movimiento_borra_hijos` (BEFORE DELETE) elimina la fila de `compra` y las líneas **con el encabezado aún visible**, y el trigger de saldo revierte cada línea; si la reversión dejara un saldo negativo, el borrado completo se rechaza.

## 12. movimiento_detalle — líneas del movimiento
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_movimiento | bigint | NO | — | PK, FK→movimiento (**sin ON DELETE CASCADE**; el borrado lo orquesta el trigger del padre) | Encabezado |
| numero_linea | smallint | NO | — | PK compuesta; CHECK > 0 | Nº de línea (mismo artículo repetible por documento — evidencia 2019) |
| id_articulo | integer | NO | — | FK→articulo | Artículo afectado |
| cantidad | numeric(12,2) | NO | — | CHECK > 0 | Cantidad |
| costo_unitario | numeric(12,4) | NO | — | CHECK ≥ 0 | Costo histórico congelado (VLOOKUP del Excel; nota RESUMEN 44–47) |

Triggers sobre esta tabla: `trg_movdet_saldo` (mantiene `articulo.existencia_actual`; en UPDATE del mismo artículo aplica delta neto) y `trg_movdet_valida_despacho` (artículo ∈ requisición y acumulado ≤ autorizado [P]).

## 13. compra — subtipo 1:1 de movimiento para entradas por compra
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_movimiento | bigint | NO | — | PK, FK→movimiento; **solo movimientos de entrada** (`trg_compra_solo_entrada`) | Movimiento que extiende; PK=FK impide duplicar la fila |
| id_proveedor | integer | NO | — | FK→proveedor | [P] Obligatorio por diseño (reporte por proveedor); columna vacía en el Excel |
| numero_factura | varchar(50) | NO | — | UNIQUE (id_proveedor, numero_factura) | El Excel trae GUIDs sin interpretar; formato real POR CONFIRMAR |

## 14. requisicion — solicitud de una unidad (no modifica stock)
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_requisicion | integer | NO | identity | PK | Identificador interno |
| numero | varchar(20) | NO | — | UNIQUE | Correlativo visible |
| id_unidad_organizativa | integer | NO | — | FK→unidad_organizativa | Unidad solicitante |
| id_usuario_solicita | integer | NO | — | FK→usuario | [P] Depende de si las unidades tienen usuario propio |
| fecha_solicitud | date | NO | — | — | Fecha de creación |
| estado | varchar(20) | NO | — | **CHECK diferido** | REGLA PENDIENTE: lista de estados POR CONFIRMAR |
| id_usuario_revisa | integer | SÍ | — | FK→usuario | Revisor/aprobador (rol exacto POR CONFIRMAR) |
| fecha_revision | timestamptz | SÍ | — | — | Cuándo se revisó |
| observacion | varchar(255) | SÍ | — | — | Observaciones |

Borrado: una requisición **con despachos no puede eliminarse** (FK de `movimiento.id_requisicion`, sin acción de borrado); una sin despachos se elimina con sus líneas (cascada).

## 15. requisicion_detalle — líneas solicitadas
| Columna | Tipo | Nulable | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| id_requisicion | integer | NO | — | PK, FK→requisicion ON DELETE CASCADE | Solicitud |
| numero_linea | smallint | NO | — | PK compuesta; CHECK > 0 | Nº de línea |
| id_articulo | integer | NO | — | FK→articulo | Artículo solicitado |
| cantidad_solicitada | numeric(12,2) | NO | — | CHECK > 0 | Lo pedido |
| cantidad_aprobada | numeric(12,2) | SÍ | — | CHECK ≥ 0 | [P] Lo autorizado; NULL hasta revisión |

Trigger `trg_reqdet_protege_despachado` (AFTER UPDATE/DELETE): rechaza modificar o borrar líneas de forma que lo **ya despachado** de un artículo exceda la autorización restante — cubre reducir cantidades, borrar líneas y cambiar el artículo de una línea despachada.

## Objetos no-tabla
- **Vista `vw_existencias_calculadas`**: existencia calculada desde movimientos (naturaleza vía `tipo_movimiento`) vs. saldo materializado; `diferencia <> 0` = inconsistencia. Reproduce el bloque de conciliación del Excel (roto con `#REF!`).
- **Vistas de reportes (JPG bloque 6)** — consultas derivadas, sin almacenar resultados; los filtros (período, proveedor, unidad) los aplica el consumidor con WHERE:
  - `vw_reporte_inventario`: stock y valoración por artículo/línea; `costo_total = ROUND(existencia × costo_promedio_actual, 2)` — el criterio del propio libro (INVENTARIO J=H×I, redondeo K).
  - `vw_reporte_compras`: fecha, comprobante, proveedor, factura y líneas con costo unitario **congelado** y `costo_total_linea = cantidad × costo_unitario`.
  - `vw_reporte_requisiciones`: solicitudes por unidad con solicitado/aprobado y **despachado por artículo** (si un artículo ocupa varias líneas, cada línea muestra el despacho total del artículo — documentado en el COMMENT).
  - `vw_reporte_salidas`: todas las salidas (requisición, ajustes, obsolescencia) con unidad organizativa cuando proviene de requisición; cada línea al costo histórico (RESUMEN G=E×F y nota 44–47).
- **Función `fn_naturaleza_movimiento(bigint)`**: naturaleza de un movimiento vía su tipo (única fuente, 3FN).
- **Triggers**: los 7 descritos arriba (secciones 10–15). Reglas de negocio aún no implementadas: recálculo de costo promedio, CHECK de estados, control de despacho parcial.
