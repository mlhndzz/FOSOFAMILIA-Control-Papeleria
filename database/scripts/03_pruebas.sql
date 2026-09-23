-- ============================================================================
-- 03_pruebas.sql — Suite formal de pruebas de la base de datos (v0.4)
-- Sistema de Control de Papelería y Útiles — FOSOFAMILIA · 22/09/2026
--
-- USO:  psql -d <BASE_DE_PRUEBAS_VACIA_CON_01_SCHEMA> -f 03_pruebas.sql
--
-- REGLAS:
--  * Ejecutar EXCLUSIVAMENTE sobre una base de datos AISLADA de pruebas en la
--    que ya se cargó 01_schema.sql. Nunca sobre una base institucional.
--  * Todos los datos aquí insertados son FICTICIOS (prefijo DEMO/PRB) y no
--    representan información de FOSOFAMILIA.
--  * Las pruebas negativas se ejecutan dentro de bloques con captura de
--    excepción: un fallo esperado NO detiene la suite y NO deja residuos
--    (el bloque revierte sus efectos).
--  * La CONCURRENCIA real (dos sesiones simultáneas) no puede probarse desde
--    un único script: ver el procedimiento manual al final (sección Z), que
--    fue ejecutado y documentado aparte.
--  * Reglas institucionales pendientes (costo promedio, estados, parciales)
--    NO se prueban porque no están implementadas: ver matriz de decisiones.
--
-- RESULTADO: tabla papeleria._prb_resultados y resumen final PASS/FAIL.
-- ============================================================================

SET search_path TO papeleria;

-- ---------------------------------------------------------------------------
-- Arnés de pruebas
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS _prb_resultados;
CREATE TABLE _prb_resultados (
    orden     serial PRIMARY KEY,
    seccion   text NOT NULL,
    prueba    text NOT NULL,
    esperado  text NOT NULL,
    obtenido  text NOT NULL,
    ok        boolean NOT NULL
);

