# F1 Tyre War (2000-2005): Análisis Estratégico y Técnico

> **Proyecto de Base de Datos y Business Intelligence en Fórmula 1**  
> Estudio comparativo del rendimiento, fiabilidad y adaptación estratégica entre los proveedores de neumáticos **Bridgestone** y **Michelin** durante la era de competencia abierta (2000-2005).

---

## 🏎️ Descripción del Proyecto

A través de una perspectiva de consultoría técnica externa para Directores de Equipo (*Team Principals*) previa a la temporada 2006, este proyecto analiza:
- **Ritmo puro a una vuelta (Qualy) vs Degradación en carrera (Race).**
- **Comportamiento en condiciones climáticas adversas (Lluvia y ventanas térmicas con ERA5).**
- **Asimetría de desarrollo y alianzas:** el enfoque mono-cliente de Bridgestone (Ferrari) frente al modelo multichasis democrático de Michelin (Renault, McLaren, Williams, BAR).
- **Rendimiento según tipología de trazado:** circuitos de alta velocidad (Spa, Suzuka) vs circuitos lentos y técnicos (Mónaco, Hungaroring).
- **Riesgo operativo y fiabilidad:** tasa de fallas por cada 1.000 vueltas y el impacto del GP de Estados Unidos (Indianápolis 2005).
- **Dictamen contractual 2006:** recomendación adaptada al retorno de las paradas en boxes para cambio de neumáticos.

---

## 📁 Estructura del Repositorio

```text
f1-tyre-war/
├── docs/
│   ├── guia_carga_datos_weather.md            # Guía completa de reproducción del modelo de datos y clima
│   └── f1-powerbi-estructura.txt              # Storytelling, narrativa en 3 actos y tesis del dossier
├── powerbi/
│   ├── f1-neumaticos.pbip                     # Proyecto Power BI Desktop (formato PBIP)
│   ├── f1-neumaticos.Report/                  # Definición de visuales, lienzos y temas (PBIR)
│   └── f1-neumaticos.SemanticModel/           # Definición de tablas, relaciones y medidas DAX (TMDL)
├── scripts/
│   ├── run_sql_pipeline.py                    # Pipeline automatizado de despliegue SQL y validación en PostgreSQL
│   ├── run_sql_pipeline.ps1                   # Wrapper PowerShell para ejecución directa en Windows
│   └── script_generador_weather.py            # Pipeline ETL en Python para ingesta climática ERA5
└── sql/
    ├── ddl_race_weather.sql                   # DDL de la tabla formula1.race_weather
    ├── 45_race_weather.sql                    # Datos climáticos históricos procesados (104 carreras)
    ├── vistas_temporadas_y_acumulacion_poles.sql # Vistas de temporadas, cuota de parrilla y poles
    ├── vistas_qualy.sql                       # Vistas granulares de clasificación y carrera
    ├── vistas_generalita_o_especializado.sql  # Vistas de asimetría Ferrari vs escuderías cliente
    ├── vistas_rendimiento_circuitos.sql       # Vistas de rendimiento en circuitos rápidos vs lentos
    ├── vistas_rendimiento_lluvia.sql          # Vistas de delta de ritmo en mojado por segmento
    └── vistas_fallas.sql                      # Vistas de fiabilidad, fallas y retiros de Indianápolis 2005
```

---

## 🚀 Inicio Rápido: Despliegue de la Base de Datos

Para levantar todas las tablas, datos de clima y vistas analíticas en PostgreSQL con un solo comando:

### Opción 1: Pipeline Automatizado (Recomendado)

1. **Instalar dependencias de Python:**
   ```bash
   pip install psycopg2-binary requests urllib3
   ```

2. **Ejecutar el pipeline:**
   ```bash
   # En cualquier sistema operativo (Linux, macOS, Windows):
   python scripts/run_sql_pipeline.py

   # O directamente desde PowerShell en Windows:
   .\scripts\run_sql_pipeline.ps1
   ```

   > **Nota de conexión:** Por defecto conecta a `localhost:5432`, base `postgres`, usuario `postgres`, contraseña `postgres` (o lee variables de entorno `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`).  
   > Si utilizas otras credenciales, puedes especificarlas con flags:  
   > `python scripts/run_sql_pipeline.py --user postgres --password tu_pass --port 5432`

El script ejecuta los 8 archivos SQL en estricto orden de dependencias y realiza una verificación final con conteo de registros para cada tabla y vista.

---

### Opción 2: Ejecución Manual con `psql`

