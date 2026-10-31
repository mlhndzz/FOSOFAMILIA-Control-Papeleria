
using Npgsql;

var builder = WebApplication.CreateBuilder(args);

// Configuración de ASP.NET Core
// El puerto se establece desde la terminal.
var app = builder.Build();

// Página principal de FOSOFAMILIA
app.MapGet("/", () => Results.Content("""
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>FOSOFAMILIA</title>
    <style>
        body {
            font-family: system-ui;
            background: #edf3f0;
            color: #164532;
            margin: 0;
        }

        main {
            max-width: 750px;
            margin: 8vh auto;
            padding: 3rem;
            background: white;
            border-radius: 24px;
            box-shadow: 0 10px 35px #183d2915;
        }

        small {
            color: #448568;
        }

        h1 {
            font-size: 2.5rem;
        }

        p {
            line-height: 1.7;
        }

        .tag {
            display: inline-block;
            background: #e1f2e8;
            padding: 10px 20px;
            border-radius: 30px;
        }
    </style>
</head>
<body>
    <main>
        <small>FOSOFAMILIA · SISTEMA INSTITUCIONAL</small>
        <h1>Control de Papelería y Útiles</h1>
        <p>
            Primera versión de desarrollo.
            Próximamente: usuarios, artículos, compras,
            requisiciones y reportes.
        </p>
        <p class="tag">ASP.NET Core + PostgreSQL</p>
    </main>
</body>
</html>
""", "text/html; charset=utf-8"));

// Verificar conexión a PostgreSQL
app.MapGet("/health", async (IConfiguration config) =>
{
    var connectionString =
        config.GetConnectionString("FosoFamilia");

    if (string.IsNullOrWhiteSpace(connectionString))
    {
        return Results.Json(
            new { database = "not_configured" },
            statusCode: 503
        );
    }

    try
    {
        await using var connection =
            new NpgsqlConnection(connectionString);

        await connection.OpenAsync();

        await using var command = new NpgsqlCommand(
            "SELECT to_regclass('papeleria.articulo') IS NOT NULL",
            connection
        );

        var result = await command.ExecuteScalarAsync();

        var databaseReady = result is bool ready && ready;

        if (databaseReady)
        {
            return Results.Ok(new
            {
                database = "ready"
            });
        }

        return Results.Json(
            new { database = "schema_missing" },
            statusCode: 503
        );
    }
    catch (NpgsqlException)
    {
        return Results.Json(
            new { database = "unavailable" },
            statusCode: 503
        );
    }
});

// Iniciar aplicación
app.Run();
