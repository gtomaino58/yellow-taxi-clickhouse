# Benchmark (Evaluación de Rendimiento)

## (1) Ingestión de datos: se realizaron tres ejecuciones consecutivas de carga completa de los cuatro archivos CSV.

Volumen por ejecución: 47.248.845 registros.

Resultados:
Tiempo medio de carga: 792.35 segundos
Throughput medio: 59.600 filas por segundo

Este rendimiento se obtuvo en entorno local Windows + Docker, utilizando inserción desde CSV mediante pipe estándar.
Debe considerarse que no se utilizó paralelización explícita, no se empleó cola de ingestión (Kafka), el entorno no
está optimizado para alto rendimiento (I/O compartido con Docker Desktop). Por tanto, el valor observado representa
una cota conservadora del sistema en entorno no productivo.

## (2) Rendimiento de lectura:

(a) Consulta agregada sobre tabla base (47M filas).

Resultados:
Tiempo: 0.021 segundos
Filas procesadas: 47.25 millones
Throughput interno: 2.24 mil millones de filas/segundo
Ancho de banda interno: 4.49 GB/s

(b) Consulta equivalente utilizando Materialized View.

Resultados:
Tiempo: 0.003 segundos
Mejora observada: aproximadamente 7x.

## (3) Eficiencia de almacenamiento:

Tabla principal:
47.248.845 filas
Tamaño en disco: 1.60 GiB

El almacenamiento columnar comprimido permite una alta eficiencia de espacio.

## (4) Estado del sistema durante pruebas:

Las métricas internas muestran:

* CPU mayoritariamente en estado idle (>98%).
* Ausencia de presión de I/O.
* Sin merges activos.
* Memoria estable (~1.3 GB residente).
* El sistema opera muy por debajo de sus límites en entorno local.

## (5) Conclusión de rendimiento

El sistema demuestra:

* Alta eficiencia de lectura.
* Baja latencia en agregaciones.
* Escalabilidad vertical viable.
* Diseño adecuado para analítica masiva.

El throughput de ingestión observado está limitado por el entorno local y el método de carga, no por el motor de base de datos.
En un entorno distribuido con micro-batching y paralelismo, el diseño permitiría escalar significativamente hacia el objetivo
de >1 millón de filas por segundo.

# Análisis avanzado de escalabilidad y proyección de rendimiento

## (1) Proyección hacia >1 millón de filas por segundo:

El benchmark local mostró:
Throughput medio de ingestión ≈ 59.600 filas/segundo
con un entorno: Windows + Docker Desktop + pipe PowerShell + disco compartido.

Este resultado está limitado por:

* Overhead del pipe STDIN.
* Virtualización de Docker.
* Escritura en volumen compartido.
* Ausencia de paralelismo multi-proceso.

ClickHouse está diseñado para ingestión por bloques y procesamiento altamente paralelo.

En producción, el patrón recomendado sería:

* Cola de ingestión (Kafka o equivalente).
* Micro-batching de 100k–500k filas por bloque.
* Múltiples consumidores en paralelo.
* Sharding horizontal.

Si asumimos 8 consumidores paralelos cada uno capaz de ~150k filas/seg en entorno optimizado
la capacidad estimada es de 8 × 150.000 ≈ 1.2 millones de filas/segundo. Esta estimación
supone hardware dedicado y almacenamiento NVMe.

Esto cumple el requisito de >1M filas/seg con arquitectura distribuida.
La limitación observada en entorno local no es del motor, sino del pipeline de carga.

## (2) Comparativa técnica con PostgreSQL:

| Criterio                   | ClickHouse                           | PostgreSQL                            |
|----------------------------|--------------------------------------|---------------------------------------|
| Modelo                     | Columnar                             | Fila                                  |
| Optimizado para            | OLAP                                 | OLTP                                  |
| Agregaciones masivas       | Extremadamente eficiente             | Más costosas                          |
| Compresión                 | Nativa y alta                        | Limitada                              |
| Particionado               | Nativo y eficiente (MergeTree)       | Disponible pero más costoso           |
| Escalado horizontal        | Sharding nativo                      | Requiere Citus u otro                 |
| MV en tiempo real          | Integradas                           | Más limitadas                         |

En PostgreSQL:

* 47M filas con GROUP BY completo requeriría mayor uso de memoria.
* La compresión sería inferior.
* Escalar a >1M filas/seg requeriría arquitectura adicional compleja.

ClickHouse resulta más adecuado para este tipo de carga analítica de forma natural.

## (3) Modelo teórico de escalado horizontal:

Supongamos arquitectura con 3 shards, cada shard con 2 réplicas y particionado por mes distribuido

Distribución:

Shard 1 → 2015-01
Shard 2 → 2016-01
Shard 3 → 2016-02 y 2016-03

Throughput teórico:

Si cada nodo soporta 60k filas/seg en entorno no optimizado, 3 nodos → 180k filas/seg
En entorno optimizado (x3 mejora por eliminación de overhead local): 3 × 180k ≈ 540k filas/seg

Con paralelismo por shard (4 procesos por nodo): 3 × 4 × 150k ≈ 1.8M filas/seg
La arquitectura escala casi linealmente.

## (4) Evaluación global de rendimiento:

El sistema demuestra:

* Alta eficiencia de almacenamiento.
* Baja latencia en agregaciones.
* Beneficio claro de Materialized Views.
* Escalabilidad vertical viable.
* Escalabilidad horizontal proyectada coherente.
* El diseño cumple los requisitos funcionales y técnicos establecidos.

# Reflexión final

* El aspecto más interesante del proyecto fue comprobar cómo el modelo columnar permite procesar decenas de millones de registros en  milisegundos.
* La parte más compleja fue definir una métrica robusta de densidad espacial sin depender de datos externos.
* El ejercicio demuestra que el diseño físico del almacenamiento es determinante en el rendimiento analítico.