SET search_path TO formula1, public;

CREATE OR REPLACE VIEW formula1.v_analisis_fiabilidad_neumaticos AS
WITH race_scope AS (
    SELECT 
        r.id AS race_id,
        r.year
    FROM formula1.race r
    WHERE r.year BETWEEN 2001 AND 2005
),
categorized_retirements AS (
    SELECT 
        rs.year,
        rr.constructor_id,
        rr.tyre_manufacturer_id,
        rr.laps,
        CASE 
            WHEN rr.reason_retired IN ('Tyre', 'Puncture', 'Wheel rim') 
                THEN 'Tyre/Wheel Failure'
            
            WHEN rr.reason_retired IN ('Collision', 'Collision damage', 'Caused collision with Trulli', 
                                      'Accident', 'Spun off', 'Spin') 
                THEN 'Accident/Collision'
            
            WHEN rr.reason_retired IN ('Withdrew', 'Safety concerns') 
                THEN 'Withdrawal / Safety'
            
            WHEN rr.reason_retired IS NOT NULL 
                THEN 'Car Mechanical / Technical'
            
            ELSE 'Finished / Classified'
        END AS dnf_category
    FROM formula1.race_result rr
    JOIN race_scope rs ON rr.race_id = rs.race_id
    WHERE rr.tyre_manufacturer_id IN ('bridgestone', 'michelin')
)
SELECT 
    year,
    constructor_id,
    tyre_manufacturer_id,
    COUNT(*) AS total_race_entries,
    SUM(laps) AS total_laps_completed,
    
    COUNT(CASE WHEN dnf_category = 'Tyre/Wheel Failure' THEN 1 END) AS tyre_dnfs,
    COUNT(CASE WHEN dnf_category = 'Accident/Collision' THEN 1 END) AS accident_dnfs,
    COUNT(CASE WHEN dnf_category = 'Withdrawal / Safety' THEN 1 END) AS withdrawal_dnfs,
    COUNT(CASE WHEN dnf_category = 'Car Mechanical / Technical' THEN 1 END) AS mechanical_dnfs,
    COUNT(CASE WHEN dnf_category = 'Finished / Classified' THEN 1 END) AS finished_races
FROM categorized_retirements
GROUP BY year, constructor_id, tyre_manufacturer_id;