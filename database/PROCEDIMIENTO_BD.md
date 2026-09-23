# Procedimiento de creación, inicialización y verificación de la base de datos
**Proyecto:** Sistema de Control de Papelería y Útiles — FOSOFAMILIA · 22/09/2026
**Motor objetivo:** PostgreSQL 18 en Ubuntu Server 24.04 LTS (correo institucional). Verificación original realizada en **PostgreSQL 16.13**. Verificación adicional realizada el **23/09/2026 en PostgreSQL 18.6 sobre Windows**: creación completa de `01_schema.sql` y suite formal `03_pruebas.sql` con **43/43 PASS**. La prueba de concurrencia real con dos sesiones conserva como evidencia la ejecución original en PostgreSQL 16.13.

## 1. Creación (una sola vez por entorno)

```bash
# como usuario del SO postgres (o superusuario de la instancia)
createuser --pwprompt papeleria_app          # usuario de la aplicación, sin superusuario
createdb -O papeleria_app foso_papeleria     # base institucional
psql -d foso_papeleria -v ON_ERROR_STOP=1 -f 01_schema.sql
```

Notas:
- `01_schema.sql` es transaccional (BEGIN/COMMIT): o crea todo o no crea nada. Ejecutarlo dos veces falla en el `CREATE TABLE` inicial — está pensado para base vacía; para reinstalar, `dropdb`/`createdb` primero.
- No inserta ningún dato: los catálogos reales (roles, permisos, unidades organizativas, unidades de medida, tipos de movimiento, proveedores) **los define FOSOFAMILIA** — ver matriz de decisiones.
- Credenciales: gestionarlas con las prácticas de la institución; nunca en el repositorio ni en scripts.

## 2. Inicialización (cuando FOSOFAMILIA entregue los catálogos)

Orden de carga (respeta las FKs):
1. `rol`, `permiso`, `rol_permiso`, `unidad_organizativa`, `usuario` (con hash de contraseña generado por la aplicación, nunca texto plano).
2. `unidad_medida` ← **bloqueante actual**: sin este catálogo no pueden cargarse artículos.
3. `especifico` (54105/54114/54115 según el Excel; alcance por confirmar) y `articulo` (61 códigos de la hoja INVENTARIO, cols. B/C, normalizando espacios de borde).
4. `tipo_movimiento` (catálogo definitivo por confirmar; debe incluir el tipo de *ajuste de entrada — carga inicial*).
5. `proveedor` (cuando existan datos reales).
6. **Carga inicial de existencias**: UN movimiento de ajuste de entrada a la fecha de corte con una línea por artículo con existencia > 0 (`cantidad` = col. H, `costo_unitario` = col. I del libro) e inicializar `articulo.costo_promedio_actual` con la col. I. **Nunca** editar `existencia_actual` a mano. Detalle completo y alternativa con histórico: `FOSO_Integridad_y_Migracion_v0_4.md` §3.

## 3. Verificación posterior a la carga

```sql
SET search_path TO papeleria;
-- a) Conciliación: debe devolver 0 filas
SELECT * FROM vw_existencias_calculadas WHERE diferencia <> 0;
-- b) Totales contra el libro (corte 31/08/2026): 2641 / 1351 / 42, total 4034
SELECT e.codigo, SUM(a.existencia_actual) FROM articulo a JOIN especifico e USING (id_especifico) GROUP BY ROLLUP (e.codigo);
-- c) Valoración por línea contra la col. K del libro (≈ 3992.36 / 901.66 / 22.03)
SELECT e.codigo, SUM(ROUND(a.existencia_actual*a.costo_promedio_actual,2))
FROM articulo a JOIN especifico e USING (id_especifico) GROUP BY e.codigo;
-- d) Vistas de reportes responden
SELECT count(*) FROM vw_reporte_inventario;
```

## 4. Verificación de consistencia DER ↔ esquema (opcional, tras cualquier cambio)

```bash
psql -d foso_papeleria -Atc "SELECT table_name||'|'||column_name||'|'||CASE WHEN data_type='character varying' THEN 'varchar' WHEN data_type='timestamp with time zone' THEN 'timestamptz' WHEN data_type='character' THEN 'char' ELSE data_type END FROM information_schema.columns WHERE table_schema='papeleria' AND table_name NOT LIKE 'vw\\_%' ORDER BY table_name, ordinal_position" > cols_sql.txt
psql -d foso_papeleria -Atc "SELECT tc.table_name||'|'||tc.constraint_type||'|'||string_agg(kcu.column_name,',' ORDER BY kcu.ordinal_position) FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage kcu ON kcu.constraint_name=tc.constraint_name AND kcu.table_schema=tc.table_schema WHERE tc.table_schema='papeleria' AND tc.constraint_type IN ('PRIMARY KEY','FOREIGN KEY','UNIQUE') GROUP BY tc.table_name,tc.constraint_type,tc.constraint_name ORDER BY 1" > keys_sql.txt
python3 verifica_der_vs_sql.py   # requiere FOSO_DER_v0_4.mmd en el directorio
```
Resultado esperado: `OK: DER y esquema coinciden…` (así se obtuvo el 22/09/2026).

## 5. Pruebas (solo en base aislada)

```bash
createdb foso_test
psql -d foso_test -v ON_ERROR_STOP=1 -f 01_schema.sql
psql -d foso_test -f 03_pruebas.sql        # esperado: fail = 0
dropdb foso_test                            # los datos PRB son ficticios y desechables
```
Concurrencia (manual, 2 terminales): sección Z de `03_pruebas.sql`. **Jamás ejecutar `03_pruebas.sql` sobre la base institucional.**

## 6. Pendiente para el despliegue institucional
- Repetir los pasos 1–5 en el **servidor objetivo Ubuntu Server 24.04 LTS** antes del despliegue productivo. La compatibilidad funcional ya fue verificada en PostgreSQL 18.6 sobre Windows, pero el entorno final de servidor (Ubuntu + configuración productiva) todavía debe validarse.
- Política de respaldos y de acceso (roles de BD de la aplicación vs. administración) — a definir con FOSOFAMILIA en la fase de implementación.
