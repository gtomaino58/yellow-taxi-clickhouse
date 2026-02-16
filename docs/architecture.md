ARQUITECTURA

Arquitectura y Escalabilidad – Sistema de Base de Datos de Alto Rendimiento
Proyecto: NYC Yellow Taxi – ClickHouse

====================================================

OBJETIVO DEL SISTEMA

Diseñar e implementar un sistema de base de datos capaz de:

* Manejar tasas de inserción en tiempo real extremadamente altas (> 1 millón de filas por segundo).
* Permitir acceso a los datos mediante múltiples filtros.
* Mantener los datos accesibles a largo plazo.
* Proporcionar estadísticas agregadas en tiempo real.

Dataset utilizado: NYC Yellow Taxi Trip Records (archivos CSV locales).

====================================================

MOTOR ELEGIDO: CLICKHOUSE

Se selecciona ClickHouse como motor de base de datos debido a:

* Arquitectura columnar optimizada para analítica (OLAP).
* Alta eficiencia en agregaciones masivas (GROUP BY).
* Excelente rendimiento en inserciones por lotes.
* Soporte nativo de particionado por rango temporal en motores MergeTree.
* Soporte de replicación y distribución horizontal.
* Materialized Views integradas.

Comparativa con otras opciones:

* PostgreSQL / MySQL: Adecuados para cargas mixtas OLTP/OLAP, pero para alcanzar tasas extremadamente altas de ingestión requieren configuración avanzada y sharding externo más complejo.

* MongoDB: Flexible y escalable horizontalmente, pero menos eficiente en agregaciones analíticas masivas comparado con un motor columnar.

Por tanto, ClickHouse se adapta mejor a escenarios de analítica intensiva con grandes volúmenes de datos.

====================================================

DISEÑO FÍSICO DE LA TABLA PRINCIPAL

Motor: ENGINE = MergeTree

Particionado: PARTITION BY toYYYYMM(tpep_pickup_datetime)
Cada mes se almacena como una partición independiente.

Ordenamiento: ORDER BY (tpep_pickup_datetime, VendorID)
Este orden constituye la clave primaria física de la tabla en MergeTree y optimiza:

* Consultas por rango temporal.
* Agregaciones por día y hora.
* Lecturas secuenciales eficientes.

Columnas derivadas materializadas:

* pickup_date
* pickup_hour
* pickup_yyyymm
* trip_duration_sec

Estas columnas reducen el coste de cálculo repetitivo en consultas analíticas.

====================================================

ESTRATEGIA DE INGESTA

Entorno local:
* Inserciones por lotes desde CSV usando: INSERT INTO ... FORMAT CSVWithNames
* Directorio de datos montado en Docker.
* Carga secuencial por fichero (mes).

Entorno de producción (visión teórica) para soportar >1 millón de filas por segundo:
* Uso de cola intermedia (Kafka o sistema equivalente).
* Micro-batching (50k–500k filas por bloque).
* Consumidores paralelos.
* Mecanismo de backpressure para absorber picos.

ClickHouse procesa bloques de inserción en paralelo, maximizando uso de CPU.

====================================================

PARTICIONADO Y RETENCIÓN A LARGO PLAZO

Estrategia de particionado:

1.- El particionado mensual permite:

* Escaneo reducido en consultas por fecha.
* Eliminación eficiente de datos antiguos.
* Mantenimiento independiente por mes.

2.- TTL (Time To Live):

En un entorno real se podría aplicar:

ALTER TABLE taxi_trips
MODIFY TTL tpep_pickup_datetime + INTERVAL 3 YEAR DELETE;

O mover datos antiguos a almacenamiento frío:

ALTER TABLE taxi_trips
MODIFY TTL tpep_pickup_datetime + INTERVAL 2 YEAR
TO VOLUME 'cold_storage';

Beneficios:

* Gestión automática del ciclo de vida.
* Optimización de costes de almacenamiento.
* Acceso rápido a datos recientes.

