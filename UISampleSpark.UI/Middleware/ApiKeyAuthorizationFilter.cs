using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc.Filters;

namespace UISampleSpark.UI.Middleware;

/// <summary>
/// Lightweight API key guard for API and selected MVC actions.
/// </summary>
public sealed class ApiKeyAuthorizationFilter : IAsyncActionFilter
{
    private const string ApiKeyHeader = "X-API-Key";
    private const string ApiKeyFormField = "apiKey";
    private const int MaxConfiguredKeys = 10;
    private readonly IConfiguration _configuration;

    public ApiKeyAuthorizationFilter(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        bool requireApiKey = _configuration.GetValue("ApiSecurity:RequireApiKey", true);
        if (!requireApiKey)
        {
            await next();
            return;
        }

        string[] configuredApiKeys = _configuration
            .GetSection("ApiSecurity:ApiKeys")
            .Get<string[]>()?
            .Where(static key => !string.IsNullOrWhiteSpace(key))
            .Take(MaxConfiguredKeys)
            .ToArray() ?? [];

        // If no keys are configured, do not block requests.
        if (configuredApiKeys.Length == 0)
        {
            await next();
            return;
        }

        string? providedApiKey = GetProvidedApiKey(context.HttpContext.Request);
        if (!IsApiKeyValid(providedApiKey, configuredApiKeys))
        {
            context.Result = new UnauthorizedObjectResult(new { error = "Missing or invalid API key." });
            return;
        }

        await next();
    }

    private static string? GetProvidedApiKey(HttpRequest request)
    {
        if (request.Headers.TryGetValue(ApiKeyHeader, out var headerValue))
        {
            return headerValue.ToString();
        }

        if (request.Cookies.TryGetValue(ApiKeyHeader, out var cookieValue))
        {
            return cookieValue;
        }

        if (request.HasFormContentType && request.Form.TryGetValue(ApiKeyFormField, out var formValue))
        {
            return formValue.ToString();
        }

        return null;
    }

    private static bool IsApiKeyValid(string? providedApiKey, IEnumerable<string> configuredApiKeys)
    {
        if (string.IsNullOrWhiteSpace(providedApiKey))
        {
            return false;
        }

        byte[] provided = Encoding.UTF8.GetBytes(providedApiKey);
        return configuredApiKeys
            .Select(Encoding.UTF8.GetBytes)
            .Any(expected => CryptographicOperations.FixedTimeEquals(provided, expected));
    }
}