CREATE OR REPLACE FUNCTION _prb_espera_ok(p_seccion text, p_prueba text, p_sql text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE p_sql;
    INSERT INTO _prb_resultados (seccion,prueba,esperado,obtenido,ok)
    VALUES (p_seccion, p_prueba, 'ejecuta sin error', 'sin error', true);
EXCEPTION WHEN others THEN
    INSERT INTO _prb_resultados (seccion,prueba,esperado,obtenido,ok)
    VALUES (p_seccion, p_prueba, 'ejecuta sin error', 'ERROR: '||SQLERRM, false);
END $$;

CREATE OR REPLACE FUNCTION _prb_espera_error(p_seccion text, p_prueba text, p_sql text, p_fragmento text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE p_sql;
    INSERT INTO _prb_resultados (seccion,prueba,esperado,obtenido,ok)
    VALUES (p_seccion, p_prueba, 'ERROR con «'||p_fragmento||'»', 'no dio error', false);
EXCEPTION WHEN others THEN
    INSERT INTO _prb_resultados (seccion,prueba,esperado,obtenido,ok)
    VALUES (p_seccion, p_prueba, 'ERROR con «'||p_fragmento||'»',
            left(SQLERRM,120), position(lower(p_fragmento) in lower(SQLERRM)) > 0);
END $$;

CREATE OR REPLACE FUNCTION _prb_espera_valor(p_seccion text, p_prueba text, p_sql text, p_esperado numeric)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v numeric;
BEGIN
    EXECUTE p_sql INTO v;
    INSERT INTO _prb_resultados (seccion,prueba,esperado,obtenido,ok)
    VALUES (p_seccion, p_prueba, p_esperado::text, COALESCE(v::text,'NULL'), v = p_esperado);
EXCEPTION WHEN others THEN
    INSERT INTO _prb_resultados (seccion,prueba,esperado,obtenido,ok)
    VALUES (p_seccion, p_prueba, p_esperado::text, 'ERROR: '||SQLERRM, false);
END $$;

-- ---------------------------------------------------------------------------
-- SECCIÓN A — Datos ficticios de la base de pruebas
-- (catálogos mínimos; los reales están pendientes de FOSOFAMILIA)
-- ---------------------------------------------------------------------------
INSERT INTO rol (nombre) VALUES ('PRB_ROL');
INSERT INTO unidad_medida (abreviatura,nombre) VALUES ('prb','PRB_UNIDAD');
INSERT INTO especifico (codigo,nombre) VALUES ('PRB99','PRB LINEA DEMO');
INSERT INTO unidad_organizativa (nombre) VALUES ('PRB_UNIDAD_ORG');
INSERT INTO usuario (nombre_usuario,nombre_completo,hash_contrasena,id_rol)
SELECT 'prb_demo','Usuario Prueba','$hash$demo', id_rol FROM rol WHERE nombre='PRB_ROL';
INSERT INTO proveedor (nombre) VALUES ('PRB PROVEEDOR DEMO');
INSERT INTO tipo_movimiento (codigo,nombre,naturaleza) VALUES
  ('PRB-E','PRB AJUSTE ENTRADA','E'),
  ('PRB-S','PRB SALIDA','S'),
  ('PRB-OB','PRB SALIDA OBSOLESCENCIA (DEMO)','S');  -- demuestra que obsolescencia entra por el catálogo
INSERT INTO articulo (codigo,descripcion,id_especifico,id_unidad_medida)
SELECT 'PRB-ART-1','PRB ARTICULO UNO', e.id_especifico, u.id_unidad_medida
FROM especifico e, unidad_medida u WHERE e.codigo='PRB99' AND u.abreviatura='prb';
INSERT INTO articulo (codigo,descripcion,id_especifico,id_unidad_medida)
SELECT 'PRB-ART-2','PRB ARTICULO DOS', e.id_especifico, u.id_unidad_medida
FROM especifico e, unidad_medida u WHERE e.codigo='PRB99' AND u.abreviatura='prb';
INSERT INTO articulo (codigo,descripcion,id_especifico,id_unidad_medida)
SELECT 'PRB-ART-3','PRB ARTICULO TRES (escenario correccion)', e.id_especifico, u.id_unidad_medida
FROM especifico e, unidad_medida u WHERE e.codigo='PRB99' AND u.abreviatura='prb';

-- ids en tabla auxiliar para el resto de la suite
DROP TABLE IF EXISTS _prb_ids;
CREATE TABLE _prb_ids AS
SELECT (SELECT id_articulo FROM articulo WHERE codigo='PRB-ART-1')          AS art1,
       (SELECT id_articulo FROM articulo WHERE codigo='PRB-ART-2')          AS art2,
       (SELECT id_articulo FROM articulo WHERE codigo='PRB-ART-3')          AS art3,
       (SELECT id_tipo_movimiento FROM tipo_movimiento WHERE codigo='PRB-E') AS tipo_e,
       (SELECT id_tipo_movimiento FROM tipo_movimiento WHERE codigo='PRB-S') AS tipo_s,
       (SELECT id_tipo_movimiento FROM tipo_movimiento WHERE codigo='PRB-OB')AS tipo_ob,
       (SELECT id_usuario FROM usuario WHERE nombre_usuario='prb_demo')      AS usr,
       (SELECT id_proveedor FROM proveedor WHERE nombre='PRB PROVEEDOR DEMO')AS prov,
       (SELECT id_unidad_organizativa FROM unidad_organizativa WHERE nombre='PRB_UNIDAD_ORG') AS uorg,
       NULL::bigint  AS mov_entrada,
       NULL::bigint  AS mov_e3,
       NULL::integer AS req1,
       NULL::bigint  AS mov_desp;

-- ---------------------------------------------------------------------------
-- SECCIÓN B — Positivas: entrada, compra, saldo por trigger, conciliación
-- ---------------------------------------------------------------------------
DO $$
DECLARE i record; v_mov bigint;
BEGIN
    SELECT * INTO i FROM _prb_ids;
    INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra)
    VALUES (i.tipo_e,'B-0001','2026-01-01',i.usr) RETURNING id_movimiento INTO v_mov;
    INSERT INTO movimiento_detalle VALUES (v_mov,1,i.art1,100,0.50);
    INSERT INTO movimiento_detalle VALUES (v_mov,2,i.art1,50,0.50);   -- mismo articulo, 2 lineas: valido
    INSERT INTO compra (id_movimiento,id_proveedor,numero_factura) VALUES (v_mov,i.prov,'PRB-FAC-1');
    UPDATE _prb_ids SET mov_entrada = v_mov;
    -- stock para art2 (evita que la validacion de despacho quede enmascarada por el CHECK de stock)
    INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra)
    VALUES (i.tipo_e,'B-0002','2026-01-01',i.usr) RETURNING id_movimiento INTO v_mov;
    INSERT INTO movimiento_detalle VALUES (v_mov,1,i.art2,50,0.10);
    -- escenario del punto 2 de la auditoria sobre art3: entrada 10, salida 8 -> saldo 2
    INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra)
    VALUES (i.tipo_e,'B-0003','2026-01-01',i.usr) RETURNING id_movimiento INTO v_mov;
    INSERT INTO movimiento_detalle VALUES (v_mov,1,i.art3,10,0.50);
    UPDATE _prb_ids SET mov_e3 = v_mov;
    INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra)
    VALUES (i.tipo_s,'B-0004','2026-01-02',i.usr) RETURNING id_movimiento INTO v_mov;
    INSERT INTO movimiento_detalle VALUES (v_mov,1,i.art3,8,0.50);
