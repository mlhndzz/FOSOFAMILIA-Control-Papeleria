-- ============================================================================
-- 01_schema.sql — v0.4 (consolidado BD: tablas + integridad + vistas de reportes)
-- Sistema de Control de Papelería y Útiles — FOSOFAMILIA
-- Fecha: 22/09/2026
-- Motor objetivo: PostgreSQL 18 (última estable verificada: 18.6).
--   Verificado originalmente por ejecución completa y suite de pruebas en PostgreSQL 16.13.
--   Verificación adicional 23/09/2026: PostgreSQL 18.6 sobre Windows, esquema completo
--   + suite formal 03_pruebas.sql = 43/43 PASS. Concurrencia de dos sesiones: evidencia 16.13.
--
-- CAMBIOS v0.3 -> v0.4 (auditoría de normalización e integridad):
--   P1) Se ELIMINAN las columnas redundantes movimiento.naturaleza y
--       compra.naturaleza (violaban 3FN: naturaleza es atributo no primo
--       dependiente de id_tipo_movimiento, que no es superclave de movimiento).
--       La coherencia compra<->entrada y requisicion<->salida pasa a triggers,
--       cerrados con la inmutabilidad de tipo_movimiento.naturaleza en uso.
--   P2) fn_movdet_actualiza_saldo aplica DELTA NETO en UPDATE del mismo
--       artículo: corregir una entrada de 10 a 9 con saldo 2 deja 1, sin
--       negativo transitorio que disparara el CHECK indebidamente.
--   P3) Se retira ON DELETE CASCADE de movimiento_detalle; un BEFORE DELETE
--       en movimiento borra sus líneas (y su fila de compra) con el padre aún
--       visible, para que el trigger de saldo pueda leer la naturaleza.
--
-- ESTADO DEL SCRIPT:
--   1) ESTRUCTURA CREADA: 15 tablas, 5 vistas (1 de conciliación + 4 de
--      reportes del JPG bloque 6), claves, FKs, CHECKs, índices.
--   2) RESTRICCIONES IMPLEMENTADAS: unicidad de comprobante por tipo [P];
--      proveedor+factura únicos; despacho único [P]; despacho ⊆ requisición y
--      ≤ autorizado [P]; saldo transaccional con no-negatividad; coherencia
--      compra=entrada y requisición=salida (triggers); inmutabilidad de
--      naturaleza de tipos en uso y de movimientos con líneas.
--   3) REGLAS PENDIENTES: fórmula de costo promedio; CHECK de estados de
--      requisición; catálogo de tipos de movimiento; alcance del correlativo;
--      semántica de aprobación y despachos parciales; obligatoriedad real de
--      proveedor.
--   4) PROCESOS NO DESARROLLADOS: recálculo de costo, flujo de aprobación,
--      carga inicial (documentada aparte), aplicación C#. Los reportes ya
--      tienen sus vistas base; sus filtros y formato final son de la app.
--   NO es una base de datos operativa terminada. No inserta ningún dato.
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS papeleria;
SET search_path TO papeleria;

-- ---------------------------------------------------------------------------
-- 1. Seguridad (JPG bloques 1 y 7; correo req. 3)
-- ---------------------------------------------------------------------------

CREATE TABLE rol (
    id_rol       smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       varchar(60)  NOT NULL UNIQUE,
    descripcion  varchar(255),
    activo       boolean      NOT NULL DEFAULT true
);
COMMENT ON TABLE rol IS 'Roles del sistema (lista real POR CONFIRMAR)';

CREATE TABLE permiso (
    id_permiso   smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo       varchar(60)  NOT NULL UNIQUE,
    descripcion  varchar(255)
);

CREATE TABLE rol_permiso (
    id_rol      smallint NOT NULL REFERENCES rol,
    id_permiso  smallint NOT NULL REFERENCES permiso,
    PRIMARY KEY (id_rol, id_permiso)
);

