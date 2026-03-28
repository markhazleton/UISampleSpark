using Microsoft.OpenApi;
using UISampleSpark.UI.Middleware;
using Swashbuckle.AspNetCore.SwaggerGen;
using WebSpark.Bootswatch;
using WebSpark.HttpClientUtility.RequestResult;
using Westwind.AspNetCore.Markdown;
using System.Threading.RateLimiting;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// Lightweight abuse protection: limit each client IP to 100 requests/minute.
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.OnRejected = async (context, token) =>
    {
        context.HttpContext.Response.Headers.RetryAfter = "60";
        await context.HttpContext.Response.WriteAsync("Too many requests. Please try again later.", token).ConfigureAwait(false);
    };

    options.AddPolicy("PerIpLimit", httpContext =>
    {
        string key = httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        return RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: key,
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 100,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            });
    });
});

// Configure Swagger/OpenAPI
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Version = "v10",
        Title = "UI Sample Spark API",
        Description = "Employee management API for UI Sample Spark",
        Contact = new OpenApiContact
        {
            Name = "Mark Hazleton",
            Url = new Uri("https://markhazleton.com")
        },
    });
});

// Database and data access services
builder.Services.AddDbContext<EmployeeContext>(opt => 
    opt.UseInMemoryDatabase("Employee"));
builder.Services.AddScoped<IEmployeeService, EmployeeDatabaseService>();
builder.Services.AddScoped<IEmployeeClient, EmployeeDatabaseClient>();

// Seed database during startup
using (var context = new EmployeeContext())
{
    SeedDatabase.DatabaseInitialization(context);
}

// HTTP and infrastructure services
builder.Services.AddHttpClient();
builder.Services.TryAddSingleton<IHttpContextAccessor, HttpContextAccessor>();

// Application-specific services
builder.Services.AddScoped<IHttpRequestResultService, HttpRequestResultService>();
builder.Services.AddBootswatchThemeSwitcher();
builder.Services.AddMarkdown();

// Session and MVC configuration
builder.Services.AddSession();
builder.Services.AddRazorPages();
builder.Services.AddControllersWithViews(options =>
    options.Filters.Add(new Microsoft.AspNetCore.Mvc.AutoValidateAntiforgeryTokenAttribute()));
builder.Services.AddServerSideBlazor();

// Monitoring and diagnostics
var appInsightsConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
if (!string.IsNullOrWhiteSpace(appInsightsConnectionString))
{
    builder.Services.AddApplicationInsightsTelemetry(options =>
    {
        options.ConnectionString = appInsightsConnectionString;
    });
}
builder.Services.AddHealthChecks();

// Problem details for standardized error responses
builder.Services.AddProblemDetails();

// Global exception handler (Constitution Principle III)
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();

WebApplication app = builder.Build();

// Configure middleware pipeline
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
else
{
    // Use global exception handler for standardized ProblemDetails responses
    app.UseExceptionHandler();
    app.UseHsts();
}

// Swagger configuration
app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "UI Sample Spark API v10");
    options.DocumentTitle = "UI Sample Spark API";
    options.InjectStylesheet("/swagger_custom/custom.css");
    options.RoutePrefix = "swagger";
});

// Request pipeline
app.UseMyHttpContext();
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseBootswatchAll();

app.UseRouting();
app.UseRateLimiter();
app.UseAuthorization();
app.UseSession();

// Health check endpoint
app.MapHealthChecks("/health");

// Map controllers and pages
app.MapControllers().RequireRateLimiting("PerIpLimit");
app.MapRazorPages();
app.MapBlazorHub();

// Map MVC routes using modern endpoint routing
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.MapControllerRoute(
    name: "home",
    pattern: "home/index",
    defaults: new { controller = "Home", action = "Index" });

app.MapControllerRoute(
    name: "index",
    pattern: "index.html",
    defaults: new { controller = "Home", action = "Index" });

// Markdown middleware
app.UseMarkdown();

app.Run();
