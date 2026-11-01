SET search_path TO formula1, public;

-- =========================================================================
-- VISTA 1: Temporadas de uso por proveedor de neumáticos por constructor (2001-2005)
-- Cuenta cuántas temporadas usó cada marca Michelin y/o Bridgestone
-- =========================================================================
DROP VIEW IF EXISTS formula1.v_temporadas_proveedor_marca CASCADE;

CREATE VIEW formula1.v_temporadas_proveedor_marca AS
WITH base AS (
    SELECT DISTINCT
        c.id AS constructor_id,
        c.name AS constructor_name,
        r.year,
        rd.tyre_manufacturer_id
    FROM formula1.constructor c
    JOIN formula1.race_data rd ON rd.constructor_id = c.id
    JOIN formula1.race r ON r.id = rd.race_id
    WHERE r.year BETWEEN 2001 AND 2005
      AND rd.tyre_manufacturer_id IN ('michelin', 'bridgestone')
)
SELECT 
    constructor_id,
    constructor_name,
    COUNT(DISTINCT CASE WHEN tyre_manufacturer_id = 'michelin' THEN year END) AS temporadas_michelin,
    COUNT(DISTINCT CASE WHEN tyre_manufacturer_id = 'bridgestone' THEN year END) AS temporadas_bridgestone,
    COUNT(DISTINCT year) AS total_temporadas,
    COALESCE(STRING_AGG(DISTINCT year::text, ', ' ORDER BY year::text) FILTER (WHERE tyre_manufacturer_id = 'michelin'), 'Ninguna') AS anios_michelin,
    COALESCE(STRING_AGG(DISTINCT year::text, ', ' ORDER BY year::text) FILTER (WHERE tyre_manufacturer_id = 'bridgestone'), 'Ninguna') AS anios_bridgestone
FROM base
GROUP BY constructor_id, constructor_name
ORDER BY constructor_name;


-- =========================================================================
-- VISTA 1 COMPLEMENTARIA: Cuota y % de la parrilla por año (2001-2005)
-- Cada observación es un año, calculando el % de equipos y de autos en grilla por proveedor
-- =========================================================================
DROP VIEW IF EXISTS formula1.v_cuota_parrilla_anual_neumaticos CASCADE;

CREATE VIEW formula1.v_cuota_parrilla_anual_neumaticos AS
WITH por_carrera AS (
    SELECT 
        r.year,
        r.id AS race_id,
        rd.constructor_id,
        rd.tyre_manufacturer_id,
        rd.driver_id
    FROM formula1.race r
    JOIN formula1.race_data rd ON rd.race_id = r.id
    WHERE r.year BETWEEN 2001 AND 2005
      AND rd.type = 'STARTING_GRID_POSITION'
      AND rd.tyre_manufacturer_id IN ('michelin', 'bridgestone')
),
equipos_anio AS (
    SELECT 
        year,
        COUNT(DISTINCT constructor_id) AS total_equipos,
        COUNT(DISTINCT CASE WHEN tyre_manufacturer_id = 'michelin' THEN constructor_id END) AS equipos_michelin,
        COUNT(DISTINCT CASE WHEN tyre_manufacturer_id = 'bridgestone' THEN constructor_id END) AS equipos_bridgestone
    FROM por_carrera
    GROUP BY year
),
autos_anio AS (
    SELECT 
        year,
        COUNT(*) AS total_autos_grilla,
        COUNT(CASE WHEN tyre_manufacturer_id = 'michelin' THEN 1 END) AS autos_michelin,
        COUNT(CASE WHEN tyre_manufacturer_id = 'bridgestone' THEN 1 END) AS autos_bridgestone
    FROM por_carrera
    GROUP BY year
)
SELECT 
    e.year,
    e.total_equipos,
    e.equipos_michelin,
    e.equipos_bridgestone,
    ROUND((e.equipos_michelin::numeric / e.total_equipos::numeric) * 100.0, 2) AS pct_equipos_michelin,
    ROUND((e.equipos_bridgestone::numeric / e.total_equipos::numeric) * 100.0, 2) AS pct_equipos_bridgestone,
    a.total_autos_grilla,
    a.autos_michelin,
    a.autos_bridgestone,
    ROUND((a.autos_michelin::numeric / a.total_autos_grilla::numeric) * 100.0, 2) AS pct_parrilla_michelin,
    ROUND((a.autos_bridgestone::numeric / a.total_autos_grilla::numeric) * 100.0, 2) AS pct_parrilla_bridgestone
FROM equipos_anio e
JOIN autos_anio a ON a.year = e.year
ORDER BY e.year;


-- =========================================================================
-- VISTA 2: Acumulación progresiva de Pole Positions carrera por carrera (2001-2005)
-- Incluye todos los circuitos del calendario y las columnas Poles_Michelin y Poles_bridgestone
-- =========================================================================
DROP VIEW IF EXISTS formula1.v_acumulacion_poles_carreras CASCADE;

CREATE VIEW formula1.v_acumulacion_poles_carreras AS
WITH pole_data AS (
    SELECT 
        r.id AS race_id,
        r.year,
        r.round,
        r.date,
        r.official_name AS grand_prix,
        r.circuit_id,
        rd.driver_id AS pole_driver_id,
        rd.constructor_id AS pole_constructor_id,
        rd.tyre_manufacturer_id AS pole_tyre
    FROM formula1.race r
    JOIN formula1.race_data rd ON rd.race_id = r.id
    WHERE r.year BETWEEN 2001 AND 2005
      AND rd.type = 'STARTING_GRID_POSITION'
      AND rd.position_number = 1
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY year, round) AS numero_carrera_acumulado,
    race_id,
    year,
    round,
    date,
    grand_prix,
    circuit_id,
    pole_driver_id,
    pole_constructor_id,
    pole_tyre,
    SUM(CASE WHEN pole_tyre = 'michelin' THEN 1 ELSE 0 END) OVER (
        ORDER BY year, round 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS "Poles_Michelin",
    SUM(CASE WHEN pole_tyre = 'bridgestone' THEN 1 ELSE 0 END) OVER (
        ORDER BY year, round 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS "Poles_bridgestone"
FROM pole_data
ORDER BY year, round;