CREATE TABLE unidad_organizativa (
    id_unidad_organizativa integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre  varchar(120) NOT NULL UNIQUE,
    activo  boolean      NOT NULL DEFAULT true
);

CREATE TABLE usuario (
    id_usuario             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_usuario         varchar(60)  NOT NULL UNIQUE,
    nombre_completo        varchar(120) NOT NULL,
    correo                 varchar(120),
    hash_contrasena        varchar(255) NOT NULL,
    id_rol                 smallint     NOT NULL REFERENCES rol,          -- [P] un solo rol
    id_unidad_organizativa integer      REFERENCES unidad_organizativa,  -- [P]
    activo                 boolean      NOT NULL DEFAULT true,
    fecha_creacion         timestamptz  NOT NULL DEFAULT now()
);
COMMENT ON COLUMN usuario.hash_contrasena IS 'Hash con sal; nunca texto plano';
CREATE UNIQUE INDEX ux_usuario_correo ON usuario (lower(correo)) WHERE correo IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. Catálogos de artículos (Excel: líneas 54105/54114/54115; JPG bloque 7)
-- ---------------------------------------------------------------------------

CREATE TABLE especifico (
    id_especifico integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo  varchar(10)  NOT NULL UNIQUE,
    nombre  varchar(120) NOT NULL,
    activo  boolean      NOT NULL DEFAULT true
);

CREATE TABLE unidad_medida (
    id_unidad_medida smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    abreviatura varchar(10) NOT NULL UNIQUE,
    nombre      varchar(60) NOT NULL UNIQUE
);
COMMENT ON TABLE unidad_medida IS 'Catálogo del JPG; el Excel no trae unidad por artículo (valores POR CONFIRMAR)';

CREATE TABLE articulo (
    id_articulo           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                varchar(30)  NOT NULL UNIQUE,
    descripcion           varchar(200) NOT NULL,
    id_especifico         integer      NOT NULL REFERENCES especifico,
    id_unidad_medida      smallint     NOT NULL REFERENCES unidad_medida, -- [P]
    existencia_actual     numeric(12,2) NOT NULL DEFAULT 0 CHECK (existencia_actual >= 0),
    costo_promedio_actual numeric(12,4) NOT NULL DEFAULT 0 CHECK (costo_promedio_actual >= 0),
    activo                boolean       NOT NULL DEFAULT true,
    CONSTRAINT ck_articulo_codigo_formato CHECK (codigo = btrim(codigo) AND codigo <> '')
);
COMMENT ON COLUMN articulo.existencia_actual IS
  'Saldo materializado por trg_movdet_saldo en la transacción del movimiento. Fuente de verdad: movimientos (Excel: H=E+F-G)';
COMMENT ON COLUMN articulo.costo_promedio_actual IS
  'Costo vigente (Excel col I). REGLA PENDIENTE: recálculo no implementado; el Excel evidencia (anterior+compra)/2, fórmula POR CONFIRMAR';
CREATE INDEX ix_articulo_especifico ON articulo (id_especifico);

-- ---------------------------------------------------------------------------
-- 3. Proveedores
-- ---------------------------------------------------------------------------

CREATE TABLE proveedor (
    id_proveedor    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          varchar(150) NOT NULL UNIQUE,
    registro_fiscal varchar(30),   -- [P]
    activo          boolean NOT NULL DEFAULT true
);

-- ---------------------------------------------------------------------------
-- 4. Movimientos de inventario
--    v0.4: la naturaleza vive SOLO en tipo_movimiento (3FN). La coherencia se
--    valida con triggers (sección 5), no con columnas redundantes.
-- ---------------------------------------------------------------------------