END $$;
SELECT _prb_espera_valor('B','B1 saldo tras entrada 100+50 (dos lineas, mismo articulo)',
  'SELECT existencia_actual FROM articulo a JOIN _prb_ids i ON a.id_articulo=i.art1', 150);
SELECT _prb_espera_valor('B','B2 conciliacion en cero tras entrada',
  'SELECT diferencia FROM vw_existencias_calculadas v JOIN _prb_ids i ON v.id_articulo=i.art1', 0);
SELECT _prb_espera_valor('B','B3 compra visible en vw_reporte_compras (2 lineas)',
  'SELECT count(*)::numeric FROM vw_reporte_compras WHERE numero_factura=''PRB-FAC-1''', 2);

-- ---------------------------------------------------------------------------
-- SECCIÓN C — Negativas: coherencia tipo/naturaleza, compra, requisición
-- ---------------------------------------------------------------------------
SELECT _prb_espera_error('C','C1 compra sobre movimiento de salida',
 $q$ WITH m AS (INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra)
      SELECT tipo_s,'C-0001','2026-01-02',usr FROM _prb_ids RETURNING id_movimiento)
     INSERT INTO compra (id_movimiento,id_proveedor,numero_factura)
     SELECT m.id_movimiento, i.prov, 'PRB-FAC-C1' FROM m, _prb_ids i $q$,
 'movimiento de entrada');
SELECT _prb_espera_error('C','C2 misma factura del mismo proveedor en OTRA entrada',
 $q$ WITH m AS (INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra)
      SELECT tipo_e,'C-0002','2026-01-02',usr FROM _prb_ids RETURNING id_movimiento)
     INSERT INTO compra (id_movimiento,id_proveedor,numero_factura)
     SELECT m.id_movimiento, i.prov, 'PRB-FAC-1' FROM m, _prb_ids i $q$,
 'ux_compra_factura');
SELECT _prb_espera_error('C','C3 segunda fila de compra para el mismo movimiento',
 $q$ INSERT INTO compra (id_movimiento,id_proveedor,numero_factura)
     SELECT mov_entrada, prov, 'PRB-FAC-OTRA' FROM _prb_ids $q$,
 'compra_pkey');
SELECT _prb_espera_error('C','C4 requisicion vinculada a un tipo de entrada',
 $q$ WITH r AS (INSERT INTO requisicion (numero,id_unidad_organizativa,id_usuario_solicita,fecha_solicitud,estado)
      SELECT 'PRB-RQ-C4', uorg, usr, '2026-01-03','PRB' FROM _prb_ids RETURNING id_requisicion)
     INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra,id_requisicion)
     SELECT i.tipo_e,'C-0004','2026-01-03',i.usr,r.id_requisicion FROM r, _prb_ids i $q$,
 'entrada no puede vincularse');
SELECT _prb_espera_error('C','C5 cambiar naturaleza de un tipo en uso',
 $q$ UPDATE tipo_movimiento tm SET naturaleza='S' FROM _prb_ids i WHERE tm.id_tipo_movimiento=i.tipo_e $q$,
 'no puede cambiar');
SELECT _prb_espera_ok('C','C6 cambiar naturaleza de un tipo SIN uso',
 $q$ UPDATE tipo_movimiento SET naturaleza='E' WHERE codigo='PRB-OB' AND NOT EXISTS
     (SELECT 1 FROM movimiento m WHERE m.id_tipo_movimiento=tipo_movimiento.id_tipo_movimiento);
     UPDATE tipo_movimiento SET naturaleza='S' WHERE codigo='PRB-OB' $q$);
SELECT _prb_espera_error('C','C7 cambiar tipo de un movimiento con lineas/compra',
 $q$ UPDATE movimiento m SET id_tipo_movimiento=i.tipo_s FROM _prb_ids i WHERE m.id_movimiento=i.mov_entrada $q$,
 'no se permite cambiar');
