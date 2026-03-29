using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;

namespace UISampleSpark.MinimalApi.Middleware;

/// <summary>
/// Global exception handler for the Minimal API host.
/// Converts unhandled exceptions to RFC 7807 ProblemDetails responses.
/// Implements Principle III of the project constitution (Error Handling &amp; API Contracts).
/// </summary>
public class GlobalExceptionHandler : IExceptionHandler
{
    private readonly ILogger<GlobalExceptionHandler> _logger;
    private readonly IHostEnvironment _environment;

    public GlobalExceptionHandler(
        ILogger<GlobalExceptionHandler> logger,
        IHostEnvironment environment)
    {
        _logger = logger;
        _environment = environment;
    }

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(httpContext);
        ArgumentNullException.ThrowIfNull(exception);

        var traceId = Activity.Current?.Id ?? httpContext.TraceIdentifier;

        var sanitizedPath = (httpContext.Request.Path.Value ?? "/")
            .Replace("\r", "", StringComparison.Ordinal)
            .Replace("\n", "", StringComparison.Ordinal);
        var sanitizedMethod = httpContext.Request.Method
            .Replace("\r", "", StringComparison.Ordinal)
            .Replace("\n", "", StringComparison.Ordinal);

        _logger.LogError(
            exception,
            "Unhandled exception occurred. TraceId: {TraceId}, Path: {Path}, Method: {Method}",
            traceId,
            sanitizedPath,
            sanitizedMethod);

        var statusCode = DetermineStatusCode(exception);

        var problemDetails = new ProblemDetails
        {
            Status = statusCode,
            Title = GetTitleForStatusCode(statusCode),
            Detail = GetDetailMessage(exception),
            Instance = httpContext.Request.Path,
            Type = $"https://httpstatuses.com/{statusCode}",
            Extensions =
            {
                ["traceId"] = traceId,
                ["timestamp"] = DateTime.UtcNow.ToString("o"),
                ["exceptionType"] = exception.GetType().Name
            }
        };

        if (_environment.IsDevelopment())
        {
            problemDetails.Extensions["stackTrace"] = exception.StackTrace;
            problemDetails.Extensions["source"] = exception.Source;

            if (exception.InnerException != null)
            {
                problemDetails.Extensions["innerException"] = new
                {
                    message = exception.InnerException.Message,
                    type = exception.InnerException.GetType().Name
                };
            }
        }

        httpContext.Response.StatusCode = statusCode;
        httpContext.Response.ContentType = "application/problem+json";

        await httpContext.Response.WriteAsJsonAsync(problemDetails, cancellationToken);

        return true;
    }

    private static int DetermineStatusCode(Exception exception) => exception switch
    {
        ArgumentNullException => StatusCodes.Status400BadRequest,
        ArgumentException => StatusCodes.Status400BadRequest,
        InvalidOperationException => StatusCodes.Status400BadRequest,
        UnauthorizedAccessException => StatusCodes.Status401Unauthorized,
        KeyNotFoundException => StatusCodes.Status404NotFound,
        NotImplementedException => StatusCodes.Status501NotImplemented,
        TimeoutException => StatusCodes.Status408RequestTimeout,
        _ => StatusCodes.Status500InternalServerError
    };

    private static string GetTitleForStatusCode(int statusCode) => statusCode switch
    {
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        408 => "Request Timeout",
        500 => "Internal Server Error",
        501 => "Not Implemented",
        503 => "Service Unavailable",
        _ => "Error"
    };

    private string GetDetailMessage(Exception exception)
    {
        if (_environment.IsDevelopment())
        {
            return exception.Message;
        }

        return exception switch
        {
            ArgumentNullException => "A required parameter was not provided.",
            ArgumentException => "The request contained invalid arguments. Please check your input and try again.",
            UnauthorizedAccessException => "You do not have permission to access this resource.",
            KeyNotFoundException => "The requested resource was not found.",
            NotImplementedException => "This feature is not yet implemented.",
            TimeoutException => "The request took too long to complete. Please try again later.",
            _ => "An unexpected error occurred. Please contact support if the issue persists."
        };
    }
}