CREATE TABLE tipo_movimiento (
    id_tipo_movimiento smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo     varchar(10) NOT NULL UNIQUE,
    nombre     varchar(80) NOT NULL,
    naturaleza char(1)     NOT NULL CHECK (naturaleza IN ('E','S'))  -- E suma, S resta
);
COMMENT ON TABLE tipo_movimiento IS
  'Comportamientos evidenciados: compra, salida por requisición, ajustes ±, obsolescencia. REGLA PENDIENTE: catálogo definitivo y significado de SM/S5 (no se insertan filas). Su naturaleza es inmutable mientras existan movimientos del tipo (trigger)';

CREATE TABLE requisicion (
    id_requisicion         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero                 varchar(20) NOT NULL UNIQUE,
    id_unidad_organizativa integer NOT NULL REFERENCES unidad_organizativa,
    id_usuario_solicita    integer NOT NULL REFERENCES usuario,
    fecha_solicitud        date    NOT NULL,
    estado                 varchar(20) NOT NULL,
    id_usuario_revisa      integer REFERENCES usuario,
    fecha_revision         timestamptz,
    observacion            varchar(255)
);
COMMENT ON COLUMN requisicion.estado IS
  'REGLA PENDIENTE: lista de estados POR CONFIRMAR; CHECK diferido hasta confirmarse';
CREATE INDEX ix_requisicion_unidad ON requisicion (id_unidad_organizativa);
CREATE INDEX ix_requisicion_fecha  ON requisicion (fecha_solicitud);

CREATE TABLE requisicion_detalle (
    id_requisicion      integer  NOT NULL REFERENCES requisicion ON DELETE CASCADE,
    numero_linea        smallint NOT NULL CHECK (numero_linea > 0),
    id_articulo         integer  NOT NULL REFERENCES articulo,
    cantidad_solicitada numeric(12,2) NOT NULL CHECK (cantidad_solicitada > 0),
    cantidad_aprobada   numeric(12,2) CHECK (cantidad_aprobada >= 0),  -- [P]
    PRIMARY KEY (id_requisicion, numero_linea)
);
CREATE INDEX ix_reqdet_articulo ON requisicion_detalle (id_articulo);

CREATE TABLE movimiento (
    id_movimiento       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_tipo_movimiento  smallint NOT NULL REFERENCES tipo_movimiento,
    numero_comprobante  varchar(20) NOT NULL,
    fecha               date NOT NULL,
    id_usuario_registra integer NOT NULL REFERENCES usuario,
    id_requisicion      integer REFERENCES requisicion,
    observacion         varchar(255),
    fecha_registro      timestamptz NOT NULL DEFAULT now(),
    -- [P] correlativo por tipo (opción menos restrictiva)
    CONSTRAINT ux_movimiento_comprobante UNIQUE (id_tipo_movimiento, numero_comprobante)
);
CREATE INDEX ix_movimiento_fecha ON movimiento (fecha);
-- [P] despacho único provisional (sin confirmación sobre parciales):
CREATE UNIQUE INDEX ux_movimiento_despacho_unico
    ON movimiento (id_requisicion) WHERE id_requisicion IS NOT NULL;

CREATE TABLE movimiento_detalle (
    id_movimiento  bigint   NOT NULL REFERENCES movimiento,  -- SIN cascade: ver trg_movimiento_borra_hijos (P3)
    numero_linea   smallint NOT NULL CHECK (numero_linea > 0),
    id_articulo    integer  NOT NULL REFERENCES articulo,
    cantidad       numeric(12,2) NOT NULL CHECK (cantidad > 0),
    costo_unitario numeric(12,4) NOT NULL CHECK (costo_unitario >= 0),
    PRIMARY KEY (id_movimiento, numero_linea)
);
COMMENT ON COLUMN movimiento_detalle.costo_unitario IS
  'Costo histórico congelado (evidencia: VLOOKUP del Excel; nota RESUMEN 44-47)';
CREATE INDEX ix_movdet_articulo ON movimiento_detalle (id_articulo);