SELECT _prb_espera_error('C','C8 comprobante duplicado en el mismo tipo',
 $q$ INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra)
     SELECT tipo_e,'B-0001','2026-01-04',usr FROM _prb_ids $q$,
 'ux_movimiento_comprobante');
SELECT _prb_espera_ok('C','C9 mismo numero de comprobante en OTRO tipo (correlativo por tipo [P])',
 $q$ INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra)
     SELECT tipo_ob,'B-0001','2026-01-04',usr FROM _prb_ids $q$);
SELECT _prb_espera_error('C','C10 cantidad negativa en detalle',
 $q$ INSERT INTO movimiento_detalle SELECT mov_entrada, 90, art1, -5, 0.5 FROM _prb_ids $q$,
 'cantidad');
SELECT _prb_espera_error('C','C11 codigo de articulo con espacios de borde',
 $q$ INSERT INTO articulo (codigo,descripcion,id_especifico,id_unidad_medida)
     SELECT 'PRB-MAL ','X', a.id_especifico, a.id_unidad_medida FROM articulo a LIMIT 1 $q$,
 'ck_articulo_codigo_formato');

-- ---------------------------------------------------------------------------
-- SECCIÓN D — Requisición y despacho (reglas confirmadas + provisionales [P])
-- ---------------------------------------------------------------------------
DO $$
DECLARE i record; v_req integer; v_desp bigint;
BEGIN
    SELECT * INTO i FROM _prb_ids;
    INSERT INTO requisicion (numero,id_unidad_organizativa,id_usuario_solicita,fecha_solicitud,estado)
    VALUES ('PRB-RQ-1', i.uorg, i.usr, '2026-01-05','PRB') RETURNING id_requisicion INTO v_req;
    INSERT INTO requisicion_detalle VALUES (v_req,1,i.art1,15,12);
    INSERT INTO requisicion_detalle VALUES (v_req,2,i.art1,10,8);   -- mismo articulo en 2 lineas: autorizado total 20
    INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra,id_requisicion)
    VALUES (i.tipo_s,'D-0001','2026-01-06',i.usr,v_req) RETURNING id_movimiento INTO v_desp;
    UPDATE _prb_ids SET req1=v_req, mov_desp=v_desp;
END $$;
SELECT _prb_espera_error('D','D1 despachar articulo no incluido en la requisicion',
 $q$ INSERT INTO movimiento_detalle SELECT mov_desp,1,art2,1,0.10 FROM _prb_ids $q$,
 'no está en la requisición');
SELECT _prb_espera_ok('D','D2 despacho valido de 10 (autorizado 20, stock 150)',
 $q$ INSERT INTO movimiento_detalle SELECT mov_desp,2,art1,10,0.50 FROM _prb_ids $q$);
SELECT _prb_espera_valor('D','D3 saldo tras despacho',
 'SELECT existencia_actual FROM articulo a JOIN _prb_ids i ON a.id_articulo=i.art1', 140);
SELECT _prb_espera_error('D','D4 linea adicional que excede lo autorizado (10+15>20)',
 $q$ INSERT INTO movimiento_detalle SELECT mov_desp,3,art1,15,0.50 FROM _prb_ids $q$,
 'excede lo autorizado');
SELECT _prb_espera_error('D','D5 [P] segundo despacho de la misma requisicion (despacho unico provisional)',
 $q$ INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra,id_requisicion)
     SELECT tipo_s,'D-0002','2026-01-07',usr,req1 FROM _prb_ids $q$,
 'ux_movimiento_despacho_unico');
SELECT _prb_espera_error('D','D6 salida libre mayor que el stock',
 $q$ WITH m AS (INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra)
      SELECT tipo_s,'D-0003','2026-01-08',usr FROM _prb_ids RETURNING id_movimiento)
     INSERT INTO movimiento_detalle SELECT m.id_movimiento,1,i.art1,999,0.5 FROM m,_prb_ids i $q$,
 'existencia_actual_check');
SELECT _prb_espera_ok('D','D7 salida por obsolescencia via catalogo de tipos (naturaleza S)',
 $q$ WITH m AS (INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra)
      SELECT tipo_ob,'D-0004','2026-01-09',usr FROM _prb_ids RETURNING id_movimiento)
     INSERT INTO movimiento_detalle SELECT m.id_movimiento,1,i.art1,5,0.5 FROM m,_prb_ids i $q$);
