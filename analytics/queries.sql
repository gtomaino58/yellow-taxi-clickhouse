
-- 4.1 Número de viajes por día
SELECT
  pickup_date AS day,
  count() AS trips
FROM taxi.taxi_trips
GROUP BY day
ORDER BY day;

-- 4.2 Duración media por hora del día
SELECT
  pickup_hour AS hour,
  avg(trip_duration_sec) / 60.0 AS avg_duration_minutes
FROM taxi.taxi_trips
GROUP BY hour
ORDER BY hour;

-- 4.3 Densidad de taxis por km² (aproximación robusta con “grid 1km x 1km”)
-- Aquí no tenemos “TaxiID” ni área oficial de zonas en el dataset. Así que definimos densidad como:
-- “número de pickups por km² (en una malla de 1km²), por día”
-- ClickHouse permite convertir lat/lon a metros (proyección Web Mercator) y hacer “bucketing” en celdas de 1000m.
-- En la memoria lo explicas como “densidad espacial por celda de 1km²” (muy defendible).
-- Si quieres, luego añadimos una versión “densidad media” (promedio de pickups por celda ocupada).
WITH
  -- Web Mercator (aprox) en metros
  (pickup_longitude * 20037508.34 / 180.0) AS x,
  (log(tan((90.0 + pickup_latitude) * pi() / 360.0)) / (pi() / 180.0)) * 20037508.34 / 180.0 AS y,
  intDiv(toInt64(x), 1000) AS cell_x,
  intDiv(toInt64(y), 1000) AS cell_y
SELECT
  pickup_date AS day,
  cell_x,
  cell_y,
  count() AS pickups_in_cell
FROM taxi.taxi_trips
WHERE pickup_longitude IS NOT NULL AND pickup_latitude IS NOT NULL
GROUP BY day, cell_x, cell_y
ORDER BY day, pickups_in_cell DESC
LIMIT 200;

-- 4.4 Variación MoM y QoQ de la suma de propinas por hora
-- Primero agregamos por mes + hora, luego calculamos variación respecto al mes anterior y al trimestre anterior.
WITH base AS (
  SELECT
    toStartOfMonth(tpep_pickup_datetime) AS month,
    pickup_hour AS hour,
    sum(ifNull(tip_amount, 0.0)) AS tips_sum
  FROM taxi.taxi_trips
  GROUP BY month, hour
)
SELECT
  month,
  hour,
  tips_sum,
  tips_sum - lagInFrame(tips_sum, 1) OVER (PARTITION BY hour ORDER BY month) AS mom_abs_change,
  tips_sum - lagInFrame(tips_sum, 3) OVER (PARTITION BY hour ORDER BY month) AS qoq_abs_change,
  if(lagInFrame(tips_sum, 1) OVER (PARTITION BY hour ORDER BY month) = 0, NULL,
     (tips_sum / lagInFrame(tips_sum, 1) OVER (PARTITION BY hour ORDER BY month) - 1) * 100
  ) AS mom_pct_change,
  if(lagInFrame(tips_sum, 3) OVER (PARTITION BY hour ORDER BY month) = 0, NULL,
     (tips_sum / lagInFrame(tips_sum, 3) OVER (PARTITION BY hour ORDER BY month) - 1) * 100
  ) AS qoq_pct_change
FROM base
ORDER BY month, hour;