CREATE TABLE compra (
    id_movimiento  bigint PRIMARY KEY REFERENCES movimiento,  -- subtipo 1:1
    id_proveedor   integer NOT NULL REFERENCES proveedor,     -- [P]
    numero_factura varchar(50) NOT NULL,
    CONSTRAINT ux_compra_factura UNIQUE (id_proveedor, numero_factura)
);
COMMENT ON TABLE compra IS
  'Subtipo de movimiento para entradas por compra. PK=FK impide duplicar la fila del mismo movimiento; trg_compra_solo_entrada garantiza que el movimiento sea de entrada; UNIQUE (proveedor, factura) impide re-registrar la misma factura (definición completa de compra lógica PENDIENTE)';

-- ---------------------------------------------------------------------------
-- 5. Funciones y triggers de integridad
-- ---------------------------------------------------------------------------

-- Naturaleza de un movimiento, vía su tipo (única fuente de la naturaleza, 3FN):
CREATE FUNCTION fn_naturaleza_movimiento(p_id_movimiento bigint) RETURNS char(1)
LANGUAGE sql STABLE AS $$
    SELECT tm.naturaleza
    FROM movimiento m
    JOIN tipo_movimiento tm ON tm.id_tipo_movimiento = m.id_tipo_movimiento
    WHERE m.id_movimiento = p_id_movimiento
$$;

-- (P1) La naturaleza de un tipo en uso es inmutable: cierra el hueco que las
-- FK compuestas cubrían en v0.3, ahora sin columna redundante.
CREATE FUNCTION fn_tipomov_naturaleza_inmutable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.naturaleza <> OLD.naturaleza
       AND EXISTS (SELECT 1 FROM movimiento m WHERE m.id_tipo_movimiento = OLD.id_tipo_movimiento) THEN
        RAISE EXCEPTION 'El tipo de movimiento % ya tiene movimientos registrados: su naturaleza no puede cambiar', OLD.codigo;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_tipomov_naturaleza_inmutable
BEFORE UPDATE OF naturaleza ON tipo_movimiento
FOR EACH ROW EXECUTE FUNCTION fn_tipomov_naturaleza_inmutable();

-- (P1) Una requisición solo puede vincularse a movimientos de SALIDA
-- (flujo del JPG: la requisición desemboca en despacho/salida):
CREATE FUNCTION fn_movimiento_valida_requisicion() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_nat char(1);
BEGIN
    IF NEW.id_requisicion IS NOT NULL THEN
        SELECT naturaleza INTO v_nat FROM tipo_movimiento WHERE id_tipo_movimiento = NEW.id_tipo_movimiento;
        IF v_nat <> 'S' THEN
            RAISE EXCEPTION 'Un movimiento de entrada no puede vincularse a una requisición (movimiento tipo %, requisición %)',
                NEW.id_tipo_movimiento, NEW.id_requisicion;
        END IF;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_movimiento_valida_requisicion
BEFORE INSERT OR UPDATE OF id_requisicion, id_tipo_movimiento ON movimiento
FOR EACH ROW EXECUTE FUNCTION fn_movimiento_valida_requisicion();

-- (P1) Una compra solo puede extender un movimiento de ENTRADA:
CREATE FUNCTION fn_compra_solo_entrada() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF fn_naturaleza_movimiento(NEW.id_movimiento) <> 'E' THEN
        RAISE EXCEPTION 'Una compra solo puede asociarse a un movimiento de entrada (movimiento %)', NEW.id_movimiento;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_compra_solo_entrada
BEFORE INSERT OR UPDATE OF id_movimiento ON compra
FOR EACH ROW EXECUTE FUNCTION fn_compra_solo_entrada();

