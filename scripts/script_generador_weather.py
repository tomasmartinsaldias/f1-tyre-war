#!/usr/bin/env python3
"""
script_generador_weather.py
Pipeline ETL de Enriquecimiento Climático para Fórmula 1 (2000-2005)
Consulta Open-Meteo Historical Weather API (ERA5 Reanalysis) y genera el archivo SQL
para poblar la tabla formula1.race_weather.

Uso:
    python script_generador_weather.py
    python script_generador_weather.py --help
"""

import sys
import os
import time
import argparse
from pathlib import Path
import psycopg2
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Configuración por defecto de la base de datos (PostgreSQL)
DEFAULT_DB_CONFIG = {
    "host": os.getenv("PGHOST", "localhost"),
    "port": int(os.getenv("PGPORT", "5432")),
    "dbname": os.getenv("PGDATABASE", "postgres"),
    "user": os.getenv("PGUSER", "postgres"),
    "password": os.getenv("PGPASSWORD", "postgresql"),
    "options": "-c search_path=formula1"
}

WEATHER_API_URL = "https://archive-api.open-meteo.com/v1/archive"
# Códigos WMO considerados condiciones de lluvia / pista mojada:
# Drizzle (51, 53, 55), Freezing Drizzle (56, 57), Rain (61, 63, 65),
# Freezing Rain (66, 67), Rain Showers (80, 81, 82), Thunderstorm (95, 96, 99)
WMO_WET_CODES = {51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99}


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Pipeline ETL: Enriquecimiento Climático F1 (2000-2005) vía Open-Meteo ERA5"
    )
    parser.add_argument(
        "--scripts-dir", "-d",
        type=Path,
        default=None,
        help="Directorio de scripts SQL de la cátedra (donde se ubica 00_estructura.sql)"
    )
    parser.add_argument(
        "--output", "-o",
        type=Path,
        default=None,
        help="Ruta destino del archivo 45_race_weather.sql generado"
    )
    parser.add_argument(
        "--skip-patch",
        action="store_true",
        help="Omitir el parche de 00_estructura.sql si la tabla ya fue creada o se maneja por separado"
    )
    parser.add_argument("--host", default=DEFAULT_DB_CONFIG["host"], help="Host PostgreSQL (def: localhost)")
    parser.add_argument("--port", type=int, default=DEFAULT_DB_CONFIG["port"], help="Puerto PostgreSQL (def: 5432)")
    parser.add_argument("--dbname", default=DEFAULT_DB_CONFIG["dbname"], help="Base de datos (def: postgres)")
    parser.add_argument("--user", default=DEFAULT_DB_CONFIG["user"], help="Usuario PostgreSQL (def: postgres)")
    parser.add_argument("--password", default=DEFAULT_DB_CONFIG["password"], help="Contraseña PostgreSQL (def: postgresql)")
    parser.add_argument("--schema", default="formula1", help="Esquema PostgreSQL (def: formula1)")
    return parser.parse_args()


def resolve_paths(args):
    """Resuelve la ubicación de 00_estructura.sql y 45_race_weather.sql."""
    current_dir = Path(__file__).resolve().parent
    repo_root = current_dir.parent

    # Candidatos para 00_estructura.sql
    candidates_estructura = []
    if args.scripts_dir:
        candidates_estructura.append(args.scripts_dir / "00_estructura.sql")
    candidates_estructura.extend([
        current_dir / "00_estructura.sql",
        repo_root / "sql" / "00_estructura.sql",
        # Ruta estándar del curso de BD si existe en el entorno
        Path(r"C:\Users\Franc\Documents\Facultad\2026\Bases de Datos\FI BD-LCD 2026 Tema 05 - SQL Practica - F1\FI BD-LCD 2026 Tema 05 - SQL Practica - F1\scripts\00_estructura.sql")
    ])

    file_estructura = None
    for cand in candidates_estructura:
        if cand.exists():
            file_estructura = cand
            break

    # Ruta de salida para 45_race_weather.sql
    if args.output:
        file_output = args.output
    elif file_estructura:
        file_output = file_estructura.parent / "45_race_weather.sql"
    else:
        file_output = current_dir / "45_race_weather.sql"

    return file_estructura, file_output


