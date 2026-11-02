-- =========================================================================
-- VISTAS: Rendimiento según Circuitos (Rápidos vs. Lentos: 2001-2005)
-- Circuitos Rápidos: Spa-Francorchamps y Suzuka
-- Circuitos Lentos: Hungaroring y Mónaco
-- Comparativa:
--   1. Vuelta rápida en Qualy (Q3 / clasificación final) usando el auto más rápido
--      de cada proveedor (Michelin vs. Bridgestone).
--   2. Ritmo Normalizado Carrera vs Qualy: ((time_lap - time_pole) / time_pole)
--      Puntaje normalizado de fidelidad de ritmo por proveedor y piloto/auto.
--   3. Puntos obtenidos normalizados por la cantidad de autos en parrilla (grilla)
--      que tenía cada proveedor en la carrera.
--   4. Métricas complementarias: podios, victorias y abandonos (DNFs).
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
        (r.year * 100 + r.round)::integer AS orden_carrera,
        r.official_name AS grand_prix,
        r.circuit_id,
        cm.circuit_name,
        cm.tipo_circuito,
        r.year::text || ' ' || cm.circuit_name AS carrera_rotulo
    FROM formula1.race r
    INNER JOIN circuit_meta cm ON cm.circuit_id = r.circuit_id
    WHERE r.year BETWEEN 2001 AND 2005
),
clean_qualy AS (
    SELECT 
        qr.race_id,
        qr.driver_id,
        qr.constructor_id,
        qr.tyre_manufacturer_id,
        CASE 
            WHEN r.year = 2005 AND r.round = 6 AND q1.time_millis IS NOT NULL THEN q1.time_millis
            ELSE qr.time_millis
        END AS qualy_millis
    FROM formula1.qualifying_result qr
    JOIN formula1.race r ON r.id = qr.race_id
    LEFT JOIN formula1.qualifying_1_result q1 ON q1.race_id = qr.race_id AND q1.driver_id = qr.driver_id
    WHERE qr.time_millis IS NOT NULL AND qr.time_millis > 0
),
gp_poles AS (
    SELECT race_id, MIN(qualy_millis) as gp_pole_millis
    FROM clean_qualy
    GROUP BY race_id
),
qualy_ranked AS (
    SELECT 
        cq.race_id,
        cq.tyre_manufacturer_id,
        cq.driver_id,
        d.name AS driver_name,
        cq.constructor_id,
        c.name AS constructor_name,
        cq.qualy_millis,
        ROW_NUMBER() OVER (
            PARTITION BY cq.race_id, cq.tyre_manufacturer_id 
            ORDER BY cq.qualy_millis ASC
        ) AS rn
    FROM clean_qualy cq
    INNER JOIN formula1.driver d ON d.id = cq.driver_id
    INNER JOIN formula1.constructor c ON c.id = cq.constructor_id
    WHERE cq.tyre_manufacturer_id IN ('michelin', 'bridgestone')
),
qualy_michelin AS (
    SELECT 
        race_id,
        driver_id AS piloto_id_michelin,
        driver_name AS piloto_michelin,
        constructor_id AS equipo_id_michelin,
        constructor_name AS equipo_michelin,
        ROUND(qualy_millis / 1000.0, 3) AS tiempo_qualy_michelin_sec
    FROM qualy_ranked
    WHERE tyre_manufacturer_id = 'michelin' AND rn = 1
),
qualy_bridgestone AS (
    SELECT 
        race_id,
        driver_id AS piloto_id_bridgestone,
        driver_name AS piloto_bridgestone,
        constructor_id AS equipo_id_bridgestone,
        constructor_name AS equipo_bridgestone,
        ROUND(qualy_millis / 1000.0, 3) AS tiempo_qualy_bridgestone_sec
    FROM qualy_ranked
    WHERE tyre_manufacturer_id = 'bridgestone' AND rn = 1
),
-- PACE RETENTION / QUALY-TO-RACE NORMALIZATION:
driver_pace AS (
    SELECT 
        fl.race_id,
        fl.tyre_manufacturer_id,
        fl.driver_id,
        d.name AS driver_name,
        co.name AS constructor_name,
        cq.qualy_millis,
        gp.gp_pole_millis,
        fl.time_millis AS race_fl_millis,
        ROUND(((fl.time_millis - cq.qualy_millis)::numeric / cq.qualy_millis) * 100.0, 3) AS ritmo_vs_own_qualy_pct,
        ROUND(((fl.time_millis - gp.gp_pole_millis)::numeric / gp.gp_pole_millis) * 100.0, 3) AS ritmo_vs_gp_pole_pct,
        ROW_NUMBER() OVER(
            PARTITION BY fl.race_id, fl.tyre_manufacturer_id 
            ORDER BY fl.time_millis ASC
        ) as rank_fastest_race
    FROM formula1.fastest_lap fl
    JOIN clean_qualy cq ON cq.race_id = fl.race_id AND cq.driver_id = fl.driver_id
    JOIN gp_poles gp ON gp.race_id = fl.race_id
    JOIN formula1.driver d ON d.id = fl.driver_id
    JOIN formula1.constructor co ON co.id = fl.constructor_id
    WHERE fl.tyre_manufacturer_id IN ('michelin', 'bridgestone')
      AND fl.time_millis IS NOT NULL AND fl.time_millis > 0
),
pace_michelin AS (
    SELECT 
        race_id,
        driver_name AS michelin_ritmo_piloto,
        constructor_name AS michelin_ritmo_constructor,
        driver_name || ' (' || constructor_name || ')' AS michelin_ritmo_label,
        ROUND(qualy_millis / 1000.0, 3) AS michelin_ritmo_qualy_sec,
        ROUND(race_fl_millis / 1000.0, 3) AS michelin_race_fl_sec,
        ritmo_vs_own_qualy_pct AS michelin_ritmo_score_pct,
        ritmo_vs_gp_pole_pct AS michelin_ritmo_vs_pole_pct
    FROM driver_pace
    WHERE tyre_manufacturer_id = 'michelin' AND rank_fastest_race = 1
),
pace_bridgestone AS (
    SELECT 
        race_id,
        driver_name AS bridgestone_ritmo_piloto,
        constructor_name AS bridgestone_ritmo_constructor,
        driver_name || ' (' || constructor_name || ')' AS bridgestone_ritmo_label,
        ROUND(qualy_millis / 1000.0, 3) AS bridgestone_ritmo_qualy_sec,
        ROUND(race_fl_millis / 1000.0, 3) AS bridgestone_race_fl_sec,
        ritmo_vs_own_qualy_pct AS bridgestone_ritmo_score_pct,
        ritmo_vs_gp_pole_pct AS bridgestone_ritmo_vs_pole_pct
    FROM driver_pace
    WHERE tyre_manufacturer_id = 'bridgestone' AND rank_fastest_race = 1
),
grid_counts AS (
    SELECT 
        rd.race_id,
        COUNT(*) FILTER (WHERE rd.tyre_manufacturer_id = 'michelin') AS autos_grilla_michelin,
        COUNT(*) FILTER (WHERE rd.tyre_manufacturer_id = 'bridgestone') AS autos_grilla_bridgestone
    FROM formula1.race_data rd
    WHERE rd.type = 'STARTING_GRID_POSITION'
      AND rd.tyre_manufacturer_id IN ('michelin', 'bridgestone')
    GROUP BY rd.race_id
),
race_stats AS (
    SELECT 
        rr.race_id,
        COALESCE(SUM(rr.points) FILTER (WHERE rr.tyre_manufacturer_id = 'michelin'), 0) AS puntos_totales_michelin,
        COALESCE(SUM(rr.points) FILTER (WHERE rr.tyre_manufacturer_id = 'bridgestone'), 0) AS puntos_totales_bridgestone,
        COUNT(*) FILTER (WHERE rr.tyre_manufacturer_id = 'michelin' AND rr.position_number = 1) AS victorias_michelin,
        COUNT(*) FILTER (WHERE rr.tyre_manufacturer_id = 'bridgestone' AND rr.position_number = 1) AS victorias_bridgestone,
        COUNT(*) FILTER (WHERE rr.tyre_manufacturer_id = 'michelin' AND rr.position_number BETWEEN 1 AND 3) AS podios_michelin,
        COUNT(*) FILTER (WHERE rr.tyre_manufacturer_id = 'bridgestone' AND rr.position_number BETWEEN 1 AND 3) AS podios_bridgestone,
        COUNT(*) FILTER (WHERE rr.tyre_manufacturer_id = 'michelin' AND (rr.position_text = 'R' OR rr.reason_retired IS NOT NULL)) AS dnf_michelin,
        COUNT(*) FILTER (WHERE rr.tyre_manufacturer_id = 'bridgestone' AND (rr.position_text = 'R' OR rr.reason_retired IS NOT NULL)) AS dnf_bridgestone,
        COUNT(*) FILTER (WHERE rr.tyre_manufacturer_id = 'michelin' AND (
            LOWER(rr.reason_retired) LIKE '%tyre%' 
            OR LOWER(rr.reason_retired) LIKE '%tire%' 
            OR LOWER(rr.reason_retired) LIKE '%puncture%'
            OR LOWER(rr.reason_retired) LIKE '%wheel%'
        )) AS dnf_neumaticos_michelin,
        COUNT(*) FILTER (WHERE rr.tyre_manufacturer_id = 'bridgestone' AND (
            LOWER(rr.reason_retired) LIKE '%tyre%' 
            OR LOWER(rr.reason_retired) LIKE '%tire%' 
            OR LOWER(rr.reason_retired) LIKE '%puncture%'
            OR LOWER(rr.reason_retired) LIKE '%wheel%'
        )) AS dnf_neumaticos_bridgestone
    FROM formula1.race_result rr
    WHERE rr.tyre_manufacturer_id IN ('michelin', 'bridgestone')
    GROUP BY rr.race_id
)
SELECT 
    rs.race_id,
    rs.year,
    rs.round,
    rs.orden_carrera,
    rs.grand_prix,
    rs.circuit_id,
    rs.circuit_name,
    rs.tipo_circuito,
    rs.carrera_rotulo,
    
    -- Qualy comparativa
    qm.piloto_id_michelin,
    qm.piloto_michelin,
    qm.equipo_id_michelin,
    qm.equipo_michelin,
    qm.tiempo_qualy_michelin_sec,
    qb.piloto_id_bridgestone,
    qb.piloto_bridgestone,
    qb.equipo_id_bridgestone,
    qb.equipo_bridgestone,
    qb.tiempo_qualy_bridgestone_sec,
    ROUND(qm.tiempo_qualy_michelin_sec - qb.tiempo_qualy_bridgestone_sec, 3) AS delta_qualy_sec,
    ROUND(ABS(qm.tiempo_qualy_michelin_sec - qb.tiempo_qualy_bridgestone_sec), 3) AS delta_qualy_sec_abs,
    ROUND(((qm.tiempo_qualy_michelin_sec - qb.tiempo_qualy_bridgestone_sec) / qb.tiempo_qualy_bridgestone_sec) * 100.0, 3) AS delta_qualy_pct,
    CASE 
        WHEN qm.tiempo_qualy_michelin_sec < qb.tiempo_qualy_bridgestone_sec THEN 'Michelin'
        WHEN qb.tiempo_qualy_bridgestone_sec < qm.tiempo_qualy_michelin_sec THEN 'Bridgestone'
        ELSE 'Empate'
    END AS ganador_qualy,
    qm.piloto_michelin || ' (' || qm.equipo_michelin || ') vs ' || qb.piloto_bridgestone || ' (' || qb.equipo_bridgestone || ')' AS rotulo_comparacion_qualy,

    -- Ritmo Normalizado Carrera vs Qualy ((time_lap - time_pole)/time_pole)
    pm.michelin_ritmo_score_pct,
    pm.michelin_ritmo_piloto,
    pm.michelin_ritmo_constructor,
    pm.michelin_ritmo_label,
    pm.michelin_race_fl_sec,
    pm.michelin_ritmo_qualy_sec,
    pb.bridgestone_ritmo_score_pct,
    pb.bridgestone_ritmo_piloto,
    pb.bridgestone_ritmo_constructor,
    pb.bridgestone_ritmo_label,
    pb.bridgestone_race_fl_sec,
    pb.bridgestone_ritmo_qualy_sec,
    ROUND(pm.michelin_ritmo_score_pct - pb.bridgestone_ritmo_score_pct, 3) AS delta_ritmo_score_pct,
    CASE 
        WHEN pm.michelin_ritmo_score_pct < pb.bridgestone_ritmo_score_pct THEN 'Michelin'
        WHEN pb.bridgestone_ritmo_score_pct < pm.michelin_ritmo_score_pct THEN 'Bridgestone'
        ELSE 'Empate'
    END AS ganador_ritmo,
    'M: ' || pm.michelin_ritmo_label || ' | B: ' || pb.bridgestone_ritmo_label AS comparativa_pilotos_ritmo,

    -- Puntos normalizados
    gc.autos_grilla_michelin,
    rst.puntos_totales_michelin,
    ROUND(rst.puntos_totales_michelin / NULLIF(gc.autos_grilla_michelin, 0), 2) AS puntos_por_auto_michelin,
    gc.autos_grilla_bridgestone,
    rst.puntos_totales_bridgestone,
    ROUND(rst.puntos_totales_bridgestone / NULLIF(gc.autos_grilla_bridgestone, 0), 2) AS puntos_por_auto_bridgestone,
    ROUND((rst.puntos_totales_michelin / NULLIF(gc.autos_grilla_michelin, 0)) - (rst.puntos_totales_bridgestone / NULLIF(gc.autos_grilla_bridgestone, 0)), 2) AS delta_puntos_por_auto,
    ROUND(ABS((rst.puntos_totales_michelin / NULLIF(gc.autos_grilla_michelin, 0)) - (rst.puntos_totales_bridgestone / NULLIF(gc.autos_grilla_bridgestone, 0))), 2) AS delta_puntos_por_auto_abs,
    CASE 
        WHEN (rst.puntos_totales_michelin / NULLIF(gc.autos_grilla_michelin, 0)) > (rst.puntos_totales_bridgestone / NULLIF(gc.autos_grilla_bridgestone, 0)) THEN 'Michelin'
        WHEN (rst.puntos_totales_bridgestone / NULLIF(gc.autos_grilla_bridgestone, 0)) > (rst.puntos_totales_michelin / NULLIF(gc.autos_grilla_bridgestone, 0)) THEN 'Bridgestone'
        ELSE 'Empate'
    END AS ganador_puntos_normalizados,

    -- Éxito y fiabilidad
    rst.victorias_michelin,
    rst.victorias_bridgestone,
    rst.podios_michelin,
    rst.podios_bridgestone,
    rst.dnf_michelin,
    rst.dnf_bridgestone,
    rst.dnf_neumaticos_michelin,
    rst.dnf_neumaticos_bridgestone,
    ROUND((rst.dnf_michelin::numeric / NULLIF(gc.autos_grilla_michelin, 0)) * 100.0, 2) AS tasa_dnf_michelin,
    ROUND((rst.dnf_bridgestone::numeric / NULLIF(gc.autos_grilla_bridgestone, 0)) * 100.0, 2) AS tasa_dnf_bridgestone