-- Un movimiento con líneas o con fila de compra no cambia de tipo ni de
-- requisición (las correcciones se hacen con movimientos de ajuste):
CREATE FUNCTION fn_movimiento_bloquea_cambios() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF (NEW.id_tipo_movimiento <> OLD.id_tipo_movimiento
        OR NEW.id_requisicion IS DISTINCT FROM OLD.id_requisicion)
       AND (EXISTS (SELECT 1 FROM movimiento_detalle d WHERE d.id_movimiento = OLD.id_movimiento)
            OR EXISTS (SELECT 1 FROM compra c WHERE c.id_movimiento = OLD.id_movimiento)) THEN
        RAISE EXCEPTION 'El movimiento % ya tiene líneas o compra asociada: no se permite cambiar su tipo o requisición', OLD.id_movimiento;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_movimiento_bloquea_cambios
BEFORE UPDATE OF id_tipo_movimiento, id_requisicion ON movimiento
FOR EACH ROW EXECUTE FUNCTION fn_movimiento_bloquea_cambios();

-- (P2) Mantenimiento del saldo con DELTA NETO en UPDATE:
--   corregir una entrada de 10 a 9 aplica -1 en una sola actualización, sin
--   pasar por el estado intermedio negativo que rechazaba el CHECK en v0.3.
--   Si el UPDATE cambia el artículo de la línea, sí se revierte en el viejo y
--   se aplica en el nuevo (dos filas distintas; cada una debe quedar >= 0).
CREATE FUNCTION fn_movdet_actualiza_saldo() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_efecto_old numeric := 0;
    v_efecto_new numeric := 0;
BEGIN
    IF TG_OP IN ('UPDATE','DELETE') THEN
        v_efecto_old := CASE fn_naturaleza_movimiento(OLD.id_movimiento)
                        WHEN 'E' THEN OLD.cantidad ELSE -OLD.cantidad END;
    END IF;
    IF TG_OP IN ('INSERT','UPDATE') THEN
        v_efecto_new := CASE fn_naturaleza_movimiento(NEW.id_movimiento)
                        WHEN 'E' THEN NEW.cantidad ELSE -NEW.cantidad END;
    END IF;

    IF TG_OP = 'INSERT' THEN
        UPDATE articulo SET existencia_actual = existencia_actual + v_efecto_new
         WHERE id_articulo = NEW.id_articulo;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE articulo SET existencia_actual = existencia_actual - v_efecto_old
         WHERE id_articulo = OLD.id_articulo;
        RETURN OLD;
    ELSE  -- UPDATE
        IF NEW.id_articulo = OLD.id_articulo THEN
            IF v_efecto_new <> v_efecto_old THEN
                UPDATE articulo
                   SET existencia_actual = existencia_actual + (v_efecto_new - v_efecto_old)
                 WHERE id_articulo = NEW.id_articulo;
            END IF;
        ELSE
            UPDATE articulo SET existencia_actual = existencia_actual - v_efecto_old
             WHERE id_articulo = OLD.id_articulo;
            UPDATE articulo SET existencia_actual = existencia_actual + v_efecto_new
             WHERE id_articulo = NEW.id_articulo;
        END IF;
        RETURN NEW;
    END IF;
END $$;

CREATE TRIGGER trg_movdet_saldo
AFTER INSERT OR UPDATE OR DELETE ON movimiento_detalle
FOR EACH ROW EXECUTE FUNCTION fn_movdet_actualiza_saldo();

-- (P3) Borrado de un movimiento: sus líneas (y su fila de compra) se borran
-- en un BEFORE DELETE, mientras el encabezado AÚN ES VISIBLE, de modo que
-- trg_movdet_saldo puede leer la naturaleza vía fn_naturaleza_movimiento.
-- Por eso la FK de movimiento_detalle NO usa ON DELETE CASCADE: con cascada,
-- PostgreSQL borra primero el encabezado y las líneas después, y el trigger
-- de saldo ya no encontraría al padre.
CREATE FUNCTION fn_movimiento_borra_hijos() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM compra WHERE id_movimiento = OLD.id_movimiento;
    DELETE FROM movimiento_detalle WHERE id_movimiento = OLD.id_movimiento;
    RETURN OLD;
END $$;

