# Yellow Taxi – High Performance Database Design (ClickHouse)

Proyecto de diseño e implementación de un sistema de base de datos de alto rendimiento
capaz de soportar alta ingestión de datos, consultas analíticas complejas y estadísticas agregadas en tiempo real.

Motor utilizado: ClickHouse  
Dataset: NYC Yellow Taxi Trip Records  

====================================================

1. OBJETIVO DEL PROYECTO

Diseñar un sistema capaz de:

- Manejar altas tasas de inserción.
- Permitir consultas con múltiples filtros.
- Mantener datos accesibles a largo plazo.
- Proporcionar estadísticas agregadas en tiempo real.
- Escalar vertical y horizontalmente.

====================================================

2. REQUISITOS

- Windows + Docker Desktop
- PowerShell
- ClickHouse ejecutándose mediante Docker Compose

====================================================

3. ESTRUCTURA DEL PROYECTO

```text
yellow-taxi-clickhouse/
├── README.md
├── docker-compose.yml
├── .gitignore
├── .gitattributes
├── schema/
│   ├── 01_create_tables.sql
│   └── 02_aggregates.sql
├── ingestion/
│   └── load_data.ps1
├── analytics/
│   ├── queries.sql
│   └── queries_mv.sql
├── docs/
│   └── architecture.md
│   └── Yellow_Taxi_Enunciado.txt
│   └── Queries_Clickhouse.txt
│   └── Estadisticas_desde_Clickhouse.txt
│   └── Benchmark_Carga_Powershell.txt
│   └── DB_normal (capturas)
│   └── DB_triplicada (capturas)
└── benchmark/
    └── benchmark_results.md

====================================================

4. DATASET

Los archivos CSV NO están incluidos en el repositorio debido a su tamaño.

Colocar los siguientes archivos en:

./data/

Archivos necesarios:

- yellow_tripdata_2015-01.csv
- yellow_tripdata_2016-01.csv
- yellow_tripdata_2016-02.csv
- yellow_tripdata_2016-03.csv

====================================================

5. QUICK START

1) Levantar ClickHouse

docker compose up -d

2) Crear tablas principales

Get-Content .\schema\01_create_tables.sql -Raw | docker exec -i clickhouse clickhouse-client

3) Crear agregados (Materialized Views)

Get-Content .\schema\02_aggregates.sql -Raw | docker exec -i clickhouse clickhouse-client

4) Cargar los datos

.\ingestion\load_data.ps1

5) Verificar carga

docker exec -it clickhouse clickhouse-client --query "SELECT count() FROM taxi.taxi_trips"

Resultado esperado:
47248845

====================================================

6. ANALÍTICAS IMPLEMENTADAS

1) Número de viajes por día  
2) Duración media por hora del día  
3) Densidad de taxis por km² (grid 1km x 1km)  
4) Variación MoM y QoQ de la suma de propinas por hora  

Para ejecutar las consultas:

docker exec -it clickhouse clickhouse-client

Y ejecutar las queries contenidas en:

analytics/queries.sql

o bien utilizar las versiones optimizadas con agregados en:

analytics/queries_mv.sql

====================================================

7. DISEÑO TÉCNICO

- Motor: MergeTree
- Particionado: por mes (toYYYYMM)
- Orden primario: (tpep_pickup_datetime, VendorID)
- Agregados en tiempo real mediante Materialized Views
- Tablas agregadas basadas en SummingMergeTree

Detalles completos en:

docs/architecture.md

====================================================

8. BENCHMARK (RESUMEN)

Volumen cargado:
- 47.248.845 registros
- Tamaño en disco: 1.60 GiB

Ingestión (entorno local Docker):
- Throughput medio: ~59.600 filas/segundo

Lectura:
- Scan completo (47M filas): 0.021 s
- Consulta mediante MV: 0.003 s
- Mejora aproximada: 7x

Detalles completos en:

benchmark/benchmark_results.md

====================================================

9. ESCALABILIDAD

El diseño soporta:

Escalado Vertical:
- Más CPU
- Más RAM
- NVMe
- Ajuste de parámetros internos

Escalado Horizontal:
- Sharding por mes o hash
- Tablas Distributed
- ReplicatedMergeTree
- ClickHouse Keeper

Proyección teórica >1M filas/seg en arquitectura distribuida con micro-batching y paralelismo.

====================================================

10. CONCLUSIÓN

El sistema implementado demuestra:

- Alta eficiencia de almacenamiento.
- Excelente rendimiento en agregaciones.
- Beneficio claro del modelo columnar.
- Escalabilidad proyectada coherente con requisitos de alto rendimiento.

ClickHouse se confirma como una solución idónea para escenarios de analítica masiva de datos.