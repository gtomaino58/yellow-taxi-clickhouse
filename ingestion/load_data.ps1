# ingestion/load_data.ps1
$ErrorActionPreference = "Stop"

$files = @(
  "yellow_tripdata_2015-01.csv",
  "yellow_tripdata_2016-01.csv",
  "yellow_tripdata_2016-02.csv",
  "yellow_tripdata_2016-03.csv"
)

foreach ($f in $files) {
  $path = Join-Path -Path "$PSScriptRoot\..\data" -ChildPath $f
  if (!(Test-Path $path)) { throw "No encuentro el fichero: $path" }

  Write-Host "Cargando $f ..."
  Get-Content $path -ReadCount 0 | docker exec -i clickhouse clickhouse-client `
    --query "INSERT INTO taxi.taxi_trips FORMAT CSVWithNames"

  Write-Host "OK $f"
}

Write-Host "Carga finalizada."