CREATE TRIGGER trg_movimiento_borra_hijos
BEFORE DELETE ON movimiento
FOR EACH ROW EXECUTE FUNCTION fn_movimiento_borra_hijos();

-- Validación del despacho contra su requisición:
--   (a) solo artículos presentes en la requisición;
--   (b) despachado acumulado por artículo <= autorizado.
--   [P] autorizado = COALESCE(cantidad_aprobada, cantidad_solicitada).
CREATE FUNCTION fn_valida_despacho() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_req integer;
    v_autorizada numeric;
    v_despachada numeric;
BEGIN
    SELECT id_requisicion INTO v_req FROM movimiento WHERE id_movimiento = NEW.id_movimiento;
    IF v_req IS NULL THEN
        RETURN NEW;
    END IF;
    SELECT COALESCE(SUM(COALESCE(rd.cantidad_aprobada, rd.cantidad_solicitada)), 0)
      INTO v_autorizada
      FROM requisicion_detalle rd
     WHERE rd.id_requisicion = v_req AND rd.id_articulo = NEW.id_articulo;
    IF v_autorizada = 0 THEN
        RAISE EXCEPTION 'Despacho rechazado: el artículo % no está en la requisición % (o su cantidad autorizada es 0)',
            NEW.id_articulo, v_req;
    END IF;
    SELECT COALESCE(SUM(md.cantidad), 0)
      INTO v_despachada
      FROM movimiento_detalle md
      JOIN movimiento m ON m.id_movimiento = md.id_movimiento
     WHERE m.id_requisicion = v_req AND md.id_articulo = NEW.id_articulo;
    IF v_despachada > v_autorizada THEN
        RAISE EXCEPTION 'Despacho rechazado: artículo %, despachado acumulado % excede lo autorizado % en la requisición %',
            NEW.id_articulo, v_despachada, v_autorizada, v_req;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_movdet_valida_despacho
AFTER INSERT OR UPDATE ON movimiento_detalle
FOR EACH ROW EXECUTE FUNCTION fn_valida_despacho();

-- Protección de lo ya despachado: una línea de requisición no puede
-- modificarse ni eliminarse de forma que lo YA ENTREGADO de ese artículo
-- exceda lo autorizado restante. (INSERT no se valida: añadir líneas solo
-- aumenta la autorización.) La eliminación de una requisición completa con
-- despachos queda además bloqueada por la FK movimiento.id_requisicion
-- (sin ON DELETE), de modo que sus líneas nunca se pierden en cascada.
CREATE FUNCTION fn_reqdet_protege_despachado() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_despachada numeric;
    v_autorizada numeric;
BEGIN
    SELECT COALESCE(SUM(md.cantidad), 0)
      INTO v_despachada
      FROM movimiento_detalle md
      JOIN movimiento m ON m.id_movimiento = md.id_movimiento
     WHERE m.id_requisicion = OLD.id_requisicion
       AND md.id_articulo   = OLD.id_articulo;
    IF v_despachada > 0 THEN
        SELECT COALESCE(SUM(COALESCE(rd.cantidad_aprobada, rd.cantidad_solicitada)), 0)
          INTO v_autorizada
          FROM requisicion_detalle rd
         WHERE rd.id_requisicion = OLD.id_requisicion
           AND rd.id_articulo    = OLD.id_articulo;
        IF v_despachada > v_autorizada THEN
            RAISE EXCEPTION 'Cambio rechazado: la requisición % ya tiene % despachado del artículo % y la autorización quedaría en %',
                OLD.id_requisicion, v_despachada, OLD.id_articulo, v_autorizada;
        END IF;
    END IF;
    RETURN NULL;  -- AFTER trigger
END $$;

CREATE TRIGGER trg_reqdet_protege_despachado
AFTER UPDATE OR DELETE ON requisicion_detalle
FOR EACH ROW EXECUTE FUNCTION fn_reqdet_protege_despachado();

