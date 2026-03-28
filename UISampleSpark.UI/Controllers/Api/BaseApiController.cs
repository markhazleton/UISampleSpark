
namespace UISampleSpark.UI.Controllers.Api;

using UISampleSpark.UI.Middleware;

/// <summary>
/// Base for all Api Controllers in this project
/// </summary>
[Produces("application/json")]
[ApiController]
[ServiceFilter(typeof(ApiKeyAuthorizationFilter))]
public abstract class BaseApiController : ControllerBase
{

}
