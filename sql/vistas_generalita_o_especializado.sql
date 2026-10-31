SET search_path TO formula1, public;

-- VISTA 1: Rendimiento General Carrera vs Qualy
CREATE OR REPLACE VIEW formula1.v_analisis_rendimiento_anual AS
WITH race_scope AS (
    SELECT id AS race_id, year
    FROM formula1.race
    WHERE year BETWEEN 2001 AND 2005
),
team_performance AS (
    SELECT 
        rs.year,
        rr.constructor_id,
        rr.tyre_manufacturer_id,
        rr.qualification_position_number,
        rr.grid_position_number,
        rr.position_number AS final_position,
        rr.positions_gained,
        rr.points
    FROM formula1.race_result rr
    JOIN race_scope rs ON rr.race_id = rs.race_id
    WHERE rr.constructor_id IN ('ferrari', 'mclaren', 'bar', 'sauber', 'jordan')
      AND rr.tyre_manufacturer_id IN ('bridgestone', 'michelin')
)
SELECT 
    constructor_id,
    year,
    tyre_manufacturer_id,
    COUNT(*) AS entries,
    ROUND(AVG(qualification_position_number)::numeric, 2) AS avg_qualy_pos,
    ROUND(AVG(final_position)::numeric, 2) AS avg_finish_pos,
    ROUND(AVG(positions_gained)::numeric, 2) AS avg_positions_gained,
    SUM(points) AS total_points
FROM team_performance
GROUP BY constructor_id, year, tyre_manufacturer_id;


-- VISTA 2: Asimetría y Brecha con el Líder de Marca (Efecto Ferrari)
CREATE OR REPLACE VIEW formula1.v_analisis_asimetria_marca AS
WITH race_scope AS (
    SELECT id AS race_id, year 
    FROM formula1.race 
    WHERE year BETWEEN 2001 AND 2005
),
qualy_data AS (
    SELECT 
        rs.year,
        rr.race_id,
        rr.constructor_id,
        rr.tyre_manufacturer_id,
        rr.qualification_position_number AS qualy_pos
    FROM formula1.race_result rr
    JOIN race_scope rs ON rr.race_id = rs.race_id
    WHERE rr.qualification_position_number IS NOT NULL
      AND rr.tyre_manufacturer_id IN ('bridgestone', 'michelin')
),
brand_benchmarks AS (
    SELECT 
        race_id,
        tyre_manufacturer_id,
        MIN(qualy_pos) AS best_brand_qualy
    FROM qualy_data
    GROUP BY race_id, tyre_manufacturer_id
)
SELECT 
    q.year,
    q.tyre_manufacturer_id,
    q.constructor_id,
    COUNT(*) AS total_entries,
    ROUND(AVG(q.qualy_pos - b.best_brand_qualy)::numeric, 2) AS avg_gap_to_brand_leader
FROM qualy_data q
JOIN brand_benchmarks b 
  ON q.race_id = b.race_id 
 AND q.tyre_manufacturer_id = b.tyre_manufacturer_id
WHERE q.constructor_id IN ('ferrari', 'jordan', 'sauber', 'mclaren', 'williams', 'renault', 'bar')
GROUP BY q.year, q.tyre_manufacturer_id, q.constructor_id;