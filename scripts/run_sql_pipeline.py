#!/usr/bin/env python3
"""
Pipeline de Ejecución SQL: F1 Tyre War (2000-2005)
Ejecuta secuencialmente la creación de tablas, ingesta de datos climáticos
y definición de todas las vistas analíticas en PostgreSQL (esquema formula1).
"""

import sys
import os
import argparse
from pathlib import Path
import psycopg2

SQL_PIPELINE = [
    {
        "file": "ddl_race_weather.sql",
        "description": "DDL tabla formula1.race_weather (clima)",
        "check": "SELECT count(*) FROM formula1.race_weather",
        "entity": "formula1.race_weather"
    },
    {
        "file": "45_race_weather.sql",
        "description": "Datos historicos de clima ERA5 (104 GPs)",
        "check": "SELECT count(*) FROM formula1.race_weather WHERE is_wet_race IS NOT NULL",
        "entity": "formula1.race_weather (datos)"
    },
    {
        "file": "vistas_temporadas_y_acumulacion_poles.sql",
        "description": "Vistas de cuota de parrilla y acumulacion de poles",
        "check": "SELECT count(*) FROM formula1.v_acumulacion_poles_carreras",
        "entity": "formula1.v_acumulacion_poles_carreras"
    },
    {
        "file": "vistas_qualy.sql",
        "description": "Vistas granulares de qualy y carrera",
        "check": "SELECT count(*) FROM formula1.v_f1_qualy_granular",
        "entity": "formula1.v_f1_qualy_granular"
    },
    {
        "file": "vistas_generalita_o_especializado.sql",
        "description": "Vistas de rendimiento anual y asimetria de marca",
        "check": "SELECT count(*) FROM formula1.v_analisis_asimetria_marca",
        "entity": "formula1.v_analisis_asimetria_marca"
    },
    {
        "file": "vistas_rendimiento_circuitos.sql",
        "description": "Vistas de circuitos rapidos vs lentos",
        "check": "SELECT count(*) FROM formula1.v_analisis_rendimiento_circuitos",
        "entity": "formula1.v_analisis_rendimiento_circuitos"
    },
    {
        "file": "vistas_rendimiento_lluvia.sql",
        "description": "Vistas de ritmo y carreras en mojado",
        "check": "SELECT count(*) FROM formula1.v_analisis_rendimiento_lluvia_carreras",
        "entity": "formula1.v_analisis_rendimiento_lluvia_carreras"
    },
    {
        "file": "vistas_fallas.sql",
        "description": "Vistas de fiabilidad y fallas de neumaticos (con Indy 2005)",
        "check": "SELECT count(*) FROM formula1.v_analisis_fiabilidad_neumaticos",
        "entity": "formula1.v_analisis_fiabilidad_neumaticos"
    }
]

ALL_ENTITIES_CHECK = [
    ("formula1.constructor", "SELECT count(*) FROM formula1.constructor"),
    ("formula1.race", "SELECT count(*) FROM formula1.race"),
    ("formula1.race_weather", "SELECT count(*) FROM formula1.race_weather"),
    ("formula1.v_temporadas_proveedor_marca", "SELECT count(*) FROM formula1.v_temporadas_proveedor_marca"),
    ("formula1.v_cuota_parrilla_anual_neumaticos", "SELECT count(*) FROM formula1.v_cuota_parrilla_anual_neumaticos"),
    ("formula1.v_acumulacion_poles_carreras", "SELECT count(*) FROM formula1.v_acumulacion_poles_carreras"),
    ("formula1.v_f1_qualy_granular", "SELECT count(*) FROM formula1.v_f1_qualy_granular"),
    ("formula1.v_f1_race_granular", "SELECT count(*) FROM formula1.v_f1_race_granular"),
    ("formula1.v_analisis_rendimiento_anual", "SELECT count(*) FROM formula1.v_analisis_rendimiento_anual"),
    ("formula1.v_analisis_asimetria_marca", "SELECT count(*) FROM formula1.v_analisis_asimetria_marca"),
    ("formula1.v_analisis_rendimiento_circuitos", "SELECT count(*) FROM formula1.v_analisis_rendimiento_circuitos"),
    ("formula1.v_analisis_rendimiento_lluvia_carreras", "SELECT count(*) FROM formula1.v_analisis_rendimiento_lluvia_carreras"),
    ("formula1.v_analisis_fiabilidad_neumaticos", "SELECT count(*) FROM formula1.v_analisis_fiabilidad_neumaticos")
]


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Pipeline SQL: Ejecuta y valida todos los scripts SQL de F1 Tyre War en PostgreSQL"
    )
    parser.add_argument("--host", default=os.getenv("PGHOST", "localhost"), help="Host de PostgreSQL (default: localhost)")
    parser.add_argument("--port", type=int, default=int(os.getenv("PGPORT", "5432")), help="Puerto de PostgreSQL (default: 5432)")
    parser.add_argument("--dbname", default=os.getenv("PGDATABASE", "postgres"), help="Base de datos (default: postgres)")
    parser.add_argument("--user", default=os.getenv("PGUSER", "postgres"), help="Usuario (default: postgres)")
    parser.add_argument("--password", default=os.getenv("PGPASSWORD", "postgres"), help="Contraseña (default: postgres o var PGPASSWORD)")
    parser.add_argument("--sql-dir", type=Path, default=None, help="Directorio con los archivos .sql (default: auto-detect)")
    return parser.parse_args()


