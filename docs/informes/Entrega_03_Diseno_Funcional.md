# FOSOFAMILIA — Entrega 3: Diseño funcional
**26 de octubre de 2026 | Melanie Hernández**

## Navegación prevista
Login → Panel principal → Artículos → Catálogos → Compras → Inventario → Requisiciones → Reportes → Usuarios y permisos.

## Módulos y datos
| Módulo | Tablas de referencia | Función principal |
|---|---|---|
| Seguridad | usuario, rol, permiso, rol_permiso | Acceso y permisos |
| Catálogos | especifico, unidad_medida, proveedor | Registros maestros |
| Artículos | articulo | Lista, alta, edición, desactivación |
| Compra e inventario | compra, movimiento, movimiento_detalle, tipo_movimiento | Entradas y saldos |
| Requisiciones | requisicion, requisicion_detalle, unidad_organizativa | Solicitudes internas |
| Reportes | vistas del esquema papeleria | Consultas y filtros |

## Flujo de compra
Capturar datos → verificar proveedor, tipo de entrada y artículos → comenzar transacción → registrar movimiento, compra y líneas → aplicar triggers de saldo → confirmar transacción o revertir por error.

## Flujo de requisición
Solicitar artículos → validar cantidades y solicitante → revisión por responsable (según reglas por confirmar) → validar autorización y existencia → registrar despacho en transacción → emitir comprobante.

## Reglas obligatorias
No actualizar manualmente `articulo.existencia_actual`; respetar las restricciones de base de datos; no establecer estados ni despachos parciales antes de la validación institucional; verificar permisos en backend.

**Estado:** diseño realizado; pantallas, operaciones y evidencias reales pendientes.
