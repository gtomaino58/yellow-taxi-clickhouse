-- schema/02_aggregates.sql
CREATE DATABASE IF NOT EXISTS taxi;

-- 1) Viajes por día
DROP TABLE IF EXISTS taxi.trips_by_day;
CREATE TABLE taxi.trips_by_day
(
  day Date,
  trips UInt64
)
ENGINE = SummingMergeTree
ORDER BY (day);

DROP VIEW IF EXISTS taxi.mv_trips_by_day;
CREATE MATERIALIZED VIEW taxi.mv_trips_by_day
TO taxi.trips_by_day
AS
SELECT
  pickup_date AS day,
  count() AS trips
FROM taxi.taxi_trips
GROUP BY day;

-- 2) Duración media por hora (usamos sum/count para poder recomputar avg)
DROP TABLE IF EXISTS taxi.duration_by_hour;
CREATE TABLE taxi.duration_by_hour
(
  hour UInt8,
  duration_sum UInt64,
  trips UInt64
)
ENGINE = SummingMergeTree
ORDER BY (hour);

DROP VIEW IF EXISTS taxi.mv_duration_by_hour;
CREATE MATERIALIZED VIEW taxi.mv_duration_by_hour
TO taxi.duration_by_hour
AS
SELECT
  pickup_hour AS hour,
  sum(trip_duration_sec) AS duration_sum,
  count() AS trips
FROM taxi.taxi_trips
GROUP BY hour;


-- 3) Densidad por celda 1km² (pickups por celda y día)
DROP TABLE IF EXISTS taxi.pickups_density_grid_1km;
CREATE TABLE taxi.pickups_density_grid_1km
(
  day Date,
  cell_x Int64,
  cell_y Int64,
  pickups UInt64
)
ENGINE = SummingMergeTree
ORDER BY (day, cell_x, cell_y);

DROP VIEW IF EXISTS taxi.mv_pickups_density_grid_1km;
CREATE MATERIALIZED VIEW taxi.mv_pickups_density_grid_1km
TO taxi.pickups_density_grid_1km
AS
WITH
  (pickup_longitude * 20037508.34 / 180.0) AS x,
  (log(tan((90.0 + pickup_latitude) * pi() / 360.0)) / (pi() / 180.0)) * 20037508.34 / 180.0 AS y,
  intDiv(toInt64(x), 1000) AS cell_x,
  intDiv(toInt64(y), 1000) AS cell_y
SELECT
  pickup_date AS day,
  cell_x,
  cell_y,
  count() AS pickups
FROM taxi.taxi_trips
WHERE pickup_longitude IS NOT NULL AND pickup_latitude IS NOT NULL
GROUP BY day, cell_x, cell_y;


-- 4) Propinas por mes + hora (para MoM/QoQ)
DROP TABLE IF EXISTS taxi.tips_by_month_hour;
CREATE TABLE taxi.tips_by_month_hour
(
  month Date,     -- toStartOfMonth
  hour UInt8,
  tips_sum Float64
)
ENGINE = SummingMergeTree
ORDER BY (month, hour);

DROP VIEW IF EXISTS taxi.mv_tips_by_month_hour;
CREATE MATERIALIZED VIEW taxi.mv_tips_by_month_hour
TO taxi.tips_by_month_hour
AS
SELECT
  toStartOfMonth(tpep_pickup_datetime) AS month,
  pickup_hour AS hour,
  sum(ifNull(tip_amount, 0.0)) AS tips_sum
FROM taxi.taxi_trips
GROUP BY month, hour;
