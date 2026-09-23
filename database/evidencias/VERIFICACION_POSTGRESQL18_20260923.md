# Verificación adicional — PostgreSQL 18.6

**Proyecto:** FOSOFAMILIA — Base de datos v0.4  
**Fecha:** 23/09/2026  
**Entorno:** Windows + PostgreSQL 18.6 (`psql (PostgreSQL) 18.6`)

## Procedimiento ejecutado

1. Se creó una base aislada `foso_test`.
2. Se ejecutó `01_schema.sql` desde cero mediante `psql` con `ON_ERROR_STOP=1`.
3. El esquema final creó correctamente las 15 tablas del esquema `papeleria`, junto con funciones, triggers y vistas.
4. Se ejecutó `03_pruebas.sql` mediante `psql` (no mediante el Query Tool de pgAdmin, porque la suite contiene control transaccional pensado para `psql`).
5. Resultado final observado: **43 PASS / 0 FAIL / 43 total**.

## Alcance

Esta verificación confirma la ejecución funcional del esquema y de la suite formal en PostgreSQL 18.6 sobre Windows. No equivale todavía a una validación del despliegue final en Ubuntu Server 24.04 LTS. La prueba de concurrencia de dos sesiones no se repitió durante esta ejecución local; su evidencia existente corresponde a PostgreSQL 16.13.

## Evidencia

- `verificacion_pg18_43de43_20260923.png`: captura del resumen final 43/43 PASS.
- `verificacion_pg18_schema_20260923.png`: captura de ejecución del esquema con `COMMIT`.
- `verificacion_pg18_tablas_20260923.png`: captura de las 15 tablas creadas en el esquema `papeleria`.
