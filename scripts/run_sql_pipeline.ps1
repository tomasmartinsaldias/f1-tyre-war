<#
.SYNOPSIS
    Ejecuta el pipeline de carga SQL y creación de vistas para F1 Tyre War.
.DESCRIPTION
    Invoca el script Python scripts/run_sql_pipeline.py con los parámetros proporcionados
    o variables de entorno correspondientes.
.PARAMETER Hostname
    Servidor PostgreSQL (por defecto: localhost o $env:PGHOST)
.PARAMETER Port
    Puerto PostgreSQL (por defecto: 5432 o $env:PGPORT)
.PARAMETER Database
    Nombre de la base de datos (por defecto: postgres o $env:PGDATABASE)
.PARAMETER User
    Usuario de PostgreSQL (por defecto: postgres o $env:PGUSER)
.PARAMETER Password
    Contraseña de PostgreSQL (por defecto: postgres o $env:PGPASSWORD)
.EXAMPLE
    .\scripts\run_sql_pipeline.ps1
.EXAMPLE
    .\scripts\run_sql_pipeline.ps1 -User postgres -Password mipassword
#>
[CmdletBinding()]
param(
    [string]$Hostname = $(if ($env:PGHOST) { $env:PGHOST } else { "localhost" }),
    [int]$Port = $(if ($env:PGPORT) { [int]$env:PGPORT } else { 5432 }),
    [string]$Database = $(if ($env:PGDATABASE) { $env:PGDATABASE } else { "postgres" }),
    [string]$User = $(if ($env:PGUSER) { $env:PGUSER } else { "postgres" }),
    [string]$Password = $(if ($env:PGPASSWORD) { $env:PGPASSWORD } else { "postgres" })
)

$scriptPath = Join-Path $PSScriptRoot "run_sql_pipeline.py"

python $scriptPath --host $Hostname --port $Port --dbname $Database --user $User --password $Password
