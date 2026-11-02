-- =========================================================================
-- VISTAS: Rendimiento según Circuitos (Rápidos vs. Lentos: 2001-2005)
-- Circuitos Rápidos: Spa-Francorchamps y Suzuka
-- Circuitos Lentos: Hungaroring y Mónaco
-- Comparativa:
--   1. Vuelta rápida en Qualy (Q3 / clasificación final) usando el auto más rápido
--      de cada proveedor (Michelin vs. Bridgestone).
--   2. Puntos obtenidos normalizados por la cantidad de autos en parrilla (grilla)
--      que tenía cada proveedor en la carrera.
--   3. Métricas complementarias: podios, victorias y abandonos (DNFs).
-- Referencia: Script-7.sql
-- =========================================================================

SET search_path TO formula1, public;

DROP VIEW IF EXISTS formula1.v_resumen_rendimiento_circuitos CASCADE;
DROP VIEW IF EXISTS formula1.v_analisis_rendimiento_circuitos CASCADE;

-- =========================================================================
-- VISTA 1: Análisis Granular por Gran Premio (19 carreras disputadas 2001-2005)
-- =========================================================================
CREATE OR REPLACE VIEW formula1.v_analisis_rendimiento_circuitos AS
WITH circuit_meta AS (
    SELECT 
        c.id AS circuit_id,
        c.name AS circuit_name,
        CASE 
            WHEN c.id IN ('spa-francorchamps', 'suzuka') THEN 'Rápido'
            WHEN c.id IN ('monaco', 'hungaroring') THEN 'Lento'
        END AS tipo_circuito
    FROM formula1.circuit c
    WHERE c.id IN ('spa-francorchamps', 'suzuka', 'monaco', 'hungaroring')
),
races_selected AS (
    SELECT 
        r.id AS race_id,
        r.year,
        r.round,
        r.official_name AS grand_prix,
        r.circuit_id,
        cm.circuit_name,
        cm.tipo_circuito,
        r.year::text || ' ' || cm.circuit_name AS carrera_rotulo
    FROM formula1.race r
    INNER JOIN circuit_meta cm ON cm.circuit_id = r.circuit_id
    WHERE r.year BETWEEN 2001 AND 2005
),
qualy_ranked AS (
    SELECT 
        qr.race_id,
        qr.tyre_manufacturer_id,
        qr.driver_id,
        d.name AS driver_name,
        qr.constructor_id,
        co.name AS constructor_name,
        COALESCE(NULLIF(qr.q3_millis, 0), qr.time_millis) AS qualy_time_millis,
        ROW_NUMBER() OVER (
            PARTITION BY qr.race_id, qr.tyre_manufacturer_id 
            ORDER BY COALESCE(NULLIF(qr.q3_millis, 0), qr.time_millis) ASC
        ) as rn
    FROM formula1.qualifying_result qr
    INNER JOIN formula1.driver d ON d.id = qr.driver_id
    INNER JOIN formula1.constructor co ON co.id = qr.constructor_id
    WHERE qr.race_id IN (SELECT race_id FROM races_selected)
      AND qr.tyre_manufacturer_id IN ('michelin', 'bridgestone')
      AND COALESCE(NULLIF(qr.q3_millis, 0), qr.time_millis) > 0
),
qualy_fastest AS (
    SELECT 
        race_id,
        tyre_manufacturer_id,
        driver_id,
        driver_name,
        constructor_id,
        constructor_name,
        qualy_time_millis,
        ROUND((qualy_time_millis / 1000.0), 3) AS qualy_time_sec
    FROM qualy_ranked
    WHERE rn = 1
),
race_stats AS (
    SELECT 
        rr.race_id,
        rr.tyre_manufacturer_id,
        COUNT(CASE WHEN rr.position_text <> 'DNS' THEN 1 END) AS autos_grilla,
        COALESCE(SUM(rr.points), 0) AS puntos_totales,
        COUNT(CASE WHEN rr.position_number = 1 THEN 1 END) AS victorias,
        COUNT(CASE WHEN rr.position_number <= 3 THEN 1 END) AS podios,
        COUNT(CASE WHEN rr.position_text = 'DNF' THEN 1 END) AS dnfs,
        COUNT(CASE 
            WHEN rr.position_text = 'DNF' AND (
                rr.reason_retired ILIKE '%tyre%' 
                OR rr.reason_retired ILIKE '%tire%' 
                OR rr.reason_retired ILIKE '%puncture%'
            ) THEN 1 
        END) AS dnfs_neumaticos
    FROM formula1.race_result rr
    WHERE rr.race_id IN (SELECT race_id FROM races_selected)
      AND rr.tyre_manufacturer_id IN ('michelin', 'bridgestone')
    GROUP BY rr.race_id, rr.tyre_manufacturer_id
)
SELECT 
    rs.race_id,
    rs.year,
    rs.round,
    rs.grand_prix,
    rs.circuit_id,
    rs.circuit_name,
    rs.tipo_circuito,
    rs.carrera_rotulo,
    
    -- Vuelta Rápida en Qualy (Q3 / final) - Michelin
    qm.driver_id AS piloto_id_michelin,
    qm.driver_name AS piloto_michelin,
    qm.constructor_id AS equipo_id_michelin,
    qm.constructor_name AS equipo_michelin,
    qm.qualy_time_sec AS tiempo_qualy_michelin_sec,
    
    -- Vuelta Rápida en Qualy (Q3 / final) - Bridgestone
    qb.driver_id AS piloto_id_bridgestone,
    qb.driver_name AS piloto_bridgestone,
    qb.constructor_id AS equipo_id_bridgestone,
    qb.constructor_name AS equipo_bridgestone,
    qb.qualy_time_sec AS tiempo_qualy_bridgestone_sec,
    
    -- Diferenciales de Qualy
    -- Delta < 0: Michelin fue más rápido; Delta > 0: Bridgestone fue más rápido
    ROUND((qm.qualy_time_sec - qb.qualy_time_sec), 3) AS delta_qualy_sec,
    ROUND(ABS(qm.qualy_time_sec - qb.qualy_time_sec), 3) AS delta_qualy_sec_abs,
    ROUND((((qm.qualy_time_sec - qb.qualy_time_sec) / qb.qualy_time_sec) * 100.0), 3) AS delta_qualy_pct,
    CASE 
        WHEN qm.qualy_time_sec < qb.qualy_time_sec THEN 'Michelin'
        WHEN qb.qualy_time_sec < qm.qualy_time_sec THEN 'Bridgestone'
        ELSE 'Empate'
    END AS ganador_qualy,
    'M: ' || qm.driver_name || ' (' || qm.constructor_name || ') vs B: ' || qb.driver_name || ' (' || qb.constructor_name || ')' AS rotulo_comparacion_qualy,
    
    -- Puntos y Normalización por Autos en Parrilla
    sm.autos_grilla AS autos_grilla_michelin,
    sm.puntos_totales AS puntos_totales_michelin,
    ROUND((sm.puntos_totales::numeric / NULLIF(sm.autos_grilla, 0)), 2) AS puntos_por_auto_michelin,
    
    sb.autos_grilla AS autos_grilla_bridgestone,
    sb.puntos_totales AS puntos_totales_bridgestone,
    ROUND((sb.puntos_totales::numeric / NULLIF(sb.autos_grilla, 0)), 2) AS puntos_por_auto_bridgestone,
    
    -- Diferenciales de Puntos Normalizados
    -- Delta > 0: Michelin obtuvo mayor rendimiento por auto; Delta < 0: Bridgestone obtuvo más
    ROUND((sm.puntos_totales::numeric / NULLIF(sm.autos_grilla, 0)) - (sb.puntos_totales::numeric / NULLIF(sb.autos_grilla, 0)), 2) AS delta_puntos_por_auto,
    ROUND(ABS((sm.puntos_totales::numeric / NULLIF(sm.autos_grilla, 0)) - (sb.puntos_totales::numeric / NULLIF(sb.autos_grilla, 0))), 2) AS delta_puntos_por_auto_abs,
    CASE 
        WHEN (sm.puntos_totales::numeric / NULLIF(sm.autos_grilla, 0)) > (sb.puntos_totales::numeric / NULLIF(sb.autos_grilla, 0)) THEN 'Michelin'
        WHEN (sb.puntos_totales::numeric / NULLIF(sb.autos_grilla, 0)) > (sm.puntos_totales::numeric / NULLIF(sm.autos_grilla, 0)) THEN 'Bridgestone'
        ELSE 'Empate'
    END AS ganador_puntos_normalizados,
    
    -- Resultados de Carrera y Fiabilidad
    sm.victorias AS victorias_michelin,
    sb.victorias AS victorias_bridgestone,
    sm.podios AS podios_michelin,
    sb.podios AS podios_bridgestone,
    sm.dnfs AS dnf_michelin,
    sb.dnfs AS dnf_bridgestone,
    sm.dnfs_neumaticos AS dnf_neumaticos_michelin,
    sb.dnfs_neumaticos AS dnf_neumaticos_bridgestone,
    ROUND((sm.dnfs::numeric / NULLIF(sm.autos_grilla, 0)), 4) AS tasa_dnf_michelin,
    ROUND((sb.dnfs::numeric / NULLIF(sb.autos_grilla, 0)), 4) AS tasa_dnf_bridgestone

