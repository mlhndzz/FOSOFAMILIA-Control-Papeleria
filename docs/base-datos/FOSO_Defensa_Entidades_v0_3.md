# Justificación de las 15 tablas del modelo v0.3 — documento interno de defensa técnica
**Proyecto:** FOSOFAMILIA — Control de Papelería y Útiles · 22/09/2026
**Carácter:** documento interno de desarrollo. No forma parte de la entrega institucional.

## Contexto
En la reunión del 22/09, según lo reportado por Melanie, el licenciado estimó **aproximadamente 10 u 11 entidades** para el sistema. No conocemos el criterio con el que hizo esa estimación (¿entidades conceptuales?, ¿tablas físicas?, ¿solo las del flujo operativo?), y los audios de la reunión siguen sin transcribir, así que **no se afirma coincidencia ni discrepancia con nuestro modelo**: solo se deja constancia de que el orden de magnitud es compatible y de que cada tabla del modelo tiene justificación propia, que es lo defendible.

El modelo lógico v0.3 tiene **15 tablas**: **12 corresponden a entidades conceptuales del negocio** (cosas que FOSOFAMILIA nombraría: usuarios, roles, permisos, unidades, artículos, proveedores, comprobantes, solicitudes…) y **3 son tablas auxiliares del modelo lógico** (resuelven una relación N:M y las líneas de los documentos). La cantidad de tablas no se justifica "por cumplir 3FN/4FN": se justifica, tabla por tabla, por los requisitos y las dependencias identificadas en las fuentes. La forma normal es una propiedad que el diseño resultante cumple, no la causa del número.

## Tabla de justificación

| # | Tabla | Clase | Justificación funcional | Justificación técnica | Veredicto |
|---|---|---|---|---|---|
| 1 | `usuario` | Conceptual | Login y gestión de usuarios (JPG bloque 1; correo req. 3) | Autoría de movimientos y solicitudes (FKs de trazabilidad) | Mantener |
| 2 | `rol` | Conceptual | «Definir Roles y Permisos» (JPG bloque 7) | Autorización por rol en backend (regla 10 del proyecto) | Mantener |
| 3 | `permiso` | Conceptual | El mismo bloque 7 trata los permisos como configuración administrable | Permite ajustar autorizaciones sin recompilar | Mantener, con alternativa [P]: si FOSOFAMILIA confirma que el conjunto de permisos es fijo en la aplicación, `permiso` y `rol_permiso` pueden retirarse (→13 tablas) sin pérdida de información. Única reducción sin costo identificada |
| 4 | `rol_permiso` | Auxiliar | — | Resuelve la relación N:M rol↔permiso; sin ella, un rol no podría tener varios permisos sin repetir grupos | Sigue la suerte de `permiso` |
| 5 | `unidad_organizativa` | Conceptual | Las unidades crean solicitudes (JPG bloque 4); reporte «salidas por departamento» (bloque 6) | Dimensión de los reportes de consumo | Mantener |
| 6 | `especifico` | Conceptual | Líneas reales 54105/54114/54115 del Excel (INVENTARIO filas 5/26/68); «categorías/códigos específicos» (JPG 7) | Agrupa artículos y totales de reportes como hace el libro | Mantener |
| 7 | `unidad_medida` | Conceptual | Catálogo explícito del JPG bloque 7 (el Excel no trae datos) | Evita valores libres inconsistentes («c/u», «C/U», «unidad»). Alternativa evaluada y descartada: columna de texto en `articulo` (−1 tabla) contradiría el catálogo administrable que el diagrama pide | Mantener |
| 8 | `articulo` | Conceptual | Núcleo del inventario (61 artículos reales en INVENTARIO) | Punto único de código, descripción, saldo y costo vigente | Mantener |
| 9 | `proveedor` | Conceptual | Configuración (JPG 7) y reporte de compras por proveedor (JPG 6) | Unicidad de factura por proveedor | Mantener |
| 10 | `tipo_movimiento` | Conceptual | Cuatro comportamientos evidenciados: compra, salida por requisición, ajustes ±, obsolescencia (Excel D83–D85, hojas ocultas); códigos «SM»/«S5» observados | Catálogo con naturaleza E/S que alimenta las FKs compuestas de coherencia. Alternativa evaluada y descartada: enum/CHECK fijo (−1 tabla) congelaría un catálogo que está pendiente de confirmación institucional | Mantener |
| 11 | `movimiento` | Conceptual | Todo comprobante que cambia existencias; estructura común de las 4 hojas del Excel | Fuente de verdad del stock (H=E+F−G); trazabilidad de fecha, usuario, comprobante | Mantener |
| 12 | `movimiento_detalle` | Auxiliar | Un comprobante del libro tiene varias líneas artículo-cantidad-costo (todas las hojas) | Materializa el requisito evidenciado de N líneas por documento con costo histórico congelado por línea; en una sola tabla ese hecho repetido no cabría sin duplicar el encabezado en cada línea | Mantener — sustentada por el requisito, no opcional |
| 13 | `compra` | Conceptual (subtipo) | La factura y el proveedor solo existen en compras (hoja COMPRAS) | Subtipo 1:1 restringido a entradas por FK compuesta; evita columnas vacías en ajustes/salidas. Alternativa evaluada y descartada: fusionar en `movimiento` con columnas anulables (−1 tabla) debilitaría esa garantía a CHECKs sobre NULLs | Mantener |
| 14 | `requisicion` | Conceptual | Flujo completo del JPG bloque 4; solicitar no cambia stock (lo cambia el despacho) | Separa solicitud/aprobación del movimiento físico; ancla de las validaciones de despacho | Mantener |
| 15 | `requisicion_detalle` | Auxiliar | Una solicitud pide varios artículos | Mismo argumento que #12, con cantidades solicitada/aprobada por línea | Mantener — sustentada por el requisito, no opcional |

## Conclusiones
1. **No hay redundancias demostradas**: cada tabla responde a un requisito o a una dependencia identificada en el correo, el diagrama o el Excel. Las tres alternativas de reducción evaluadas (fusionar `compra`, enum para tipos, texto para unidad de medida) se descartaron con razones, no por preferencia.
2. La **única simplificación sin pérdida** (permiso+rol_permiso → 13 tablas) depende de una confirmación institucional y queda registrada en la matriz de decisiones pendientes.
3. Sobre la estimación de 10–11: se responde que el modelo contiene 12 entidades conceptuales y 3 tablas de apoyo del modelo lógico, se explica qué aporta cada una, y **no** se presenta la cifra del licenciado como validada ni contradicha. Este análisis no altera el PDF institucional.
4. No se realizó ningún cambio estructural por razones de conteo.