-- ---------------------------------------------------------------------------
-- 6. Vista de conciliación (derivados NO almacenados)
-- ---------------------------------------------------------------------------

CREATE VIEW vw_existencias_calculadas AS
SELECT a.id_articulo,
       a.codigo,
       a.descripcion,
       COALESCE(SUM(CASE WHEN tm.naturaleza = 'E' THEN md.cantidad
                         WHEN tm.naturaleza = 'S' THEN -md.cantidad END), 0) AS existencia_calculada,
       a.existencia_actual                                                   AS existencia_materializada,
       a.existencia_actual
       - COALESCE(SUM(CASE WHEN tm.naturaleza = 'E' THEN md.cantidad
                           WHEN tm.naturaleza = 'S' THEN -md.cantidad END), 0) AS diferencia
FROM articulo a
LEFT JOIN movimiento_detalle md ON md.id_articulo = a.id_articulo
LEFT JOIN movimiento m  ON m.id_movimiento = md.id_movimiento
LEFT JOIN tipo_movimiento tm ON tm.id_tipo_movimiento = m.id_tipo_movimiento
GROUP BY a.id_articulo, a.codigo, a.descripcion, a.existencia_actual;

COMMENT ON VIEW vw_existencias_calculadas IS
  'Conciliación saldo materializado vs. movimientos. diferencia <> 0 = inconsistencia. La carga inicial entra como movimiento de ajuste (ver documento de migración)';

-- ---------------------------------------------------------------------------
-- 7. Vistas de reportes (JPG bloque 6). Criterios de cálculo tomados del
--    propio libro Excel, sin inventar valoraciones:
--    * Inventario: stock y valoración = existencia x costo promedio vigente
--      (INVENTARIO col J = H*I, redondeo col K).
--    * Compras: costo unitario y total por línea tal como se registraron
--      (COMPRAS: costo unit = TOTAL/CANTIDAD congelado en el detalle).
--    * Salidas: cada línea valorada al costo histórico congelado
--      (RESUMEN DE SALIDAS: G = E*F, y su nota 44-47).
--    Los filtros (período, proveedor, unidad) los aplica el consumidor con
--    WHERE sobre estas vistas.
-- ---------------------------------------------------------------------------

-- 7.1 Reporte de inventario general: stock y valoración
CREATE VIEW vw_reporte_inventario AS
SELECT e.codigo  AS codigo_especifico,
       e.nombre  AS especifico,
       a.codigo  AS codigo_articulo,
       a.descripcion,
       um.abreviatura AS unidad_medida,
       a.existencia_actual,
       a.costo_promedio_actual,
       ROUND(a.existencia_actual * a.costo_promedio_actual, 2) AS costo_total,  -- criterio Excel col J/K
       a.activo
FROM articulo a
JOIN especifico   e  ON e.id_especifico = a.id_especifico
JOIN unidad_medida um ON um.id_unidad_medida = a.id_unidad_medida;

COMMENT ON VIEW vw_reporte_inventario IS
  'Reporte de inventario (stock/valoración) del JPG bloque 6; replica INVENTARIO cols H, I, J=H*I';

-- 7.2 Reporte de compras: por proveedor / fechas / costos
CREATE VIEW vw_reporte_compras AS
SELECT m.fecha,
       m.numero_comprobante,
       p.nombre  AS proveedor,
       c.numero_factura,
       e.codigo  AS codigo_especifico,
       a.codigo  AS codigo_articulo,
       a.descripcion,
       md.numero_linea,
       md.cantidad,
       md.costo_unitario,
       ROUND(md.cantidad * md.costo_unitario, 2) AS costo_total_linea,
       u.nombre_usuario AS registrado_por