FROM races_selected rs
LEFT JOIN qualy_michelin qm ON qm.race_id = rs.race_id
LEFT JOIN qualy_bridgestone qb ON qb.race_id = rs.race_id
LEFT JOIN pace_michelin pm ON pm.race_id = rs.race_id
LEFT JOIN pace_bridgestone pb ON pb.race_id = rs.race_id
LEFT JOIN grid_counts gc ON gc.race_id = rs.race_id
LEFT JOIN race_stats rst ON rst.race_id = rs.race_id
ORDER BY rs.year, rs.round;

-- =========================================================================
-- VISTA 2: Resumen Agregado por Circuito y Tipo de Circuito
-- =========================================================================
CREATE OR REPLACE VIEW formula1.v_resumen_rendimiento_circuitos AS
SELECT 
    tipo_circuito,
    circuit_name,
    COUNT(DISTINCT race_id) AS total_gps,
    ROUND(AVG(tiempo_qualy_michelin_sec), 3) AS avg_qualy_michelin_sec,
    ROUND(AVG(tiempo_qualy_bridgestone_sec), 3) AS avg_qualy_bridgestone_sec,
    ROUND(AVG(delta_qualy_sec), 3) AS avg_delta_qualy_sec,
    ROUND(AVG(michelin_ritmo_score_pct), 3) AS avg_ritmo_michelin_pct,
    ROUND(AVG(bridgestone_ritmo_score_pct), 3) AS avg_ritmo_bridgestone_pct,
    ROUND(AVG(delta_ritmo_score_pct), 3) AS avg_delta_ritmo_pct,
    COUNT(*) FILTER (WHERE ganador_qualy = 'Michelin') AS poles_michelin,
    COUNT(*) FILTER (WHERE ganador_qualy = 'Bridgestone') AS poles_bridgestone,
    ROUND(AVG(puntos_por_auto_michelin), 2) AS avg_puntos_por_auto_michelin,
    ROUND(AVG(puntos_por_auto_bridgestone), 2) AS avg_puntos_por_auto_bridgestone,
    ROUND(AVG(delta_puntos_por_auto), 2) AS avg_delta_puntos_por_auto,
    SUM(victorias_michelin) AS total_victorias_michelin,
    SUM(victorias_bridgestone) AS total_victorias_bridgestone,
    SUM(podios_michelin) AS total_podios_michelin,
    SUM(podios_bridgestone) AS total_podios_bridgestone,
    ROUND(AVG(tasa_dnf_michelin), 2) AS avg_tasa_dnf_michelin,
    ROUND(AVG(tasa_dnf_bridgestone), 2) AS avg_tasa_dnf_bridgestone
FROM formula1.v_analisis_rendimiento_circuitos
GROUP BY tipo_circuito, circuit_name
ORDER BY tipo_circuito, circuit_name;
