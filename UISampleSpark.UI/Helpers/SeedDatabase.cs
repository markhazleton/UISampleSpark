using Microsoft.Extensions.Logging;
using UISampleSpark.Data.Repository;

namespace UISampleSpark.UI.Helpers;

/// <summary>
/// Helper class for seeding the employee database with initial test data
/// </summary>
public static class SeedDatabase
{
    /// <summary>
    /// Initializes the database with sample departments and employees
    /// </summary>
    /// <param name="context">The employee database context to seed</param>
    public static async void DatabaseInitialization(EmployeeContext context)
    {
        try
        {
            using var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole());
            var serviceLogger = loggerFactory.CreateLogger<EmployeeDatabaseService>();
            var mockLogger = loggerFactory.CreateLogger<EmployeeMock>();
            
            EmployeeDatabaseService employeeService = new EmployeeDatabaseService(context, serviceLogger);
            CancellationToken token = new CancellationToken();
            EmployeeMock employeeMock = new EmployeeMock(mockLogger, 290);

            // First add all departments
            foreach (DepartmentDto dept in employeeMock.DepartmentCollection())
            {
                await employeeService.SaveAsync(dept, token).ConfigureAwait(true);
            }

            // Verify departments were added
            IEnumerable<DepartmentDto> d = await employeeService.GetDepartmentsAsync(true, token).ConfigureAwait(true);
            int departmentCount = d.Count();

            // Then add all employees
            employeeMock.EmployeeCollection()?.ForEach(async emp =>
            {
                await employeeService.SaveAsync(emp, token).ConfigureAwait(true);
            });

            // Verify employees were added
            IEnumerable<EmployeeDto> e = await employeeService.GetEmployeesAsync(new PagingParameterModel(), token).ConfigureAwait(true);
        }
        catch (InvalidOperationException ex)
        {
            // Database operation failed - log and continue (this is seed data)
            Console.WriteLine($"Database seed error: {ex.Message}");
        }
        catch (DbUpdateException ex)
        {
            // Database update failed - log and continue (this is seed data)
            Console.WriteLine($"Database update error during seed: {ex.Message}");
        }
    }
}
