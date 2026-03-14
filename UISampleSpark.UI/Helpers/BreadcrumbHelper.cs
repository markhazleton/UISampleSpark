using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace UISampleSpark.UI.Helpers;

/// <summary>
/// Helper class for generating breadcrumb navigation
/// </summary>
public static class BreadcrumbHelper
{
    /// <summary>
    /// Generate breadcrumbs based on the current route
    /// </summary>
    public static List<(string Name, string Url)> GenerateBreadcrumbs(ViewContext viewContext)
    {
        ArgumentNullException.ThrowIfNull(viewContext);

        var breadcrumbs = new List<(string Name, string Url)>();

        // Always start with Home
        breadcrumbs.Add(("Home", "/"));

        var controllerName = viewContext.RouteData.Values["controller"]?.ToString();
        var actionName = viewContext.RouteData.Values["action"]?.ToString();
        var idValue = viewContext.RouteData.Values["id"]?.ToString();

        // Handle Razor Pages first - check if this is a Razor Page request
        var isRazorPage = viewContext.ActionDescriptor.DisplayName?.Contains("Pages") == true ||
                         viewContext.HttpContext.Request.Path.Value?.Contains("/EmployeeRazor") == true ||
                         viewContext.ActionDescriptor.GetType().Name.Contains("CompiledPageActionDescriptor");

        if (isRazorPage)
        {
            breadcrumbs.Add(("Employee Razor Pages", "/EmployeeRazor"));

            var path = viewContext.HttpContext.Request.Path.Value;
            var pageName = path?.Split('/', StringSplitOptions.RemoveEmptyEntries).LastOrDefault();

            // Handle the case where URL is just /EmployeeRazor (Index page)
            if (string.IsNullOrEmpty(pageName) || pageName.Equals("EmployeeRazor", StringComparison.OrdinalIgnoreCase))
            {
                // This is the Index page, we already have the breadcrumbs we need
                return breadcrumbs;
            }

            // Handle other pages (Create, Edit, Details, Delete, etc.)
            if (!string.IsNullOrEmpty(pageName))
            {
                AddPageBreadcrumb(breadcrumbs, pageName, idValue);
            }

            return breadcrumbs;
        }

        // Skip if we're already on the home page (for regular MVC controllers)
        if ((string.IsNullOrEmpty(controllerName) || controllerName.Equals("Home", StringComparison.OrdinalIgnoreCase))
            && (string.IsNullOrEmpty(actionName) || actionName.Equals("Index", StringComparison.OrdinalIgnoreCase)))
        {
            return breadcrumbs;
        }

        // Handle different controller patterns
        switch (controllerName?.ToLower())
        {
            case "mvcemployee":
                breadcrumbs.Add(("Employee Management", "/MvcEmployee"));
                AddActionBreadcrumb(breadcrumbs, actionName, idValue, "/MvcEmployee");
                break;

            case "employee":
                breadcrumbs.Add(("Employee AJAX", "/Employee"));
                AddActionBreadcrumb(breadcrumbs, actionName, idValue, "/Employee");
                break;

            case "employeesinglepage":
                breadcrumbs.Add(("Single Page App", "/EmployeeSinglePage"));
                AddActionBreadcrumb(breadcrumbs, actionName, idValue, "/EmployeeSinglePage");
                break;

            case "employeepivot":
                breadcrumbs.Add(("Employee Pivot", "/EmployeePivot"));
                AddActionBreadcrumb(breadcrumbs, actionName, idValue, "/EmployeePivot");
                break;

            default:
                // Handle other controllers generically
                if (!string.IsNullOrEmpty(controllerName))
                {
                    var controllerDisplayName = FormatControllerName(controllerName);
                    breadcrumbs.Add((controllerDisplayName, $"/{controllerName}"));
                    AddActionBreadcrumb(breadcrumbs, actionName, idValue, $"/{controllerName}");
                }
                break;
        }

        return breadcrumbs;
    }

    /// <summary>
    /// Add action-specific breadcrumb
    /// </summary>
    private static void AddActionBreadcrumb(List<(string Name, string Url)> breadcrumbs, string? actionName, string? idValue, string basePath)
    {
        if (string.IsNullOrEmpty(actionName) || actionName.Equals("Index", StringComparison.OrdinalIgnoreCase))
            return;

        switch (actionName.ToLower())
        {
            case "create":
                breadcrumbs.Add(("Create Employee", $"{basePath}/Create"));
                break;

            case "edit":
                breadcrumbs.Add(("Edit Employee", string.IsNullOrEmpty(idValue) ? $"{basePath}/Edit" : $"{basePath}/Edit/{idValue}"));
                break;

            case "details":
                breadcrumbs.Add(("Employee Details", string.IsNullOrEmpty(idValue) ? $"{basePath}/Details" : $"{basePath}/Details/{idValue}"));
                break;

            case "delete":
                breadcrumbs.Add(("Delete Employee", string.IsNullOrEmpty(idValue) ? $"{basePath}/Delete" : $"{basePath}/Delete/{idValue}"));
                break;

            default:
                var actionDisplayName = FormatActionName(actionName);
                breadcrumbs.Add((actionDisplayName, $"{basePath}/{actionName}"));
                break;
        }
    }

    /// <summary>
    /// Add page-specific breadcrumb for Razor Pages
    /// </summary>
    private static void AddPageBreadcrumb(List<(string Name, string Url)> breadcrumbs, string pageName, string? idValue)
    {
        switch (pageName.ToLower())
        {
            case "create":
                breadcrumbs.Add(("Create Employee", "/EmployeeRazor/Create"));
                break;

            case "edit":
                breadcrumbs.Add(("Edit Employee", string.IsNullOrEmpty(idValue) ? "/EmployeeRazor/Edit" : $"/EmployeeRazor/Edit/{idValue}"));
                break;

            case "details":
                breadcrumbs.Add(("Employee Details", string.IsNullOrEmpty(idValue) ? "/EmployeeRazor/Details" : $"/EmployeeRazor/Details/{idValue}"));
                break;

            case "delete":
                breadcrumbs.Add(("Delete Employee", string.IsNullOrEmpty(idValue) ? "/EmployeeRazor/Delete" : $"/EmployeeRazor/Delete/{idValue}"));
                break;

            default:
                var pageDisplayName = FormatPageName(pageName);
                breadcrumbs.Add((pageDisplayName, $"/EmployeeRazor/{pageName}"));
                break;
        }
    }

    /// <summary>
    /// Format controller name for display
    /// </summary>
    private static string FormatControllerName(string controllerName)
    {
        return controllerName switch
        {
            "MvcEmployee" => "MVC Employee",
            "EmployeeSinglePage" => "Single Page App",
            "EmployeePivot" => "Employee Pivot",
            _ => controllerName
        };
    }

    /// <summary>
    /// Format action name for display
    /// </summary>
    private static string FormatActionName(string actionName)
    {
        return actionName switch
        {
            "Create" => "Create",
            "Edit" => "Edit",
            "Details" => "Details",
            "Delete" => "Delete",
            _ => actionName
        };
    }

    /// <summary>
    /// Format page name for display
    /// </summary>
    private static string FormatPageName(string pageName)
    {
        return pageName switch
        {
            "Create" => "Create",
            "Edit" => "Edit",
            "Details" => "Details",
            "Delete" => "Delete",
            _ => pageName
        };
    }
}
