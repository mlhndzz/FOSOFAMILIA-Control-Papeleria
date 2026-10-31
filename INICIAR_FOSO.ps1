$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$project = Join-Path $repo 'src\FosoFamilia.Web\FosoFamilia.Web.csproj'
if (!(Test-Path $project)) { Write-Host 'No se encuentra FosoFamilia.Web.csproj' -ForegroundColor Red; exit 1 }
if (!(Get-Command dotnet -ErrorAction SilentlyContinue)) { Write-Host 'Instala .NET 8 SDK antes de ejecutar.' -ForegroundColor Red; exit 1 }

# Elegir un puerto local libre para evitar colisiones con IIS y otros servidores.
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()
$url = "http://127.0.0.1:$port"
$env:ASPNETCORE_ENVIRONMENT = 'Development'
$env:DOTNET_ENVIRONMENT = 'Development'
Write-Host "Iniciando FOSOFAMILIA en $url" -ForegroundColor Cyan
Write-Host 'Restaurando dependencias...' -ForegroundColor Gray
& dotnet restore $project
if ($LASTEXITCODE -ne 0) { throw 'dotnet restore fallo.' }

# Ejecutar sin pasar credenciales en argumentos y sin abrir navegadores/proxies de VS Code.
# Registrar el proceso para inspeccionar su salida sin que el comando quede bloqueado.
$log = Join-Path $env:TEMP ('foso_' + $port + '.out.log')
$errlog = Join-Path $env:TEMP ('foso_' + $port + '.err.log')
$process = Start-Process -FilePath 'dotnet' -ArgumentList @('run','--no-launch-profile','--project',('"'+$project+'"'),'--urls',('"'+$url+'"')) -WorkingDirectory (Split-Path $project) -RedirectStandardOutput $log -RedirectStandardError $errlog -PassThru -WindowStyle Hidden

# Compatible con Windows PowerShell 5.1: sin HttpClientHandler ni proxy.
function Test-FosoHttp([string]$target) {
    $request = [System.Net.HttpWebRequest][System.Net.WebRequest]::Create($target)
    $request.Proxy = $null
    $request.Timeout = 2000
    $request.ReadWriteTimeout = 2000
    try {
        $response = [System.Net.HttpWebResponse]$request.GetResponse()
        try {
            $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
            try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
            return @{ Status = [int]$response.StatusCode; Body = $body }
        } finally { $response.Dispose() }
    } catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $response = [System.Net.HttpWebResponse]$_.Exception.Response
            try {
                $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
                try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
                return @{ Status = [int]$response.StatusCode; Body = $body }
            } finally { $response.Dispose() }
        }
        return $null
    }
}
$ready = $false
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 1
    $process.Refresh()
    if ($process.HasExited) { break }
    $check = Test-FosoHttp ($url + '/')
    if ($check -and $check.Status -eq 200) { $ready = $true; break }
}
if (!$ready) {
    Write-Host 'La aplicacion no respondio correctamente. Registros:' -ForegroundColor Red
    if (Test-Path $log) { Get-Content $log -Tail 25 }
    if (Test-Path $errlog) { Get-Content $errlog -Tail 25 }
    Write-Host ('Log: ' + $log)
    exit 1
}
Write-Host 'Pagina principal: OK (conexion local sin proxy).' -ForegroundColor Green
$health = Test-FosoHttp ($url + '/health')
if ($health) {
    Write-Host ('PostgreSQL /health: ' + $health.Body)
    if ($health.Status -ne 200) { Write-Host 'Revisar credenciales de User Secrets; comprobar puerto PostgreSQL 18 = 5432.' -ForegroundColor Yellow }
} else {
    Write-Host 'No se pudo comprobar /health.' -ForegroundColor Yellow
}
Write-Host ('Abriendo ' + $url) -ForegroundColor Cyan
Start-Process -FilePath "explorer.exe" -ArgumentList $url
Write-Host ('Servidor activo, proceso PID ' + $process.Id + '. Para detenerlo: Stop-Process -Id ' + $process.Id) -ForegroundColor Gray
Write-Host ('Log: ' + $log) -ForegroundColor Gray

