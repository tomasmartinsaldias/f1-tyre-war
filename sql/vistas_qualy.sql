CREATE OR REPLACE VIEW formula1.v_f1_qualy_granular AS
WITH qualy_base AS (
    SELECT 
        r.year,
        r.round,
        r.id AS race_id,
        r.official_name AS grand_prix,
        r.circuit_type,
        qr.driver_id,
        qr.constructor_id,
        qr.tyre_manufacturer_id,
        qr.position_number AS qualy_position,
        qr.time_millis,
        MIN(qr.time_millis) OVER (PARTITION BY qr.race_id) AS pole_time_millis
    FROM formula1.qualifying_result qr
    INNER JOIN formula1.race r ON r.id = qr.race_id
    WHERE r.year BETWEEN 2001 AND 2005
      AND qr.time_millis IS NOT NULL 
      AND qr.time_millis > 0
      -- Excluir la distorsión de Indianápolis 2005
      AND NOT (r.year = 2005 AND r.official_name ILIKE '%United States%')
)
SELECT 
    year,
    round,
    race_id,
    grand_prix,
    circuit_type,
    driver_id,
    constructor_id,
    tyre_manufacturer_id,
    qualy_position,
    time_millis,
    pole_time_millis,
    ROUND((time_millis - pole_time_millis) / 1000.0, 3) AS gap_to_pole_sec,
    ROUND(((time_millis - pole_time_millis)::numeric / pole_time_millis::numeric) * 100.0, 3) AS pct_gap_to_pole,
    -- Flag técnico para filtrar fácilmente el 107%
    CASE 
        WHEN ((time_millis - pole_time_millis)::numeric / pole_time_millis::numeric) * 100.0 <= 7.0 THEN TRUE 
        ELSE FALSE 
    END AS is_within_107
FROM qualy_base;

CREATE OR REPLACE VIEW formula1.v_f1_race_granular AS
SELECT 
    r.year,
    r.round,
    r.id AS race_id,
    r.official_name AS grand_prix,
    r.circuit_type,
    rr.driver_id,
    rr.constructor_id,
    rr.tyre_manufacturer_id,
    rr.grid_position_number,
    rr.position_number AS finish_position,
    rr.position_text,
    rr.positions_gained,
    rr.points,
    rr.fastest_lap,
    CASE 
        WHEN rr.position_text IN ('DNF', 'DNS', 'DSQ') THEN FALSE 
        ELSE TRUE 
    END AS is_finished
FROM formula1.race_result rr
INNER JOIN formula1.race r ON r.id = rr.race_id
WHERE r.year BETWEEN 2001 AND 2005
  -- Excluir la distorsión de Indianápolis 2005
  AND NOT (r.year = 2005 AND r.official_name ILIKE '%United States%');