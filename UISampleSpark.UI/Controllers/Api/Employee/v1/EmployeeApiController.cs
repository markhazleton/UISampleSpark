namespace UISampleSpark.UI.Controllers.Api.Employee.v1;

/// <summary>
/// Employee management API endpoints for CRUD operations.
/// </summary>
/// <remarks>
/// This controller provides RESTful endpoints for managing employee records using the repository pattern.
/// All operations use Entity Framework Core with in-memory database for educational purposes.
/// <para>
/// <b>Educational Project:</b> This API does not implement authentication or authorization by design.
/// Do not deploy to production without adding security features.
/// </para>
/// </remarks>
[Route("api/employee")]
[ApiController]
public class EmployeeApiController : BaseApiController
{
    private readonly IEmployeeService _employeeService;

    /// <summary>
    /// Initializes a new instance of the <see cref="EmployeeApiController"/> class.
    /// </summary>
    /// <param name="employeeService">The employee service for data operations.</param>
    public EmployeeApiController(IEmployeeService employeeService) : base()
    {
        _employeeService = employeeService;
    }

    /// <summary>
    /// Deletes an employee by their unique identifier.
    /// </summary>
    /// <remarks>
    /// Removes the employee record from the database. This operation cannot be undone.
    /// <para><b>Example:</b> DELETE /api/employee/1</para>
    /// </remarks>
    /// <param name="id">The unique identifier of the employee to delete.</param>
    /// <param name="cancellationToken">Cancellation token for async operation.</param>
    /// <returns>
    /// An <see cref="ActionResult{EmployeeResponse}"/> containing:
    /// <list type="bullet">
    /// <item>200 OK with success response if deletion successful</item>
    /// <item>400 Bad Request if employee not found or deletion fails</item>
    /// </list>
    /// </returns>
    /// <response code="200">Employee successfully deleted.</response>
    /// <response code="400">Employee not found or could not be deleted.</response>
    [HttpDelete("{id}", Name = "DeleteEmployee")]
    [ProducesResponseType(typeof(EmployeeDto), 200)]
    [ProducesResponseType(typeof(ErrorResource), 400)]
    public async Task<ActionResult<EmployeeResponse>> DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        EmployeeResponse result = await _employeeService.DeleteAsync(id, cancellationToken);

        if (!result.Success)
        {
            return BadRequest(new ErrorResource(result.Message));
        }

        return Ok(result);
    }

    /// <summary>
    /// Retrieves a single employee by their unique identifier.
    /// </summary>
    /// <remarks>
    /// Returns the complete employee record including department information.
    /// <para><b>Example:</b> GET /api/employee/1</para>
    /// </remarks>
    /// <param name="id">The unique identifier of the employee to retrieve.</param>
    /// <param name="cancellationToken">Cancellation token for async operation.</param>
    /// <returns>
    /// An <see cref="ActionResult{EmployeeResponse}"/> containing:
    /// <list type="bullet">
    /// <item>200 OK with employee data if found</item>
    /// <item>400 Bad Request if employee not found</item>
    /// </list>
    /// </returns>
    /// <response code="200">Employee found and returned successfully.</response>
    /// <response code="400">Employee with specified ID not found.</response>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(EmployeeDto), 200)]
    [ProducesResponseType(typeof(ErrorResource), 400)]
    public async Task<ActionResult<EmployeeResponse>> FindByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        EmployeeResponse result = await _employeeService.FindEmployeeByIdAsync(id, cancellationToken);

        if (!result.Success)
        {
            return BadRequest(result);
        }

        return Ok(result);
    }

    /// <summary>
    /// Returns collection of all employees
    /// </summary>
    /// <param name="paging">Paging parameters</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Collection of employees</returns>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<EmployeeDto>), 200)]
    public async Task<ActionResult<IEnumerable<EmployeeDto>>> ListAsync(
        [FromQuery] PagingParameterModel? paging = null, 
        CancellationToken cancellationToken = default)
    {
        paging ??= new PagingParameterModel();

        IEnumerable<EmployeeDto> employees = await _employeeService.GetEmployeesAsync(paging, cancellationToken);
        
        return Ok(employees);
    }

    /// <summary>
    /// Creates a new employee.
    /// </summary>
    /// <param name="employee">Employee data.</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Response for the request.</returns>
    [HttpPost]
    [IgnoreAntiforgeryToken] // REST API uses JSON body; CSRF not applicable for non-browser clients
    [ProducesResponseType(typeof(EmployeeDto), 201)]
    [ProducesResponseType(typeof(ErrorResource), 400)]
    public async Task<ActionResult> PostAsync([FromBody] EmployeeDto? employee, CancellationToken cancellationToken = default)
    {
        if (employee is null)
            return BadRequest("Employee was null");

        EmployeeResponse result = await _employeeService.SaveAsync(employee, cancellationToken);

        if (!result.Success)
        {
            return BadRequest(new ErrorResource(result.Message));
        }

        return Created($"/api/Employee/{employee.Id}", employee);
    }

    /// <summary>
    /// Updates an existing employee according to an identifier.
    /// </summary>
    /// <param name="id">Employee identifier.</param>
    /// <param name="employee">Updated employee data.</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Response for the request.</returns>
    [HttpPut("{id}")]
    [ProducesResponseType(typeof(EmployeeDto), 200)]
    [ProducesResponseType(typeof(ErrorResource), 400)]
    public async Task<ActionResult<EmployeeResponse>> PutAsync(
        int id, 
        [FromBody] EmployeeDto employee, 
        CancellationToken cancellationToken = default)
    {
        EmployeeResponse result = await _employeeService.UpdateAsync(id, employee, cancellationToken);

        if (!result.Success)
        {
            return BadRequest(new ErrorResource(result.Message));
        }

        return Ok(result);
    }
}
