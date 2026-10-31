# FOSOFAMILIA — Entrega 2: Arquitectura y requisitos
**26 de octubre de 2026 | Melanie Hernández**

## Antecedentes
La primera fase dejó un DER v0.4 y un esquema PostgreSQL `papeleria` de 15 tablas y 5 vistas. La suite SQL alcanzó 43/43 pruebas PASS el 23 de septiembre. El licenciado autorizó continuar con la siguiente etapa.

## Objetivo
Crear un sistema web para administrar inventario de papelería y útiles, compras, usuarios, requisiciones, despachos y reportes.

## Arquitectura propuesta
Navegador web → ASP.NET Core (C#) → capa de reglas y acceso a datos → PostgreSQL 18 (`papeleria`). Destino de despliegue: Ubuntu Server 24.04 LTS, servidor proxy Nginx/Apache, interfaz HTML/CSS/JS.

## Requisitos funcionales
- RF01: Inicio y cierre de sesión; control por roles y permisos.
- RF02: Catálogos: específicos, unidades de medida y proveedores.
- RF03: Artículos: registrar, buscar, editar y desactivar sin alterar saldos a mano.
- RF04: Compras y entradas con transacciones.
- RF05: Consultar inventario y movimientos.
- RF06: Crear y gestionar requisiciones internas.
- RF07: Despachos con control de existencias y cantidades autorizadas.
- RF08: Reportes basados en las vistas SQL existentes.

## Requisitos no funcionales
Contraseñas almacenadas como hashes seguros, consultas parametrizadas, validación y autorización en servidor, control transaccional, credenciales fuera de Git, HTTPS, respaldo y recuperación.

## Pendientes institucionales
Confirmar costo promedio, estados de requisiciones, responsables, despachos parciales, catálogos reales, roles/permisos, códigos de movimiento, correlativos y requisitos de facturas.

**Estado:** arquitectura documentada; implementación funcional aún pendiente.
