SET search_path TO formula1, public;

-- =========================================================================
-- VISTA 1: Rendimiento en lluvia carrera a carrera por Segmento de Escudería (2001-2005)
-- Compara el mejor representante de Michelin y Bridgestone dentro de cada segmento:
-- Top Tier (Ferrari vs McLaren/Renault), Midfield (Williams/BAR/Toyota vs Sauber/Jordan),
-- y Fondo de Grilla (Backmarker).
-- =========================================================================
DROP VIEW IF EXISTS formula1.v_resumen_rendimiento_lluvia CASCADE;
DROP VIEW IF EXISTS formula1.v_caida_rendimiento_seco_vs_lluvia CASCADE;
DROP VIEW IF EXISTS formula1.v_analisis_rendimiento_lluvia_carreras CASCADE;

CREATE VIEW formula1.v_analisis_rendimiento_lluvia_carreras AS
WITH wet_races AS (
    SELECT 
        r.id AS race_id,
        r.year,
        r.round,
        r.official_name AS grand_prix,
        r.circuit_id,
        rw.precipitation_total_mm
    FROM formula1.race r
    JOIN formula1.race_weather rw ON rw.race_id = r.id
    WHERE r.year BETWEEN 2001 AND 2005
      AND rw.is_wet_race = true
),
race_winners AS (
    SELECT race_id, time_millis AS winner_time_millis, laps AS winner_laps
    FROM formula1.race_result
    WHERE position_number = 1
),
team_segment AS (
    SELECT 
        id AS constructor_id,
        CASE 
            WHEN id IN ('ferrari', 'renault', 'mclaren') THEN 'top_tier'
            WHEN id IN ('williams', 'toyota', 'bar', 'sauber', 'red-bull', 'red_bull', 'jaguar') THEN 'midfield'
            ELSE 'backmarker'
        END AS id_segmento
    FROM formula1.constructor
),
driver_pace AS (
    SELECT 
        wr.race_id,
        wr.year,
        wr.round,
        wr.grand_prix,
        wr.circuit_id,
        wr.precipitation_total_mm,
        ts.id_segmento,
        rr.tyre_manufacturer_id,
        rr.constructor_id,
        rr.driver_id,
        rr.position_number,
        rr.laps,
        CASE 
            WHEN rr.time_millis IS NOT NULL THEN (rr.time_millis::numeric / rr.laps::numeric)
            WHEN rr.position_number IS NOT NULL AND w.winner_time_millis IS NOT NULL THEN (w.winner_time_millis::numeric / rr.laps::numeric)
            ELSE NULL
        END AS avg_lap_ms,
        fl.fastest_lap_time_millis
    FROM wet_races wr
    JOIN formula1.race_result rr ON rr.race_id = wr.race_id
    JOIN team_segment ts ON ts.constructor_id = rr.constructor_id
    LEFT JOIN race_winners w ON w.race_id = wr.race_id
    LEFT JOIN formula1.race_data fl 
           ON fl.race_id = wr.race_id 
          AND fl.driver_id = rr.driver_id 
          AND fl.type = 'FASTEST_LAP'
    WHERE rr.tyre_manufacturer_id IN ('michelin', 'bridgestone')
      AND (rr.position_number IS NOT NULL OR rr.laps >= 20)
),
best_per_brand AS (
    SELECT 
        dp.*,
        ROW_NUMBER() OVER (
            PARTITION BY race_id, id_segmento, tyre_manufacturer_id 
            ORDER BY 
                CASE WHEN position_number IS NOT NULL THEN position_number ELSE 999 END ASC,
                COALESCE(avg_lap_ms, 99999999) ASC
        ) as rn
    FROM driver_pace dp
    WHERE avg_lap_ms IS NOT NULL
)
SELECT 
    m.race_id,
    m.year,
    m.round,
    m.grand_prix,
    m.circuit_id,
    m.id_segmento,
    m.precipitation_total_mm,
    m.driver_id AS piloto_michelin,
    m.constructor_id AS equipo_michelin,
    ROUND((m.avg_lap_ms / 1000.0), 3) AS tiempo_promedio_vuelta_michelin_sec,
    b.driver_id AS piloto_bridgestone,
    b.constructor_id AS equipo_bridgestone,
    ROUND((b.avg_lap_ms / 1000.0), 3) AS tiempo_promedio_vuelta_bridgestone_sec,
    ROUND(((m.avg_lap_ms - b.avg_lap_ms) / 1000.0), 3) AS diferencia_sec,
    ROUND((((m.avg_lap_ms - b.avg_lap_ms) / b.avg_lap_ms) * 100.0), 2) AS pct_diferencia,
    CASE 
        WHEN m.avg_lap_ms < b.avg_lap_ms THEN 'michelin'
        ELSE 'bridgestone'
    END AS proveedor_mas_rapido,
    ROUND((m.fastest_lap_time_millis / 1000.0), 3) AS mejor_vuelta_michelin_sec,
    ROUND((b.fastest_lap_time_millis / 1000.0), 3) AS mejor_vuelta_bridgestone_sec,
    ROUND(((m.fastest_lap_time_millis - b.fastest_lap_time_millis) / 1000.0), 3) AS diferencia_mejor_vuelta_sec
FROM best_per_brand m
JOIN best_per_brand b 
  ON m.race_id = b.race_id 
 AND m.id_segmento = b.id_segmento
 AND b.tyre_manufacturer_id = 'bridgestone' 
 AND b.rn = 1