SELECT _prb_espera_valor('D','D8 saldo tras obsolescencia de 5',
 'SELECT existencia_actual FROM articulo a JOIN _prb_ids i ON a.id_articulo=i.art1', 135);

-- ---------------------------------------------------------------------------
-- SECCIÓN E — Correcciones (delta neto) y borrados con reversión de saldo
-- ---------------------------------------------------------------------------
SELECT _prb_espera_ok('E','E1 correccion de la entrada 100->99 con salidas ya registradas (delta neto)',
 $q$ UPDATE movimiento_detalle md SET cantidad=99 FROM _prb_ids i
     WHERE md.id_movimiento=i.mov_entrada AND md.numero_linea=1 $q$);
SELECT _prb_espera_valor('E','E2 saldo tras correccion (135-1)',
 'SELECT existencia_actual FROM articulo a JOIN _prb_ids i ON a.id_articulo=i.art1', 134);
SELECT _prb_espera_ok('E','E3a escenario auditoria: corregir entrada de art3 de 10 a 9 (saldo 2, salida 8)',
 $q$ UPDATE movimiento_detalle md SET cantidad=9 FROM _prb_ids i
     WHERE md.id_movimiento=i.mov_e3 AND md.numero_linea=1 $q$);
SELECT _prb_espera_valor('E','E3b saldo final del escenario = 1 (delta neto, sin negativo transitorio)',
 'SELECT existencia_actual FROM articulo a JOIN _prb_ids i ON a.id_articulo=i.art3', 1);
SELECT _prb_espera_error('E','E3c correccion que SI dejaria saldo negativo (9 a 7)',
 $q$ UPDATE movimiento_detalle md SET cantidad=7 FROM _prb_ids i
     WHERE md.id_movimiento=i.mov_e3 AND md.numero_linea=1 $q$,
 'existencia_actual_check');
SELECT _prb_espera_valor('E','E3d el rechazo no altero el saldo de art3',
 'SELECT existencia_actual FROM articulo a JOIN _prb_ids i ON a.id_articulo=i.art3', 1);
SELECT _prb_espera_ok('E','E4 borrar una LINEA de la obsolescencia (revierte 5)',
 $q$ DELETE FROM movimiento_detalle md USING movimiento m, _prb_ids i
     WHERE md.id_movimiento=m.id_movimiento AND m.numero_comprobante='D-0004'
       AND m.id_tipo_movimiento=i.tipo_ob $q$);
SELECT _prb_espera_valor('E','E5 saldo tras revertir la linea',
 'SELECT existencia_actual FROM articulo a JOIN _prb_ids i ON a.id_articulo=i.art1', 139);
SELECT _prb_espera_error('E','E6 borrar el ENCABEZADO de la entrada con stock ya consumido',
 $q$ DELETE FROM movimiento m USING _prb_ids i WHERE m.id_movimiento=i.mov_entrada $q$,
 'existencia_actual_check');
SELECT _prb_espera_valor('E','E7 el rechazo no dejo efectos residuales',
 'SELECT existencia_actual FROM articulo a JOIN _prb_ids i ON a.id_articulo=i.art1', 139);

-- ---------------------------------------------------------------------------
-- SECCIÓN F — Protección de lo ya despachado (líneas de requisición)
-- ---------------------------------------------------------------------------
SELECT _prb_espera_error('F','F1 reducir cantidad_aprobada por debajo de lo despachado',
 $q$ UPDATE requisicion_detalle rd SET cantidad_aprobada=1 FROM _prb_ids i
     WHERE rd.id_requisicion=i.req1 AND rd.numero_linea=1 $q$,
 'quedaría en');
SELECT _prb_espera_ok('F','F2 reducir dentro del margen (12->4; autorizado 4+8=12 >= 10)',
 $q$ UPDATE requisicion_detalle rd SET cantidad_aprobada=4 FROM _prb_ids i
     WHERE rd.id_requisicion=i.req1 AND rd.numero_linea=1 $q$);
SELECT _prb_espera_error('F','F3 borrar la otra linea del articulo despachado',
 $q$ DELETE FROM requisicion_detalle rd USING _prb_ids i
     WHERE rd.id_requisicion=i.req1 AND rd.numero_linea=2 $q$,
 'quedaría en');
SELECT _prb_espera_error('F','F4 borrar la requisicion con despacho registrado',
 $q$ DELETE FROM requisicion r USING _prb_ids i WHERE r.id_requisicion=i.req1 $q$,
 'movimiento_id_requisicion_fkey');
