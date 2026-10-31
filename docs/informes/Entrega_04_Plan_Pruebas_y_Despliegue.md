# FOSOFAMILIA — Entrega 4: Implementación, pruebas y despliegue
**26 de octubre de 2026 | Melanie Hernández**

## Plan de recuperación hasta el 10 de noviembre de 2026
| Fecha | Meta |
|---|---|
| 26/10 | Documentos 2, 3 y 4; proyecto inicial ASP.NET Core |
| 27/10 | Conexión a PostgreSQL y lectura de datos |
| 28/10 | Login y autorización |
| 29–30/10 | Catálogos y artículos |
| 31/10–01/11 | Compras y entradas |
| 02–03/11 | Requisiciones y despachos |
| 04/11 | Reportes |
| 05–06/11 | Pruebas de integración y correcciones |
| 07–08/11 | Prueba de despliegue Ubuntu Server |
| 09/11 | Manual técnico, manual de usuario y evidencias |
| 10/11 | Entrega final |

## Pruebas de aceptación pendientes
- Inicio de sesión válido e inválido.
- Rechazo a funciones sin autorización.
- Registro de artículo y rechazo de códigos duplicados.
- Compra: saldo actualizado mediante trigger.
- Salida superior al saldo: rechazo sin operaciones parciales.
- Requisición y despacho: cantidades válidas y trazabilidad.
- Reportes: datos correctos.
- Despliegue: acceso mediante servidor y proxy seguro.

## Despliegue previsto
Publicación .NET con `dotnet publish -c Release`, servicio `systemd` en Ubuntu 24.04 LTS, proxy Nginx o Apache, conexión PostgreSQL con secretos fuera del código, HTTPS, firewall y respaldos.

## Riesgos
Plazos cortos, reglas sin confirmar, fallos de concurrencia y manejo de credenciales. Priorización: flujo básico artículos → compras → inventario → requisiciones → salidas. Aplicar las pruebas SQL antiguas únicamente en una base aislada.

**Estado:** plan y matriz preparados; pruebas de aplicación y despliegue NO ejecutadas todavía.
