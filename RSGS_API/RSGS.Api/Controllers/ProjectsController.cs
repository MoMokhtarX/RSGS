using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Interfaces;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProjectsController : BaseApiController
{
    private readonly IProjectService _service;
    public ProjectsController(IProjectService service) => _service = service;

    [HttpGet]
    [Authorize(Roles = "Admin,Sales,Engineer,Accountant,Manager")]
    public async Task<IActionResult> GetAll() => Success(await _service.GetAllAsync());

    [HttpGet("next-number")]
    [Authorize(Roles = "Admin,Sales,Manager")]
    public async Task<IActionResult> NextNumber() => Success(new { number = await _service.GetNextProjectNumberAsync() });

    [HttpGet("{id}")]
    [Authorize(Roles = "Admin,Sales,Engineer,Accountant,Manager")]
    public async Task<IActionResult> GetById(int id)
    {
        var project = await _service.GetByIdAsync(id);
        return project == null ? NotFoundResponse("Project not found.") : Success(project);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,Sales,Manager")]
    public async Task<IActionResult> Create(CreateProjectDto dto) => CreatedResponse(await _service.CreateAsync(dto), "Project created successfully.");

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,Sales,Manager")]
    public async Task<IActionResult> Update(int id, UpdateProjectDto dto)
    {
        var project = await _service.UpdateAsync(id, dto);
        return project == null ? NotFoundResponse("Project not found.") : Success(project, "Project updated successfully.");
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _service.DeleteAsync(id);
        return deleted ? Success("", "Project deleted successfully.") : NotFoundResponse("Project not found.");
    }

    [HttpDelete("all")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteAll() => Success(new { count = await _service.DeleteAllAsync() }, "Projects deleted successfully.");

    [HttpPut("{id}/assign-engineer/{engineerId}")]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<IActionResult> AssignEngineer(int id, int engineerId)
    {
        var result = await _service.AssignEngineerAsync(id, engineerId);
        return result ? Success("", "Engineer assigned successfully.") : NotFoundResponse("Project not found.");
    }

    [HttpPut("{id}/status")]
    [Authorize(Roles = "Admin,Engineer,Manager")]
    public async Task<IActionResult> ChangeStatus(int id, [FromBody] ProjectStatus status)
    {
        var result = await _service.ChangeStatusAsync(id, status);
        return result ? Success("", "Project status updated.") : NotFoundResponse("Project not found.");
    }
}