FROM compra c
JOIN movimiento m  ON m.id_movimiento = c.id_movimiento
JOIN proveedor  p  ON p.id_proveedor = c.id_proveedor
JOIN movimiento_detalle md ON md.id_movimiento = c.id_movimiento
JOIN articulo   a  ON a.id_articulo = md.id_articulo
JOIN especifico e  ON e.id_especifico = a.id_especifico
JOIN usuario    u  ON u.id_usuario = m.id_usuario_registra;

COMMENT ON VIEW vw_reporte_compras IS
  'Reporte de compras (proveedor/fechas/costos) del JPG bloque 6; costo unitario congelado como en COMPRAS col K';

-- 7.3 Reporte de requisiciones: solicitudes y consumo por unidad
CREATE VIEW vw_reporte_requisiciones AS
SELECT r.numero,
       r.fecha_solicitud,
       uo.nombre AS unidad_organizativa,
       r.estado,
       us.nombre_usuario AS solicitante,
       ur.nombre_usuario AS revisor,
       a.codigo  AS codigo_articulo,
       a.descripcion,
       rd.numero_linea,
       rd.cantidad_solicitada,
       rd.cantidad_aprobada,
       COALESCE(desp.cantidad_despachada, 0) AS cantidad_despachada
FROM requisicion r
JOIN unidad_organizativa uo ON uo.id_unidad_organizativa = r.id_unidad_organizativa
JOIN usuario us ON us.id_usuario = r.id_usuario_solicita
LEFT JOIN usuario ur ON ur.id_usuario = r.id_usuario_revisa
JOIN requisicion_detalle rd ON rd.id_requisicion = r.id_requisicion
JOIN articulo a ON a.id_articulo = rd.id_articulo
LEFT JOIN LATERAL (
    SELECT SUM(md.cantidad) AS cantidad_despachada
    FROM movimiento m
    JOIN movimiento_detalle md ON md.id_movimiento = m.id_movimiento
    WHERE m.id_requisicion = r.id_requisicion
      AND md.id_articulo = rd.id_articulo
) desp ON true;

COMMENT ON VIEW vw_reporte_requisiciones IS
  'Reporte de requisiciones (consumo por unidad / solicitudes) del JPG bloque 6. La cantidad despachada se muestra por artículo de la requisición (si un artículo ocupa varias líneas, cada línea muestra el despacho total del artículo)';

-- 7.4 Salidas por período / departamento (todas las naturalezas S:
--     requisiciones, ajustes de salida, obsolescencia)
CREATE VIEW vw_reporte_salidas AS
SELECT m.fecha,
       tm.codigo AS tipo_movimiento,
       tm.nombre AS tipo_movimiento_nombre,
       m.numero_comprobante,
       r.numero  AS numero_requisicion,
       uo.nombre AS unidad_organizativa,   -- NULL en salidas sin requisición (ajustes/obsolescencia)
       e.codigo  AS codigo_especifico,
       a.codigo  AS codigo_articulo,
       a.descripcion,
       md.numero_linea,
       md.cantidad,
       md.costo_unitario,                  -- costo histórico congelado (nota RESUMEN 44-47)
       ROUND(md.cantidad * md.costo_unitario, 2) AS costo_total_linea
FROM movimiento m
JOIN tipo_movimiento tm ON tm.id_tipo_movimiento = m.id_tipo_movimiento
JOIN movimiento_detalle md ON md.id_movimiento = m.id_movimiento
JOIN articulo a ON a.id_articulo = md.id_articulo
JOIN especifico e ON e.id_especifico = a.id_especifico
LEFT JOIN requisicion r ON r.id_requisicion = m.id_requisicion
LEFT JOIN unidad_organizativa uo ON uo.id_unidad_organizativa = r.id_unidad_organizativa
WHERE tm.naturaleza = 'S';

COMMENT ON VIEW vw_reporte_salidas IS
  'Resumen de salidas (por período/departamento) del JPG bloque 6; cada línea al costo histórico, como RESUMEN DE SALIDAS G=E*F. Filtrar por fecha/unidad con WHERE';

COMMIT;
