-- schema/01_create_tables.sql
CREATE DATABASE IF NOT EXISTS taxi;

DROP TABLE IF EXISTS taxi.taxi_trips;

CREATE TABLE taxi.taxi_trips
(
    VendorID                 UInt8,
    tpep_pickup_datetime     DateTime,
    tpep_dropoff_datetime    DateTime,

    passenger_count          Nullable(UInt8),
    trip_distance            Nullable(Float32),

    pickup_longitude         Nullable(Float64),
    pickup_latitude          Nullable(Float64),
    RateCodeID               Nullable(UInt8),
    store_and_fwd_flag       LowCardinality(Nullable(String)),
    dropoff_longitude        Nullable(Float64),
    dropoff_latitude         Nullable(Float64),

    payment_type             Nullable(UInt8),

    fare_amount              Nullable(Float32),
    extra                    Nullable(Float32),
    mta_tax                  Nullable(Float32),
    tip_amount               Nullable(Float32),
    tolls_amount             Nullable(Float32),
    improvement_surcharge    Nullable(Float32),
    total_amount             Nullable(Float32),

    -- Columnas derivadas (materializadas) para acelerar analítica
    pickup_date              Date MATERIALIZED toDate(tpep_pickup_datetime),
    pickup_hour              UInt8 MATERIALIZED toHour(tpep_pickup_datetime),
    pickup_yyyymm            UInt32 MATERIALIZED toYYYYMM(tpep_pickup_datetime),
    trip_duration_sec        UInt32 MATERIALIZED greatest(0, dateDiff('second', tpep_pickup_datetime, tpep_dropoff_datetime))
)
ENGINE = MergeTree
PARTITION BY pickup_yyyymm
ORDER BY (tpep_pickup_datetime, VendorID)
SETTINGS index_granularity = 8192;
