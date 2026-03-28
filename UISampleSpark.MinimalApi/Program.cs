using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi;
using UISampleSpark.Core.Interfaces;
using UISampleSpark.Core.Models;
using UISampleSpark.Data.Models;
using UISampleSpark.Data.Services;
using UISampleSpark.MinimalApi.Helpers;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
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
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Version = "v8",
        Title = "UI Sample Spark API",
        Description = "Employee management API for UI Sample Spark",
        Contact = new OpenApiContact
        {
            Name = "Mark Hazleton",
            Url = new Uri("https://markhazleton.com")
        },
    });
});

builder.Services.AddDbContext<EmployeeContext>(opt => opt.UseInMemoryDatabase("Employee"));
builder.Services.AddScoped<IEmployeeService, EmployeeDatabaseService>();
builder.Services.AddScoped<IEmployeeClient, EmployeeDatabaseClient>();
SeedDatabase.DatabaseInitialization(new EmployeeContext());


var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
app.UseHttpsRedirection();
app.UseRateLimiter();

app.MapPost("/employees", async (IEmployeeService employeeService, EmployeeDto employee, CancellationToken token) =>
{
    var result = await employeeService.SaveAsync(employee, token);
    if (result is null)
    {
        return Results.BadRequest("Employee not saved");
    }
    if (result.Resource is null)
    {
        return Results.BadRequest("Employee not saved");
    }
    if (!result.Success)
    {
        return Results.BadRequest("Employee not saved");
    }

    return Results.Created($"/employees/{result.Resource.Id}", result);
}).RequireRateLimiting("PerIpLimit");

app.MapGet("/employees", async (IEmployeeService employeeService, CancellationToken token) =>
{
    var paging = new PagingParameterModel();
    var employees = await employeeService.GetEmployeesAsync(paging, token);
    return employees;
}).RequireRateLimiting("PerIpLimit");

app.MapGet("/employees/{id}", async (IEmployeeService employeeService, int id, CancellationToken token) =>
{
    var employee = await employeeService.FindEmployeeByIdAsync(id, token);
    if (employee == null)
    {
        return Results.NotFound();
    }
    return Results.Ok(employee);
}).RequireRateLimiting("PerIpLimit");

app.MapGet("/departments", async (IEmployeeService employeeService, CancellationToken token) =>
{
    var employee = await employeeService.GetDepartmentsAsync(false, token);
    return employee;
}).RequireRateLimiting("PerIpLimit");

app.Run();

public static class EmployeeGroupEndpoints
{
    public static RouteGroupBuilder MapEmployeeApi(this RouteGroupBuilder group, IEmployeeService employeeService)
    {
        group.MapGet("/", employeeService.GetEmployeesAsync);
        group.MapGet("/{id}", employeeService.FindDepartmentByIdAsync);
        group.MapDelete("/{id}", employeeService.DeleteAsync);
        return group;
    }
}