SELECT _prb_espera_ok('F','F5 una requisicion sin despachos si se borra (cascada de lineas)',
 $q$ WITH r AS (INSERT INTO requisicion (numero,id_unidad_organizativa,id_usuario_solicita,fecha_solicitud,estado)
      SELECT 'PRB-RQ-F5', uorg, usr, '2026-01-10','PRB' FROM _prb_ids RETURNING id_requisicion),
      d AS (INSERT INTO requisicion_detalle SELECT r.id_requisicion,1,i.art1,5,NULL FROM r,_prb_ids i RETURNING id_requisicion)
     DELETE FROM requisicion WHERE id_requisicion IN (SELECT id_requisicion FROM d) $q$);

-- ---------------------------------------------------------------------------
-- SECCIÓN G — Transacciones: atomicidad de movimiento + detalle
-- (fuera del arnés: usa BEGIN/ROLLBACK reales de psql)
-- ---------------------------------------------------------------------------
BEGIN;
INSERT INTO movimiento (id_tipo_movimiento,numero_comprobante,fecha,id_usuario_registra)
SELECT tipo_e,'G-0001','2026-01-11',usr FROM _prb_ids;
INSERT INTO movimiento_detalle
SELECT m.id_movimiento,1,i.art1,1000,0.5 FROM movimiento m, _prb_ids i WHERE m.numero_comprobante='G-0001';
ROLLBACK;
SELECT _prb_espera_valor('G','G1 ROLLBACK revierte encabezado, detalle y saldo',
 'SELECT existencia_actual FROM articulo a JOIN _prb_ids i ON a.id_articulo=i.art1', 139);
SELECT _prb_espera_valor('G','G2 el movimiento revertido no existe',
 'SELECT count(*)::numeric FROM movimiento WHERE numero_comprobante=''G-0001''', 0);

-- ---------------------------------------------------------------------------
-- SECCIÓN H — Vistas de reportes y conciliación global
-- ---------------------------------------------------------------------------
SELECT _prb_espera_valor('H','H1 conciliacion global: ningun articulo con diferencia',
 'SELECT count(*)::numeric FROM vw_existencias_calculadas WHERE diferencia <> 0', 0);
SELECT _prb_espera_valor('H','H2 vw_reporte_inventario valora stock al costo vigente (139 x 0 = 0 aqui)',
 'SELECT costo_total FROM vw_reporte_inventario WHERE codigo_articulo=''PRB-ART-1''', 0);
SELECT _prb_espera_valor('H','H3 vw_reporte_salidas suma las salidas registradas (10 desp + 0 obsolescencia tras E4)',
 'SELECT COALESCE(SUM(cantidad),0) FROM vw_reporte_salidas WHERE codigo_articulo=''PRB-ART-1''', 10);
SELECT _prb_espera_valor('H','H4 vw_reporte_requisiciones muestra despachado por articulo',
 'SELECT DISTINCT cantidad_despachada FROM vw_reporte_requisiciones WHERE numero=''PRB-RQ-1''', 10);

-- ---------------------------------------------------------------------------
-- RESUMEN
-- ---------------------------------------------------------------------------
SELECT seccion, prueba, esperado, obtenido, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS estado
FROM _prb_resultados ORDER BY orden;

SELECT count(*) FILTER (WHERE ok)  AS pass,
       count(*) FILTER (WHERE NOT ok) AS fail,
       count(*) AS total
FROM _prb_resultados;

-- ---------------------------------------------------------------------------
-- SECCIÓN Z — CONCURRENCIA (procedimiento manual, requiere DOS sesiones psql)
-- Objetivo: dos salidas simultáneas del mismo artículo se serializan por el
-- bloqueo de fila del UPDATE del trigger de saldo; la segunda ve el saldo ya
-- descontado y el CHECK decide sobre el valor final.
--   Sesión A:                                Sesión B:
--   BEGIN;
--   INSERT movimiento salida SA;
--   INSERT detalle (art X, cantidad qA);     BEGIN;
--   SELECT pg_sleep(3);                      INSERT movimiento salida SB;
--                                            INSERT detalle (art X, qB);  -- se BLOQUEA
--   COMMIT;                                  -- se desbloquea:
--                                            --  * si qA+qB <= stock: COMMIT correcto
--                                            --  * si qA+qB  > stock: ERROR CHECK
-- Este procedimiento fue ejecutado realmente con dos clientes psql y sus
-- resultados están documentados en el informe de pruebas del paquete.
-- ---------------------------------------------------------------------------