def get_connection(args):
    conn = psycopg2.connect(
        host=args.host,
        port=args.port,
        dbname=args.dbname,
        user=args.user,
        password=args.password,
        options="-c search_path=formula1,public"
    )
    conn.autocommit = True
    return conn


def main():
    # Configurar salida segura para consola Windows
    if sys.stdout.encoding and sys.stdout.encoding.lower() not in ('utf-8', 'utf8'):
        try:
            sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        except Exception:
            pass

    args = parse_arguments()
    repo_root = Path(__file__).resolve().parent.parent
    sql_dir = args.sql_dir if args.sql_dir else (repo_root / "sql")

    if not sql_dir.exists():
        print(f"[ERROR] Directorio SQL no encontrado: {sql_dir}")
        sys.exit(1)

    print("=" * 70)
    print("  F1 TYRE WAR: PIPELINE DE CARGA Y DESPLIEGUE SQL")
    print("=" * 70)
    print(f"PostgreSQL Target: {args.user}@{args.host}:{args.port}/{args.dbname}")
    print(f"Directorio SQL:    {sql_dir}")
    print("-" * 70)

    try:
        conn = get_connection(args)
    except Exception as e:
        print(f"[FATAL] Error de conexión a PostgreSQL:\n{e}")
        print("\nSugerencia: asegúrate de que PostgreSQL esté corriendo y que las credenciales sean válidas.")
        print("Puedes pasar parámetros con: python scripts/run_sql_pipeline.py --password tu_pass")
        sys.exit(1)

    cursor = conn.cursor()

    # Verificar que el esquema formula1 existe
    cursor.execute("SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'formula1';")
    if not cursor.fetchone():
        print("[AVISO] Esquema 'formula1' no existia. Creándolo...")
        cursor.execute("CREATE SCHEMA IF NOT EXISTS formula1;")

    print("\nEjecutando scripts SQL en orden de dependencias...")
    print("-" * 70)

    success_count = 0
    for idx, step in enumerate(SQL_PIPELINE, start=1):
        sql_file = sql_dir / step["file"]
        if not sql_file.exists():
            print(f"[{idx}/{len(SQL_PIPELINE)}] [ERROR] Archivo no encontrado: {sql_file.name}")
            continue

        print(f"[{idx}/{len(SQL_PIPELINE)}] Ejecutando {step['file']} ({step['description']})...", end=" ")
        try:
            with open(sql_file, "r", encoding="utf-8") as f:
                sql_content = f.read()

            # Asegurar search_path explícito
            cursor.execute("SET search_path TO formula1, public;")
            cursor.execute(sql_content)

            # Validar chequeo
            cursor.execute(step["check"])
            count = cursor.fetchone()[0]
            print(f"[OK] -> {count} registros")
            success_count += 1
        except Exception as e:
            print(f"[FALLO]\n  Detalle del error: {e}")

    print("-" * 70)
    print("\n" + "=" * 70)
    print("  VERIFICACIÓN FINAL DE TABLAS Y VISTAS PARA POWER BI")
    print("=" * 70)

    all_ok = True
    for entity, check_query in ALL_ENTITIES_CHECK:
        try:
            cursor.execute(check_query)
            count = cursor.fetchone()[0]
            print(f"  [OK] {entity:<48} : {count:>6} filas")
        except Exception as e:
            print(f"  [X]  {entity:<48} : ERROR ({e})")
            all_ok = False

    cursor.close()
    conn.close()

    print("=" * 70)
    if all_ok and success_count == len(SQL_PIPELINE):
        print("  PIPELINE COMPLETADO CON EXITO.")
        print("  El modelo en PostgreSQL esta 100% listo para Power BI.")
        print("=" * 70)
    else:
        print("  PIPELINE FINALIZADO CON ALGUNAS ADVERTENCIAS O ERRORES.")
        print("=" * 70)
        sys.exit(1)


if __name__ == "__main__":
    main()
