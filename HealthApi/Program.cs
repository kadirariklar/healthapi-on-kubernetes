var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

app.MapGet("/health", () =>
    Results.Json(new
    {
        status = "ok",
        version = "1.0.0"
    })
);

app.Urls.Add("http://0.0.0.0:8080");

app.Run();