def step_1_patch_estructura_sql(file_estructura, skip_patch=False):
    """
    PASO 1: Asegura que 00_estructura.sql incluya DROP TABLE IF EXISTS "race_weather";
    antes de borrar "race", evitando errores de Foreign Key al re-ejecutar cargar_todo.bat.
    """
    print("\n[PASO 1/5] Verificando orden de DROP TABLE en 00_estructura.sql...")
    if skip_patch:
        print("  -> Omitido por bandera --skip-patch.")
        return

    if not file_estructura or not file_estructura.exists():
        print("  [AVISO] No se localizó 00_estructura.sql en la carpeta actual. Si ya creaste")
        print("          la tabla race_weather en PostgreSQL, este paso no es bloqueante.")
        print("          Usa --scripts-dir para especificar la ruta si deseas parcharlo.")
        return

    content = file_estructura.read_text(encoding="utf-8")
    if 'DROP TABLE IF EXISTS "race_weather";' not in content:
        target = 'DROP TABLE IF EXISTS "race_constructor_standing";'
        if target in content:
            content = content.replace(
                target,
                'DROP TABLE IF EXISTS "race_weather";\n' + target,
                1
            )
            file_estructura.write_text(content, encoding="utf-8")
            print(f'  -> Parche aplicado en {file_estructura.name}: Agregado DROP TABLE IF EXISTS "race_weather";')
        else:
            print("  -> No se encontró el marcador de reemplazo en 00_estructura.sql. Continuando...")
    else:
        print(f"  -> 00_estructura.sql ya contiene la cláusula de DROP TABLE para race_weather.")

    print("  [OK] Paso 1 superado: 00_estructura.sql listo para múltiples ejecuciones.")


def step_2_fetch_races_from_postgres(db_config):
    """
    PASO 2: Conecta a PostgreSQL y extrae las carreras (2000-2005) cruzando
    race.circuit_id = circuit.id con las coordenadas geográficas (c.latitude, c.longitude).
    """
    print("\n[PASO 2/5] Consultando carreras (2000-2005) y coordenadas en PostgreSQL...")
    conn = psycopg2.connect(**db_config)
    cur = conn.cursor()

    cur.execute("""
        SELECT 
            r.id AS race_id,
            r.year,
            r.round,
            r.date,
            r.official_name,
            r.circuit_id,
            c.latitude,
            c.longitude
        FROM race r
        INNER JOIN circuit c ON r.circuit_id = c.id
        WHERE r.year BETWEEN 2000 AND 2005
        ORDER BY r.year ASC, r.round ASC;
    """)
    races = cur.fetchall()
    cur.close()
    conn.close()

    assert len(races) > 0, "La consulta no devolvió carreras. Verifica que circuit y race estén cargados en PostgreSQL."
    for race_id, year, rnd, r_date, name, cid, lat, lng in races:
        assert -90.0 <= float(lat) <= 90.0, f"Latitud inválida en {cid}: {lat}"
        assert -180.0 <= float(lng) <= 180.0, f"Longitud inválida en {cid}: {lng}"

    print(f"  [OK] Paso 2 superado: {len(races)} carreras recuperadas desde PostgreSQL.")
    return races


