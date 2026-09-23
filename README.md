# FOSOFAMILIA — Sistema de Control de Papelería y Útiles

Proyecto desarrollado para **FOSOFAMILIA** en concepto de horas sociales. El sistema busca centralizar y mejorar el control de artículos de papelería y útiles, compras, requisiciones, movimientos de inventario y reportes.

> **Fecha límite del proyecto completo:** 10 de noviembre de 2026.

## Estado actual

**Fase actual:** diseño y validación de base de datos.

- DER v0.4 congelado como propuesta preliminar para validación institucional.
- 15 tablas en el esquema `papeleria`.
- 5 vistas de consulta/reportes.
- Base de datos objetivo: PostgreSQL 18.
- Verificación local realizada en PostgreSQL **18.6** sobre Windows.
- Suite formal de pruebas: **43 PASS / 0 FAIL / 43 TOTAL**.
- Aplicación C#, frontend y despliegue: pendientes para las siguientes fases.

## Stack requerido

- **Lenguaje:** C#
- **Base de datos:** PostgreSQL
- **Servidor:** Ubuntu Server 24.04 LTS
- **Proxy web:** Nginx o Apache 2
- **Frontend:** HTML/CSS/JavaScript según necesidad
- **Control de versiones:** Git + GitHub

## Estructura del repositorio

```text
FOSOFAMILIA-Control-Papeleria/
├── database/
│   ├── scripts/
│   │   ├── 01_schema.sql
│   │   └── 03_pruebas.sql
│   ├── tools/
│   │   └── verifica_der_vs_sql.py
│   ├── evidencias/
│   └── PROCEDIMIENTO_BD.md
├── diagrams/
│   ├── FOSO_DER_v0_4.mmd
│   ├── genera_areas.py
│   └── areas/
├── docs/
│   ├── der/
│   ├── base-datos/
│   └── informes/
├── src/
├── tests/
├── .gitignore
├── STATUS.md
└── README.md
```

## Base de datos

El script principal es:

```text
database/scripts/01_schema.sql
```

Crea el esquema `papeleria`, sus 15 tablas, restricciones, triggers, funciones y vistas.

La suite formal de pruebas es:

```text
database/scripts/03_pruebas.sql
```

Debe ejecutarse **solo en una base aislada de pruebas**, nunca sobre una base institucional con datos reales.

### Verificación en PostgreSQL 18.6

El 23/09/2026 se ejecutó el esquema desde cero y luego la suite formal de pruebas sobre `foso_test` en PostgreSQL 18.6, obteniendo:

```text
PASS: 43
FAIL: 0
TOTAL: 43
```

Las evidencias se conservan en `database/evidencias/`.

## Decisiones institucionales pendientes

Antes de cerrar la lógica del sistema se deben confirmar con FOSOFAMILIA, entre otros puntos:

- fórmula oficial del costo promedio;
- estados y responsables del flujo de requisiciones;
- posibilidad o no de despachos parciales;
- catálogos reales de unidades de medida, tipos de movimiento, roles y permisos;
- alcance de correlativos y reglas de comprobantes;
- datos requeridos para proveedores y facturas.

Estas decisiones están documentadas en la matriz ubicada en `docs/base-datos/`.

## Próximas fases

1. Validación institucional del DER y reglas pendientes.
2. Arquitectura de la aplicación C#.
3. Autenticación y autorización.
4. Catálogos y gestión de artículos.
5. Inventario y movimientos.
6. Compras.
7. Requisiciones y despachos.
8. Reportes.
9. Pruebas de integración.
10. Despliegue sobre Ubuntu Server 24.04 LTS.
11. Documentación y entrega final antes del **10/11/2026**.

## Seguridad

No deben subirse al repositorio:

- contraseñas;
- cadenas de conexión con credenciales reales;
- archivos `.env`;
- respaldos de bases institucionales;
- información institucional sensible no autorizada;
- archivos fuente originales proporcionados por FOSOFAMILIA salvo autorización expresa.

## Responsable

**Melanie Hernández**  
Proyecto de horas sociales — FOSOFAMILIA, 2026.