FROM races_selected rs
INNER JOIN qualy_fastest qm ON qm.race_id = rs.race_id AND qm.tyre_manufacturer_id = 'michelin'
INNER JOIN qualy_fastest qb ON qb.race_id = rs.race_id AND qb.tyre_manufacturer_id = 'bridgestone'
INNER JOIN race_stats sm ON sm.race_id = rs.race_id AND sm.tyre_manufacturer_id = 'michelin'
INNER JOIN race_stats sb ON sb.race_id = rs.race_id AND sb.tyre_manufacturer_id = 'bridgestone'
ORDER BY rs.year, rs.round;

-- =========================================================================
-- VISTA 2: Resumen Agregado por Tipo de Circuito y por Circuito
-- =========================================================================
CREATE OR REPLACE VIEW formula1.v_resumen_rendimiento_circuitos AS
SELECT 
    tipo_circuito,
    circuit_name,
    COUNT(*) AS total_carreras,
    
    -- Qualy
    COUNT(CASE WHEN ganador_qualy = 'Michelin' THEN 1 END) AS qualy_ganadas_michelin,
    COUNT(CASE WHEN ganador_qualy = 'Bridgestone' THEN 1 END) AS qualy_ganadas_bridgestone,
    ROUND(AVG(tiempo_qualy_michelin_sec), 3) AS tiempo_promedio_qualy_michelin_sec,
    ROUND(AVG(tiempo_qualy_bridgestone_sec), 3) AS tiempo_promedio_qualy_bridgestone_sec,
    ROUND(AVG(delta_qualy_sec), 3) AS delta_promedio_qualy_sec,
    ROUND(AVG(delta_qualy_pct), 3) AS delta_promedio_qualy_pct,
    
    -- Puntos y Normalización
    SUM(autos_grilla_michelin) AS autos_grilla_totales_michelin,
    SUM(puntos_totales_michelin) AS puntos_totales_michelin,
    ROUND(AVG(puntos_por_auto_michelin), 2) AS puntos_promedio_por_auto_michelin,
    
    SUM(autos_grilla_bridgestone) AS autos_grilla_totales_bridgestone,
    SUM(puntos_totales_bridgestone) AS puntos_totales_bridgestone,
    ROUND(AVG(puntos_por_auto_bridgestone), 2) AS puntos_promedio_por_auto_bridgestone,
    
    ROUND(AVG(delta_puntos_por_auto), 2) AS delta_promedio_puntos_por_auto,
    COUNT(CASE WHEN ganador_puntos_normalizados = 'Michelin' THEN 1 END) AS carreras_ganadas_puntos_norm_michelin,
    COUNT(CASE WHEN ganador_puntos_normalizados = 'Bridgestone' THEN 1 END) AS carreras_ganadas_puntos_norm_bridgestone,
    
    -- Victorias y Podios
    SUM(victorias_michelin) AS victorias_totales_michelin,
    SUM(victorias_bridgestone) AS victorias_totales_bridgestone,
    SUM(podios_michelin) AS podios_totales_michelin,
    SUM(podios_bridgestone) AS podios_totales_bridgestone,
    
    -- DNFs
    SUM(dnf_michelin) AS total_dnf_michelin,
    SUM(dnf_bridgestone) AS total_dnf_bridgestone,
    SUM(dnf_neumaticos_michelin) AS total_dnf_neumaticos_michelin,
    SUM(dnf_neumaticos_bridgestone) AS total_dnf_neumaticos_bridgestone,
    ROUND(SUM(dnf_michelin)::numeric / NULLIF(SUM(autos_grilla_michelin), 0), 4) AS tasa_dnf_global_michelin,
    ROUND(SUM(dnf_bridgestone)::numeric / NULLIF(SUM(autos_grilla_bridgestone), 0), 4) AS tasa_dnf_global_bridgestone

FROM formula1.v_analisis_rendimiento_circuitos
GROUP BY GROUPING SETS (
    (tipo_circuito, circuit_name),
    (tipo_circuito)
)
ORDER BY tipo_circuito, circuit_name NULLS LAST;