def create_http_session():
    """Sesión HTTP con reintentos automáticos y backoff ante caídas o límites de tasa (429/5xx)."""
    session = requests.Session()
    retry = Retry(
        total=5,
        backoff_factor=1.0,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["GET"]
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    return session


def step_3_test_api_connection(session, sample_race):
    """
    PASO 3: Verifica que Open-Meteo ERA5 responda un JSON válido de 24 horas.
    """
    print("\n[PASO 3/5] Probando conexión con Open-Meteo Historical API...")
    race_id, year, rnd, r_date, name, cid, lat, lng = sample_race
    params = {
        "latitude": float(lat),
        "longitude": float(lng),
        "start_date": str(r_date),
        "end_date": str(r_date),
        "timezone": "auto",
        "hourly": ["temperature_2m", "relative_humidity_2m", "precipitation", "wind_speed_10m", "weather_code"]
    }
    resp = session.get(WEATHER_API_URL, params=params, timeout=20)
    resp.raise_for_status()
    data = resp.json()

    assert "hourly" in data and len(data["hourly"].get("temperature_2m", [])) == 24, "Respuesta incompleta de Open-Meteo."
    print(f"  [OK] Paso 3 superado: API operativa (Test exitoso en {name} - {r_date}).")


def step_4_download_weather(session, races):
    """
    PASO 4: Descarga y valida los datos meteorológicos para todas las carreras (ventana 12:00 a 17:00).
    """
    print("\n[PASO 4/5] Extrayendo datos climáticos (ventana local 12:00 a 17:00 hs)...")
    records = []

    for idx, (race_id, year, rnd, r_date, name, cid, lat, lng) in enumerate(races, start=1):
        params = {
            "latitude": float(lat),
            "longitude": float(lng),
            "start_date": str(r_date),
            "end_date": str(r_date),
            "timezone": "auto",
            "hourly": [
                "temperature_2m",
                "relative_humidity_2m",
                "precipitation",
                "wind_speed_10m",
                "weather_code"
            ]
        }

        resp = session.get(WEATHER_API_URL, params=params, timeout=20)
        resp.raise_for_status()
        hourly = resp.json().get("hourly", {})

        # Filtrar ventana de carrera (12:00 a 17:00 hora local del circuito, índices 12 a 17 inclusive)
        temps = [v for v in hourly.get("temperature_2m", [])[12:18] if v is not None]
        hums = [v for v in hourly.get("relative_humidity_2m", [])[12:18] if v is not None]
        precips = [v for v in hourly.get("precipitation", [])[12:18] if v is not None]
        winds = [v for v in hourly.get("wind_speed_10m", [])[12:18] if v is not None]
        codes = [int(v) for v in hourly.get("weather_code", [])[12:18] if v is not None]

        temp_avg = round(sum(temps) / len(temps), 1) if temps else 0.0
        temp_max = round(max(temps), 1) if temps else 0.0
        temp_min = round(min(temps), 1) if temps else 0.0
        hum_avg = round(sum(hums) / len(hums), 1) if hums else 0.0
        precip_tot = round(sum(precips), 2) if precips else 0.0
        wind_max = round(max(winds), 1) if winds else 0.0
        dominant_wmo = max(set(codes), key=codes.count) if codes else 0
        is_wet = (precip_tot > 0.5) or (dominant_wmo in WMO_WET_CODES)

        records.append({
            "race_id": race_id,
            "temp_avg": temp_avg,
            "temp_max": temp_max,
            "temp_min": temp_min,
            "hum_avg": hum_avg,
            "precip_tot": precip_tot,
            "wind_max": wind_max,
            "wmo": dominant_wmo,
            "is_wet": "TRUE" if is_wet else "FALSE"
        })

        print(
            f"  [{idx:03d}/{len(races):03d}] {year} R{rnd:02d} | race_id={race_id} ({cid}) | "
            f"Temp: {temp_avg}°C | Lluvia: {precip_tot}mm | Wet: {is_wet}"
        )
        time.sleep(0.12)  # Pausa breve para respetar las cuotas de la API pública

    assert len(records) == len(races), "No se procesaron todas las carreras."
    print(f"  [OK] Paso 4 superado: {len(records)} registros climáticos validados.")
    return records


def step_5_write_sql_file(records, file_output):
    """
    PASO 5: Escribe 45_race_weather.sql y comprueba que contenga todos los INSERTs.
    """
    print(f"\n[PASO 5/5] Generando archivo {file_output.name}...")
    file_output.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "-- 45_race_weather.sql\n",
        "-- Enriquecimiento climatico F1 (2000-2005) - Open-Meteo ERA5\n",
        "TRUNCATE TABLE \"race_weather\" RESTART IDENTITY;\n\n"
    ]

    for r in records:
        stmt = (
            f"INSERT INTO \"race_weather\" ("
            f"\"race_id\", \"air_temp_avg\", \"air_temp_max\", \"air_temp_min\", "
            f"\"relative_humidity_pct\", \"precipitation_total_mm\", \"wind_speed_max_kmh\", "
            f"\"weather_code\", \"is_wet_race\", \"source\""
            f") VALUES ("
            f"{r['race_id']}, {r['temp_avg']}, {r['temp_max']}, {r['temp_min']}, "
            f"{r['hum_avg']}, {r['precip_tot']}, {r['wind_max']}, "
            f"{r['wmo']}, {r['is_wet']}, 'Open-Meteo ERA5'"
            f");\n"
        )
        lines.append(stmt)

    file_output.write_text("".join(lines), encoding="utf-8")

    written_text = file_output.read_text(encoding="utf-8")
    count = written_text.count('INSERT INTO "race_weather"')
    assert count == len(records), f"Error de escritura: {count} INSERTs vs {len(records)} esperados."
    print(f"  [OK] Paso 5 superado: {file_output.resolve()} generado con {count} registros.")

    # Sincronización automática opcional: si existe sql/ en el repo, guardamos una copia allí también
    repo_sql = Path(__file__).resolve().parent.parent / "sql" / "45_race_weather.sql"
    if repo_sql.parent.exists() and file_output.resolve() != repo_sql.resolve():
        repo_sql.write_text("".join(lines), encoding="utf-8")
        print(f"  -> Sincronizado adicionalmente con: {repo_sql.resolve()}")


def main():
    args = parse_arguments()
    db_config = {
        "host": args.host,
        "port": args.port,
        "dbname": args.dbname,
        "user": args.user,
        "password": args.password,
        "options": f"-c search_path={args.schema}"
    }

    file_estructura, file_output = resolve_paths(args)

    print("=" * 65)
    print(" PIPELINE CLIMÁTICO F1 (2000-2005) -> POSTGRESQL")
    print(f" Servidor: {db_config['host']}:{db_config['port']} | DB: {db_config['dbname']} | Esquema: {args.schema}")
    print("=" * 65)

    try:
        step_1_patch_estructura_sql(file_estructura, skip_patch=args.skip_patch)
        races = step_2_fetch_races_from_postgres(db_config)
        session = create_http_session()
        step_3_test_api_connection(session, races[0])
        records = step_4_download_weather(session, races)
        step_5_write_sql_file(records, file_output)
        print("\n" + "=" * 65)
        print(" LISTO: Carga el script SQL generado en PostgreSQL:")
        print(f"   psql -h {db_config['host']} -U {db_config['user']} -d {db_config['dbname']} -f {file_output.name}")
        print(" o ejecuta .\\cargar_todo.bat si estás en la carpeta de la cátedra.")
        print("=" * 65)
    except Exception as e:
        print(f"\n[ERROR EN PIPELINE]: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
