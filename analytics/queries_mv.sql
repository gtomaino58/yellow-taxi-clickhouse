-- 1) Viajes por día
SELECT day, trips
FROM taxi.trips_by_day
ORDER BY day;

-- 2) Duración media por hora
SELECT
  hour,
  duration_sum / trips / 60.0 AS avg_duration_minutes
FROM taxi.duration_by_hour
WHERE trips > 0
ORDER BY hour;

-- 3) Densidad por km² (top celdas por día)
SELECT day, cell_x, cell_y, pickups
FROM taxi.pickups_density_grid_1km
ORDER BY day, pickups DESC
LIMIT 200;

-- 4) MoM y QoQ de propinas por hora
WITH base AS (
  SELECT month, hour, tips_sum
  FROM taxi.tips_by_month_hour
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