====================================================

AGREGADOS EN TIEMPO REAL

Se implementan Materialized Views que alimentan tablas basadas en ENGINE = SummingMergeTree

Tablas agregadas:

* trips_by_day
* duration_by_hour
* pickups_density_grid_1km
* tips_by_month_hour

Funcionamiento:

Las Materialized Views:

* Se ejecutan durante la inserción.
* Actualizan automáticamente las tablas agregadas.
* Eliminan necesidad de procesos batch externos.

Beneficios:

* Consultas analíticas con baja latencia.
* Reducción del coste computacional.
* Escalabilidad natural en entorno distribuido.
* En despliegue distribuido, cada shard mantiene sus agregados y se consultan mediante tablas Distributed.

====================================================

DENSIDAD DE TAXIS POR KM²

El dataset no incluye identificador único de taxi ni polígonos oficiales de zonas.
Se implementa una aproximación basada en:

* Conversión de latitud/longitud a coordenadas métricas (proyección aproximada Web Mercator).
* Discretización en una malla regular de 1 km x 1 km.
* Conteo de pickups por celda y día.

Esto permite:

* Identificar hotspots.
* Calcular densidad media diaria.
* Mantener independencia de datos geográficos externos.

====================================================

ESCALABILIDAD

a.- Escalado Vertical

Incremento de:

* CPU (más núcleos).
* RAM (mayor cache y eficiencia en merges).
* Almacenamiento NVMe.
* Ajuste de parámetros internos.

Ventaja: Simplicidad operativa.

Limitación: Techo físico del servidor.

b.- Escalado Horizontal

Distribución en múltiples nodos mediante:

* Sharding por mes.
* Sharding por hash geográfico.
* Tablas Distributed para consultas unificadas.

El coordinador distribuye las consultas entre shards y consolida los resultados de forma paralela.

Ventaja: Escalabilidad casi lineal.

Requiere: Gestión de coordinación entre nodos.

c.- Replicación

Uso de: ReplicatedMergeTree
Coordinación mediante: ClickHouse Keeper o ZooKeeper.

Beneficios: Alta disponibilidad, Failover automático, Lecturas desde réplicas.

====================================================

ACCESO A LARGO PLAZO

Gracias al particionado mensual:

* Se pueden archivar meses antiguos.
* Se pueden mover a almacenamiento frío.
* Se puede realizar purgado selectivo.
* Esto permite mantener datos accesibles a largo plazo con control de costes sin degradar el rendimiento de consultas
  sobre datos recientes.

====================================================

RENDIMIENTO EN ENTORNO LOCAL

En entorno Docker local:

* Total de filas cargadas: aproximadamente 47 millones.
* Consulta de agregación completa sobre 47M filas ejecutada en ~0.021 s.
* Consulta count() simple ejecutada en ~0.004 s.

Esto demuestra que el diseño es eficiente incluso sin infraestructura distribuida.
El rendimiento observado confirma que el cuello de botella en el entorno de pruebas no reside en el motor de almacenamiento
sino en el pipeline de ingestión.

====================================================

REFLEXIÓN FINAL

Parte más interesante:
El diseño de agregados en tiempo real mediante Materialized Views y la eficiencia del modelo columnar en consultas analíticas masivas.

Parte más compleja:
Definir una métrica de densidad por km² robusta con la información disponible, sin depender de datos geográficos externos.

====================================================

CONCLUSIÓN

El sistema diseñado cumple con:

* Alta capacidad de ingestión.
* Soporte para consultas con múltiples filtros.
* Estadísticas agregadas en tiempo real.
* Escalabilidad vertical y horizontal.
* Estrategia clara de replicación y retención.

ClickHouse se demuestra como una solución altamente adecuada para escenarios de analítica de gran volumen y alto rendimiento.
El diseño físico del almacenamiento, combinado con agregación incremental, demuestra que la elección del motor es determinante
en el rendimiento final del sistema.