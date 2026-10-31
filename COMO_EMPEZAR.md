# FOSOFAMILIA — versión corregida para Windows

## Ejecutar (un comando)

Abre la carpeta `foso_entregas` en VS Code y, **en la terminal PowerShell de esa carpeta**, ejecuta:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\INICIAR_FOSO.ps1
```

El script selecciona un puerto disponible, inicia la aplicación en modo Development, prueba la página principal **sin proxy** y abre el navegador. Copia la URL que muestre la terminal; el puerto puede cambiar en cada ejecución.

## PostgreSQL (solo si /health no dice `ready`)

La base ya debe existir en el servidor de PostgreSQL 18 (puerto `5432`) y contener la tabla `papeleria.articulo`. Para configurar el acceso sin escribir la contraseña en el proyecto, desde `src/FosoFamilia.Web` ejecuta:

```powershell
dotnet user-secrets init
$clave = Read-Host 'Clave del usuario postgres' -AsSecureString
$cred = [System.Net.NetworkCredential]::new('', $clave)
$cadena = 'Host=localhost;Port=5432;Database=foso_test;Username=postgres;Password=' + $cred.Password
dotnet user-secrets set 'ConnectionStrings:FosoFamilia' $cadena
Remove-Variable clave, cred, cadena
```

No compartas ni subas contraseñas. Es necesario ejecutar la aplicación en **Development** para que cargue User Secrets.

## Solución del HTTP 400 "Invalid Hostname"

- Se corrigió `AllowedHosts` para aceptar **localhost** y **127.0.0.1**.
- El `Program.cs` no fija el puerto. El iniciador elige uno libre.
- Si la prueba HTTP sin proxy del iniciador dice `OK`, pero el navegador todavía muestra 400, revisa proxy/configuración del navegador o extensiones. Abre la URL mostrada en un navegador externo, no el navegador integrado de VS Code.
- La ruta `/health` devuelve `ready` únicamente si PostgreSQL está conectado y existe `papeleria.articulo`.

## Seguridad y alcance

El ZIP excluye `bin/`, `obj/`, contraseñas, cachés y archivos temporales. `.gitignore` evita subir compilaciones. El proyecto sigue siendo un prototipo inicial, sin autenticación: úsalo solo en localhost.

## GitHub

Después de probar, desde `foso_entregas`:

```powershell
git status
git add .gitignore COMO_EMPEZAR.md INICIAR_FOSO.ps1 docs/informes src/FosoFamilia.Web/Program.cs src/FosoFamilia.Web/appsettings.json src/FosoFamilia.Web/FosoFamilia.Web.csproj
git commit -m 'Corrige inicio local y agrega entregas 2, 3 y 4'
```

Configura el repositorio remoto antes de ejecutar `git push`.


Si el navegador integrado de VS Code falla, abrir la URL impresa en Edge externo. El iniciador usa una comprobacion HTTP directa sin proxy (compatible con PowerShell 5.1).