Si prefieres ejecutar los scripts individualmente mediante la terminal de PostgreSQL:

```bash
psql -h localhost -p 5432 -U postgres -d postgres -f "sql/ddl_race_weather.sql"
psql -h localhost -p 5432 -U postgres -d postgres -f "sql/45_race_weather.sql"
psql -h localhost -p 5432 -U postgres -d postgres -f "sql/vistas_temporadas_y_acumulacion_poles.sql"
psql -h localhost -p 5432 -U postgres -d postgres -f "sql/vistas_qualy.sql"
psql -h localhost -p 5432 -U postgres -d postgres -f "sql/vistas_generalita_o_especializado.sql"
psql -h localhost -p 5432 -U postgres -d postgres -f "sql/vistas_rendimiento_circuitos.sql"
psql -h localhost -p 5432 -U postgres -d postgres -f "sql/vistas_rendimiento_lluvia.sql"
psql -h localhost -p 5432 -U postgres -d postgres -f "sql/vistas_fallas.sql"
```

---

## 📊 Vistas y Dashboards en Power BI

El informe interactivo [`powerbi/f1-neumaticos.pbip`](powerbi/f1-neumaticos.pbip) contiene **10 diapositivas ejecutivas** estructuradas para la toma de decisiones:

1. **`00. Executive Brief`**  
   Portada ejecutiva, contextualización del cambio de reglamento para 2006 (retorno de las paradas en boxes), tesis consultiva y menú de navegación global.

2. **`01. Cuota de Equipos`**  
   Evolución anual de la cuota de parrilla (2001-2005) entre Michelin y Bridgestone, mapeo de alianzas estratégicas por escudería y segmentación interactiva 1x3 (`Top-Tier, Midfield, Backmarker`).

3. **`02. Acumulación de Poles`**  
   Trayectoria cronológica de pole positions acumuladas temporada a temporada, visualizando el período de dominio de Bridgestone (2001-2004) y el quiebre (*sorpasso*) definitivo de Michelin en 2005.

4. **`03. Ritmo a una Vuelta (Shock Qualy)`**  
   Evaluación del impacto del reglamento de 2005 (neumático único para clasificación y carrera). Evidencia el colapso de rendimiento de Bridgestone a una vuelta frente a los compuestos Michelin.

5. **`04. Brecha entre Escuderías del Mismo Fabricante`**  
   Análisis del dilema *Custom vs Off-the-Shelf*. Demuestra la asimetría estructural de Bridgestone (diseñado casi exclusivamente para Ferrari, generando una brecha media de +11 posiciones para sus clientes) frente a la paridad democrática multichasis de Michelin.

6. **`05. Conversión Real de Puntos`**  
   Métricas de conversión y eficiencia en carrera: puntos normalizados por monoplaza en grilla y análisis de la paradoja de volumen de flota.

7. **`06. Rendimiento según Circuitos`**  
   Comportamiento comparativo en trazados rápidos (Spa-Francorchamps y Suzuka) frente a circuitos lentos y revirados (Mónaco y Hungaroring), analizando deltas de clasificación, puntos por auto y desgaste.

8. **`07. Carreras en Lluvia`**  
   Rendimiento en mojado (2001-2005) cruzado con reanálisis climático Open-Meteo ERA5. Comparación directa del ritmo cronológico en lluvia entre los mejores exponentes de cada fabricante.

9. **`08. Fiabilidad y Riesgo Operativo`**  
   Tasa de fallas de neumáticos por cada 1.000 vueltas completadas, distribución de abandonos (accidentes, mecánicos y neumáticos) y análisis del costo operacional de la crisis de Indianápolis 2005 (14 retiros preventivos de Michelin).

10. **`09. Matriz de Decisión Contractual 2006`**  
    Cuadro de mando consultivo interactivo que sintetiza el dictamen técnico final según el arquetipo de escudería (Aspirante al Título, Zona Media o Fondo de Parrilla) ponderando el regreso de los pit stops para 2006.

---

## 🛠️ Tecnologías Utilizadas

- **Base de Datos:** PostgreSQL 18 (Esquema relacional y vistas analíticas)
- **Datos Climáticos:** API Histórica Open-Meteo (Reanálisis ERA5 de la Comisión Europea / ECMWF)
- **Lenguajes:** Python 3 (ETL, ingesta y pipeline con `psycopg2`), SQL (ANSI / PostgreSQL DDL & Views), DAX (Medidas de Power BI)
- **Business Intelligence:** Power BI Desktop Developer Mode (Formato PBIP, TMDL y PBIR)
