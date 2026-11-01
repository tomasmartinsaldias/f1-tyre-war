-- =========================================================================
-- DDL: Estructura de la tabla "race_weather" (Enriquecimiento Climático F1)
-- Base de datos: PostgreSQL - Esquema: formula1
-- =========================================================================

SET search_path TO formula1, public;

CREATE TABLE IF NOT EXISTS formula1.race_weather (
    race_weather_id SERIAL PRIMARY KEY,
    race_id INT NOT NULL,
    air_temp_avg NUMERIC(4, 1),           -- Temperatura media (°C) en ventana 12:00-17:00
    air_temp_max NUMERIC(4, 1),           -- Temperatura máxima (°C)
    air_temp_min NUMERIC(4, 1),           -- Temperatura mínima (°C)
    relative_humidity_pct NUMERIC(4, 1),  -- Humedad relativa promedio (%)
    precipitation_total_mm NUMERIC(5, 2), -- Precipitación acumulada (mm)
    wind_speed_max_kmh NUMERIC(4, 1),     -- Ráfaga / viento máximo (km/h)
    weather_code INT,                     -- Código meteorológico WMO dominante
    is_wet_race BOOLEAN DEFAULT FALSE,    -- Flag de carrera en mojado (precip > 0.5mm o WMO wet)
    source VARCHAR(50) DEFAULT 'Open-Meteo ERA5',
    CONSTRAINT fk_race_weather_race 
        FOREIGN KEY (race_id) 
        REFERENCES formula1.race(id) 
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_race_weather_race_id ON formula1.race_weather(race_id);
