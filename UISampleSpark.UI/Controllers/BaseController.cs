
using UISampleSpark.Core.Extensions;
using SkiaSharp;
using System.Diagnostics.CodeAnalysis;

namespace UISampleSpark.UI.Controllers;

/// <summary>
/// BaseController
/// </summary>
[ApiExplorerSettings(IgnoreApi = true)]
public abstract class BaseController : Controller
{
    private readonly IWebHostEnvironment webHostEnvironment;

    /// <summary>
    ///
    /// </summary>
    public readonly CancellationTokenSource cts;
    private readonly IConfiguration Config;
    private bool disposed = false;

    /// <summary>
    /// BaseController
    /// </summary>
    protected BaseController(IConfiguration configuration,
        IWebHostEnvironment hostEnvironment)
    {
        cts = new CancellationTokenSource();
        this.Config = configuration;
        webHostEnvironment = hostEnvironment;
    }
    /// <summary>
    /// Update File and return File Name
    /// </summary>
    /// <param name="ProfileImage"></param>
    /// <returns></returns>
    /// <param name="EmployeeId"></param>
    [SuppressMessage("Security", "CA3003:Review code for file path injection vulnerabilities", Justification = "EmployeeId is sanitized using Path.GetFileName to prevent path traversal attacks")]
    protected string? UploadedFile(IFormFile? ProfileImage, string EmployeeId)
    {
        if (ProfileImage is null) return null;

        // Sanitize EmployeeId to prevent path traversal attacks
        var sanitizedEmployeeId = Path.GetFileName(EmployeeId);
        if (string.IsNullOrWhiteSpace(sanitizedEmployeeId) || sanitizedEmployeeId.Contains(".."))
        {
            throw new ArgumentException("Invalid EmployeeId", nameof(EmployeeId));
        }

        string imagesRoot = Path.GetFullPath(Path.Combine(webHostEnvironment.WebRootPath, "images"));
        string folderPath = Path.GetFullPath(Path.Combine(imagesRoot, sanitizedEmployeeId));
        if (!folderPath.StartsWith(imagesRoot, StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException("Invalid EmployeeId", nameof(EmployeeId));
        }
        if (!Directory.Exists(folderPath))
        {
            Directory.CreateDirectory(folderPath);
        }
        string safeFileName = $"{Guid.NewGuid()}_{Path.GetFileNameWithoutExtension(ProfileImage.FileName)}.png";
        string filePath = Path.GetFullPath(Path.Combine(folderPath, safeFileName));

        using var stream = ProfileImage.OpenReadStream();
        using var original = SKBitmap.Decode(stream);
        using var scaled = original.ScaleImage(81);
        using var image = SKImage.FromBitmap(scaled);
        using var data = image.Encode(SKEncodedImageFormat.Png, 100);
        using var fileStream = System.IO.File.OpenWrite(filePath);
        data.SaveTo(fileStream);

        return $"{sanitizedEmployeeId}/{Path.GetFileName(filePath)}";
    }

    /// <summary>
    /// Dispose of managed resources
    /// </summary>
    protected override void Dispose(bool disposing)
    {
        if (!disposed)
        {
            if (disposing)
            {
                cts?.Dispose();
            }
            disposed = true;
        }
        base.Dispose(disposing);
    }


}
