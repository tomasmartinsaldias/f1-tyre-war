# F1 Tyre War (2000-2005): Análisis Estratégico y Técnico

> **Proyecto de Base de Datos y Business Intelligence en Fórmula 1**  
> Estudio comparativo del rendimiento, fiabilidad y adaptación estratégica entre los proveedores de neumáticos **Bridgestone** y **Michelin** durante la era de competencia abierta (2000-2005).

---

## 🏎️ Descripción del Proyecto

A través de una perspectiva de consultoría técnica externa para Directores de Equipo (*Team Principals*) previa a la temporada 2006, este proyecto analiza:
- **Ritmo puro a una vuelta (Qualy) vs Degradación en carrera (Race).**
- **Comportamiento en condiciones climáticas adversas (Lluvia y ventanas térmicas).**
- **Asimetría de desarrollo y alianzas:** el enfoque mono-cliente de Bridgestone (Ferrari) frente al modelo multichasis democrático de Michelin (Renault, McLaren, Williams, BAR).
- **Riesgo operativo y fiabilidad:** costo en puntos de abandonos mecánicos vs fallas estructurales de neumáticos.

---

## 📁 Estructura del Repositorio

```text
f1-tyre-war/
├── docs/
│   ├── guia_carga_datos_weather.md    # Guía completa de reproducción del modelo de datos y clima
│   └── f1-powerbi-estructura.txt      # Storytelling, narrativa en 3 actos y tesis del dossier
├── powerbi/
│   ├── f1-neumaticos.pbip             # Proyecto Power BI Desktop (formato PBIP)
│   ├── f1-neumaticos.Report/          # Definición de visuales, lienzos y temas (PBIR)
│   └── f1-neumaticos.SemanticModel/   # Definición de tablas, relaciones y medidas DAX (TMDL)
├── scripts/
│   └── script_generador_weather.py    # Pipeline ETL en Python para ingesta climática ERA5
└── sql/
    ├── ddl_race_weather.sql           # DDL de la tabla formula1.race_weather
    ├── 45_race_weather.sql            # Datos climáticos históricos procesados (104 carreras)
    ├── vistas_rendimiento_lluvia.sql  # Vistas de delta de ritmo en lluvia por segmento
    ├── vistas_temporadas_y_acumulacion_poles.sql # Vistas de acumulación temporal de poles
    ├── vistas_qualy.sql               # Vistas de ritmo de clasificación
    ├── vistas_fallas.sql              # Vistas de fiabilidad y abandonos
    └── vistas_generalita_o_especializado.sql # Vistas de asimetría Ferrari vs clientes
```

---

## 🚀 Inicio Rápido: ¿Cómo Reproducir el Modelo de Datos?

Para tener todo el entorno de datos configurado exactamente igual en PostgreSQL y listo para Power BI:

1. **Consulta la guía paso a paso completa:**  
   👉 [**Guía de Replicación del Modelo y Clima (docs/guia_carga_datos_weather.md)**](file:///C:/Users/Franc/Documents/ThinkPad/Github/f1-tyre-war/docs/guia_carga_datos_weather.md)

2. **Resumen de comandos esenciales:**
   ```bash
   # 1. Instalar dependencias Python
   pip install psycopg2-binary requests urllib3

   # 2. Crear tabla de clima en PostgreSQL (localhost:5432, base: postgres, esquema: formula1)
   psql -h localhost -p 5432 -U postgres -d postgres -f "sql/ddl_race_weather.sql"

   # 3. Descargar y enriquecer con datos climáticos de Open-Meteo ERA5
   python scripts/script_generador_weather.py

   # 4. Cargar los datos y vistas analíticas
   psql -h localhost -p 5432 -U postgres -d postgres -f "sql/45_race_weather.sql"
   psql -h localhost -p 5432 -U postgres -d postgres -f "sql/vistas_rendimiento_lluvia.sql"
   psql -h localhost -p 5432 -U postgres -d postgres -f "sql/vistas_temporadas_y_acumulacion_poles.sql"
   psql -h localhost -p 5432 -U postgres -d postgres -f "sql/vistas_qualy.sql"
   psql -h localhost -p 5432 -U postgres -d postgres -f "sql/vistas_fallas.sql"
   psql -h localhost -p 5432 -U postgres -d postgres -f "sql/vistas_generalita_o_especializado.sql"

   # 5. Abrir el proyecto en Power BI
   # Abrir powerbi/f1-neumaticos.pbip y presionar "Actualizar" (Refresh).
   ```

---

## 📊 Vistas y Dashboards en Power BI

El informe incluye, entre otras secciones ejecutivas:
1. **Scuderías:** Análisis de alianzas estratégicas, cuota de parrilla y distribución competitiva de neumáticos con segmentación dinámica.
2. **Página 2 (Acumulación de Poles):** Trayectoria temporal acumulada de poles position entre Michelin y Bridgestone por temporada y fecha cronológica.
3. **Acto II: Lluvia y Segmentos:** Rendimiento en mojado carrera a carrera (orden cronológico) con codificación por color por proveedor ganador (Azul Michelin vs Rojo Bridgestone) y años visibles al pie.
