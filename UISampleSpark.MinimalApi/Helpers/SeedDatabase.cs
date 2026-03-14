using Microsoft.Extensions.Logging;
using UISampleSpark.Core.Models;
using UISampleSpark.Data.Models;
using UISampleSpark.Data.Repository;
using UISampleSpark.Data.Services;

namespace UISampleSpark.MinimalApi.Helpers;

/// <summary>
/// Helper class for seeding the employee database with initial test data
/// </summary>
public static class SeedDatabase
{
    /// <summary>
    /// Initializes the database with sample departments and employees
    /// </summary>
    public static async void DatabaseInitialization(EmployeeContext context)
    {
        try
        {
            using var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole());
            var serviceLogger = loggerFactory.CreateLogger<EmployeeDatabaseService>();
            var mockLogger = loggerFactory.CreateLogger<EmployeeMock>();

            var employeeService = new EmployeeDatabaseService(context, serviceLogger);
            var token = new CancellationToken();
            var employeeMock = new EmployeeMock(mockLogger, 290);
            foreach (var dept in employeeMock.DepartmentCollection())
            {
                await employeeService.SaveAsync(dept, token).ConfigureAwait(true);
            }
            var d = await employeeService.GetDepartmentsAsync(true, token).ConfigureAwait(true);
            var departmentCount = d.Count();
            employeeMock.EmployeeCollection()?.ForEach(async emp =>
            {
                await employeeService.SaveAsync(emp, token).ConfigureAwait(true);
            });
            var e = await employeeService.GetEmployeesAsync(new PagingParameterModel(), token).ConfigureAwait(true);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Database seed error: {ex.Message}");
        }
    }
}