WHERE m.tyre_manufacturer_id = 'michelin' 
  AND m.rn = 1
ORDER BY m.id_segmento, m.year, m.round;


-- =========================================================================
-- VISTA 2: Resumen de Rendimiento en Lluvia por Segmento de Escudería
-- =========================================================================
CREATE VIEW formula1.v_resumen_rendimiento_lluvia AS
SELECT 
    id_segmento,
    COUNT(*) AS total_carreras_lluvia,
    ROUND(AVG(tiempo_promedio_vuelta_michelin_sec), 3) AS tiempo_promedio_michelin_en_lluvia,
    ROUND(AVG(tiempo_promedio_vuelta_bridgestone_sec), 3) AS tiempo_promedio_bridgestone_en_lluvia,
    ROUND(AVG(diferencia_sec), 3) AS diferencia,
    ROUND(AVG(pct_diferencia), 2) AS pct_diferencia,
    CASE 
        WHEN AVG(diferencia_sec) < 0 THEN 'Michelin fue mas veloz (-' || ABS(ROUND(AVG(pct_diferencia), 2)) || '%)'
        ELSE 'Bridgestone fue mas veloz (+' || ROUND(AVG(pct_diferencia), 2) || '%)'
    END AS veredicto_ritmo_lluvia,
    COUNT(CASE WHEN proveedor_mas_rapido = 'michelin' THEN 1 END) AS victorias_michelin,
    COUNT(CASE WHEN proveedor_mas_rapido = 'bridgestone' THEN 1 END) AS victorias_bridgestone
FROM formula1.v_analisis_rendimiento_lluvia_carreras
GROUP BY id_segmento;


-- =========================================================================
-- VISTA 3: Caída de rendimiento Seco vs Lluvia por Segmento
-- =========================================================================
CREATE VIEW formula1.v_caida_rendimiento_seco_vs_lluvia AS
WITH all_races_pace AS (
    SELECT 
        r.id AS race_id,
        r.year,
        COALESCE(rw.is_wet_race, false) AS is_wet,
        rr.tyre_manufacturer_id,
        ts.id_segmento,
        CASE 
            WHEN rr.time_millis IS NOT NULL THEN (rr.time_millis::numeric / rr.laps::numeric)
            WHEN rr.position_number IS NOT NULL AND w.winner_time_millis IS NOT NULL THEN (w.winner_time_millis::numeric / rr.laps::numeric)
            ELSE NULL
        END AS avg_lap_ms,
        ROW_NUMBER() OVER (
            PARTITION BY r.id, ts.id_segmento, rr.tyre_manufacturer_id 
            ORDER BY rr.position_number ASC
        ) AS rn
    FROM formula1.race r
    LEFT JOIN formula1.race_weather rw ON rw.race_id = r.id
    JOIN formula1.race_result rr ON rr.race_id = r.id
    JOIN (
        SELECT id AS constructor_id,
            CASE 
                WHEN id IN ('ferrari', 'renault', 'mclaren') THEN 'top_tier'
                WHEN id IN ('williams', 'toyota', 'bar', 'sauber', 'red-bull', 'red_bull', 'jaguar') THEN 'midfield'
                ELSE 'backmarker'
            END AS id_segmento
        FROM formula1.constructor
    ) ts ON ts.constructor_id = rr.constructor_id
    LEFT JOIN (
        SELECT race_id, time_millis AS winner_time_millis 
        FROM formula1.race_result WHERE position_number = 1
    ) w ON w.race_id = r.id
    WHERE r.year BETWEEN 2001 AND 2005
      AND rr.tyre_manufacturer_id IN ('michelin', 'bridgestone')
      AND (rr.position_number IS NOT NULL OR rr.laps > 20)
),
race_pairs AS (
    SELECT 
        m.race_id,
        m.year,
        m.is_wet,
        m.id_segmento,
        (m.avg_lap_ms / 1000.0) AS m_sec,
        (b.avg_lap_ms / 1000.0) AS b_sec,
        ((m.avg_lap_ms - b.avg_lap_ms) / 1000.0) AS diff_sec,
        (((m.avg_lap_ms - b.avg_lap_ms) / b.avg_lap_ms) * 100.0) AS pct_gap
    FROM all_races_pace m
    JOIN all_races_pace b 
      ON m.race_id = b.race_id 
     AND m.id_segmento = b.id_segmento
     AND b.tyre_manufacturer_id = 'bridgestone' 
     AND b.rn = 1
    WHERE m.tyre_manufacturer_id = 'michelin' 
      AND m.rn = 1
)
SELECT 
    id_segmento,
    CASE WHEN is_wet THEN 'Lluvia (Wet = True)' ELSE 'Seco (Wet = False)' END AS condicion,
    is_wet,
    COUNT(*) AS total_carreras,
    ROUND(AVG(m_sec), 3) AS tiempo_promedio_michelin_sec,
    ROUND(AVG(b_sec), 3) AS tiempo_promedio_bridgestone_sec,
    ROUND(AVG(diff_sec), 3) AS diferencia_promedio_seg,
    ROUND(AVG(pct_gap), 2) AS pct_diferencia
FROM race_pairs
GROUP BY id_segmento, is_wet
ORDER BY id_segmento, is_wet DESC;
