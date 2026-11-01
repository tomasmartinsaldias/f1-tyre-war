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

El informe incluye las secciones ejecutivas organizadas para el storytelling consultivo:
1. **00. Executive Brief:** Portada ejecutiva con el marco del problema 2006, tesis consultora y navegación interactiva.
2. **01. Shock Qualy 2005:** Impacto del cambio regulatorio de 2005 y colapso de rendimiento de Bridgestone a una vuelta con selector interactivo 1x3 (`Top-tier, middle, bottom`).
3. **02. Modelo de Soporte (Asimetría de Marca):** Dilema *Custom vs Off-the-Shelf*, comparando la paridad multichasis de Michelin vs la brecha estructural (+11 puestos) de los clientes de Bridgestone frente a Ferrari.
4. **03. Conversión Real de Puntos:** Análisis de eficiencia de conversión de puntos vs volumen de participantes y paradoja de flota.
5. **04. Sensibilidad al Entorno (Trazados y Clima):** Ventanas operativas térmicas y adaptabilidad a características de circuito.
6. **Acto II: Lluvia y Segmentos:** Evolución continua del ritmo en mojado carrera a carrera en orden cronológico (2001-2005) con delta Michelin vs Bridgestone y selector mosaico 1x3.
7. **Scuderías: Cuota de Equipos:** Alianzas estratégicas, cuota de mercado en la parrilla (2001-2005) y segmentación dinámica 1x3 en diseño limpio y centrado.
8. **Página 2 (Acumulación de Poles):** Trayectoria temporal acumulada de poles position entre Michelin y Bridgestone por temporada y análisis del *Sorpasso* de 2005.
9. **05. Fiabilidad y Riesgo Operativo:** Tasa de fallas y abandonos atribuibles a neumáticos.
10. **06. Matriz de Decisión 2006:** Cuadro de mando de recomendación final para Directores de Equipo.
