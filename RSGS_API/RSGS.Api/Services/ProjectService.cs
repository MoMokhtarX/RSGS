using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Repositories.Interfaces;
using RSGS.Api.Exceptions;
using RSGS.Api.Utilities;
using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;

namespace RSGS.Api.Services;

public class ProjectService : IProjectService
{
    private readonly IProjectRepository _repository;
    private readonly IActivityLogService _activityLogService;
    private readonly IAuditService _auditService;
    private readonly AppDbContext _db;
    private readonly ICurrentUserService _currentUser;

    public ProjectService(
        IProjectRepository repository,
        IActivityLogService activityLogService,
        ICurrentUserService currentUser,
        IAuditService auditService,
        AppDbContext db)
    {
        _repository = repository;
        _activityLogService = activityLogService;
        _currentUser = currentUser;
        _auditService = auditService;
        _db = db;
    }

    public async Task<List<ProjectListItemDto>> GetAllAsync()
    {
        int? engineerId = null;

        if (_currentUser.Role == UserRole.Engineer.ToString())
        {
            engineerId = _currentUser.UserId;
        }

        var projects = await _repository.GetAllScopedAsync(engineerId);

        return projects.Select(MapToListItemDto).ToList();
    }

    public async Task<ProjectResponseDto?> GetByIdAsync(int id)
    {
        var project = await _repository.GetProjectDetailsAsync(id);

        if (project == null)
            return null;

        EnsureEngineerCanAccess(project);

        return MapToResponseDto(project);
    }

    public async Task<ProjectResponseDto> CreateAsync(CreateProjectDto dto)
    {
        EnsureNotEngineerForManagement();

        if (string.IsNullOrWhiteSpace(dto.ProjectNumber))
            throw new BusinessException("Project number is required.");

        var normalizedProjectNumber = dto.ProjectNumber.Trim();

        if (!await _repository.CustomerExistsAsync(dto.CustomerId))
            throw new BusinessException("Customer not found.");

        if (dto.EngineerId.HasValue &&
            !await _repository.IsValidEngineerAsync(dto.EngineerId.Value))
        {
            throw new BusinessException("Selected engineer is invalid.");
        }

        var ownsTransaction = _db.Database.CurrentTransaction == null && _db.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _db.Database.BeginTransactionAsync()
            : null;

        if (_db.Database.IsRelational())
        {
            await _db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock(41, hashtext({normalizedProjectNumber}));");
        }

        if (await _repository.ProjectNumberExistsAsync(normalizedProjectNumber))
            throw new BusinessException("Project number already exists.");

        var project = new Project
        {
            ProjectNumber = normalizedProjectNumber,
            Name = dto.Name,
            CustomerId = dto.CustomerId,
            EngineerId = dto.EngineerId,
            Status = dto.Status,
            InstallationDate = ToUtc(dto.InstallationDate),
            Notes = dto.Notes,
            TotalValue = dto.TotalValue,
            TotalKw = dto.TotalKW,
            Address = dto.Address,
            Governorate = dto.Governorate,
            City = dto.City,
            Latitude = dto.Latitude,
            Longitude = dto.Longitude,
            CreatedDate = DateTime.UtcNow
        };

        await _repository.AddAsync(project);

        await _auditService.CreateAsync(
            _currentUser.UserId,
            "Project",
            project.Id,
            null,
            project,
            new[]
            {
                "ProjectNumber",
                "Name",
                "CustomerId",
                "EngineerId",
                "Status",
                "InstallationDate",
                "Notes",
                "TotalValue",
                "TotalKw",
                "Address",
                "Governorate",
                "City",
                "Latitude",
                "Longitude"
            });

        if (ownsTransaction)
            await transaction!.CommitAsync();

        // Reload so Customer/Engineer navigation data is available in the response.
        var createdProject = await _repository.GetProjectDetailsAsync(project.Id);

        return MapToResponseDto(createdProject ?? project);
    }

    public async Task<ProjectResponseDto?> UpdateAsync(
        int id,
        UpdateProjectDto dto)
    {
        EnsureNotEngineerForManagement();

        var project = await _repository.GetByIdAsync(id);

        if (project == null)
            return null;

        if (!await _repository.CustomerExistsAsync(dto.CustomerId))
            throw new BusinessException("Customer not found.");

        if (dto.EngineerId.HasValue &&
            !await _repository.IsValidEngineerAsync(dto.EngineerId.Value))
        {
            throw new BusinessException("Selected engineer is invalid.");
        }

        var normalizedProjectNumber = dto.ProjectNumber.Trim();
        var numberChanged = !string.Equals(
            project.ProjectNumber,
            normalizedProjectNumber,
            StringComparison.OrdinalIgnoreCase);

        // Project numbers are unique business identifiers. The pre-check above is
        // useful for a friendly error, but it is not sufficient under concurrency.
        // When the number changes, serialize the check + update with the same
        // PostgreSQL advisory-lock strategy used during project creation.
        await using var transaction = _db.Database.IsRelational()
            ? await _db.Database.BeginTransactionAsync()
            : null;

        if (_db.Database.IsRelational())
        {
            await _db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock(41, hashtext({normalizedProjectNumber}));");
        }

        if (numberChanged &&
            await _repository.ProjectNumberExistsAsync(normalizedProjectNumber))
        {
            throw new BusinessException("Project number already exists.");
        }

        // Capture previous values for change description
        var previous = new
        {
            project.ProjectNumber,
            project.Name,
            project.CustomerId,
            project.EngineerId,
            project.Status,
            project.InstallationDate,
            project.Notes,
            project.TotalValue,
            project.TotalKw,
            project.Address,
            project.Governorate,
            project.City,
            project.Latitude,
            project.Longitude
        };

        project.ProjectNumber = normalizedProjectNumber;
        project.Name = dto.Name;
        project.CustomerId = dto.CustomerId;
        project.EngineerId = dto.EngineerId;
        project.Status = dto.Status;
        project.InstallationDate = ToUtc(dto.InstallationDate);
        project.Notes = dto.Notes;
        project.TotalValue = dto.TotalValue;
        project.TotalKw = dto.TotalKW;
        project.Address = dto.Address;
        project.Governorate = dto.Governorate;
        project.City = dto.City;
        project.Latitude = dto.Latitude;
        project.Longitude = dto.Longitude;

        await _repository.UpdateAsync(project);

        var description = ChangeLogBuilder.BuildDescription(
            previous,
            project,
            $"Project '{project.ProjectNumber}'",
            new[]
            {
                "ProjectNumber",
                "Name",
                "CustomerId",
                "EngineerId",
                "Status",
                "InstallationDate",
                "Notes",
                "TotalValue",
                "TotalKw",
                "Address",
                "Governorate",
                "City",
                "Latitude",
                "Longitude"
            });

        await _activityLogService.CreateAsync(
            _currentUser.UserId,
            "Update",
            "Project",
            project.Id,
            description);

        if (transaction != null)
            await transaction.CommitAsync();

        // Reload navigation properties for CustomerName/EngineerName.
        var updatedProject = await _repository.GetProjectDetailsAsync(project.Id);

        return MapToResponseDto(updatedProject ?? project);
    }

    public async Task<bool> DeleteAsync(int id)
    {
        EnsureNotEngineerForManagement();

        var project = await _repository.GetByIdAsync(id);

        if (project == null)
            return false;

        if (project.Status is ProjectStatus.InProgress or ProjectStatus.Completed)
        {
            throw new BusinessException(
                "Cannot delete a project that is in progress or completed.");
        }

        var ownsTransaction = _db.Database.CurrentTransaction == null && _db.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _db.Database.BeginTransactionAsync()
            : null;

        await _repository.DeleteAsync(project);

        await _auditService.DeleteAsync(
            _currentUser.UserId,
            "Project",
            project.Id,
            project,
            null,
            new[]
            {
                "ProjectNumber",
                "Name",
                "CustomerId",
                "EngineerId",
                "Status",
                "InstallationDate",
                "Notes",
                "TotalValue",
                "TotalKw",
                "Address",
                "Governorate",
                "City",
                "Latitude",
                "Longitude"
            });

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return true;
    }

    public async Task<int> DeleteAllAsync()
    {
        EnsureNotEngineerForManagement();

        var projects = await _repository.GetAllAsync();
        var deletable = projects
            .Where(p => p.Status is not (ProjectStatus.InProgress or ProjectStatus.Completed))
            .ToList();

        if (deletable.Count == 0)
            return 0;

        var ownsTransaction = _db.Database.CurrentTransaction == null && _db.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _db.Database.BeginTransactionAsync()
            : null;

        foreach (var project in deletable)
        {
            await _repository.DeleteAsync(project);
            await _auditService.DeleteAsync(
                _currentUser.UserId,
                "Project",
                project.Id,
                project,
                null,
                new[] { "ProjectNumber", "Name", "CustomerId", "EngineerId", "Status", "InstallationDate", "Notes", "TotalValue", "TotalKw", "Address", "Governorate", "City", "Latitude", "Longitude" });
        }

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return deletable.Count;
    }

    public async Task<bool> AssignEngineerAsync(
        int projectId,
        int engineerId)
    {
        EnsureNotEngineerForManagement();

        var project = await _repository.GetByIdAsync(projectId);

        if (project == null)
            return false;

        if (!await _repository.IsValidEngineerAsync(engineerId))
        {
            throw new BusinessException("Selected engineer is invalid.");
        }

        if (project.Status == ProjectStatus.Completed)
        {
            throw new BusinessException(
                "Cannot assign an engineer to a completed project.");
        }

        project.EngineerId = engineerId;

        await _repository.UpdateAsync(project);

        await _activityLogService.CreateAsync(
            _currentUser.UserId,
            "Assign Engineer",
            "Project",
            project.Id,
            $"Engineer {engineerId} assigned.");

        return true;
    }

    public async Task<bool> ChangeStatusAsync(
        int projectId,
        ProjectStatus status)
    {
        if (!Enum.IsDefined(status))
            throw new BusinessException("Invalid project status.");

        var project = await _repository.GetByIdAsync(projectId);

        if (project == null)
            return false;

        EnsureEngineerCanAccess(project);

        // Status is a state-machine transition. Serialize concurrent transitions
        // for the same project so two callers cannot both validate the same old
        // state and then silently overwrite each other.
        await using var transaction = _db.Database.IsRelational()
            ? await _db.Database.BeginTransactionAsync()
            : null;

        if (_db.Database.IsRelational())
        {
            await _db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock(43, {projectId});");
        }

        // Re-read after acquiring the lock because the first read may have raced
        // with another status change.
        project = await _repository.GetByIdAsync(projectId);
        if (project == null)
            return false;

        EnsureEngineerCanAccess(project);
        var currentStatus = project.Status;

        if (currentStatus == ProjectStatus.Completed && status != ProjectStatus.Completed)
            throw new BusinessException("A completed project cannot be moved to another status.");

        if (currentStatus == ProjectStatus.Cancelled && status != ProjectStatus.Cancelled)
            throw new BusinessException("A cancelled project cannot be reopened.");

        if (currentStatus == status)
            return true;

        project.Status = status;

        await _repository.UpdateAsync(project);

        await _activityLogService.CreateAsync(
            _currentUser.UserId,
            "Status Changed",
            "Project",
            project.Id,
            $"Status changed from '{currentStatus}' to '{status}'.");

        if (transaction != null)
            await transaction.CommitAsync();

        return true;
    }

    public Task<string> GetNextProjectNumberAsync() =>
        _repository.GetNextProjectNumberAsync(DateTime.UtcNow.Year);

    private void EnsureEngineerCanAccess(Project project)
    {
        if (_currentUser.Role == UserRole.Engineer.ToString() &&
            project.EngineerId != _currentUser.UserId)
        {
            throw new BusinessException(
                "You can only access projects assigned to you.");
        }
    }

    private void EnsureNotEngineerForManagement()
    {
        if (_currentUser.Role == UserRole.Engineer.ToString())
        {
            throw new BusinessException(
                "Engineers do not have permission to manage projects.");
        }
    }

    private static ProjectListItemDto MapToListItemDto(Project project)
    {
        return new ProjectListItemDto
        {
            Id = project.Id,
            ProjectNumber = project.ProjectNumber,
            Name = project.Name,
            CustomerId = project.CustomerId,
            CustomerName = project.Customer?.Name,
            CustomerChannel = project.Customer?.Channel,
            EngineerId = project.EngineerId,
            EngineerName = project.Engineer?.FullName ?? project.Engineer?.Username,
            Status = project.Status,
            CreatedDate = project.CreatedDate,
            InstallationDate = project.InstallationDate,
            Notes = project.Notes,
            TotalValue = project.TotalValue,
            TotalKW = project.TotalKw,
            Address = project.Address,
            Governorate = project.Governorate,
            City = project.City,
            Latitude = project.Latitude,
            Longitude = project.Longitude
        };
    }

    private static ProjectResponseDto MapToResponseDto(Project project)
    {
        return new ProjectResponseDto
        {
            Id = project.Id,
            ProjectNumber = project.ProjectNumber,
            Name = project.Name,
            CustomerId = project.CustomerId,
            CustomerName = project.Customer?.Name,
            CustomerChannel = project.Customer?.Channel,
            EngineerId = project.EngineerId,
            EngineerName = project.Engineer?.FullName ?? project.Engineer?.Username,
            Status = project.Status.ToString(),
            CreatedDate = project.CreatedDate,
            InstallationDate = project.InstallationDate,
            Notes = project.Notes,
            TotalValue = project.TotalValue,
            TotalKW = project.TotalKw,
            Address = project.Address,
            Governorate = project.Governorate,
            City = project.City,
            Latitude = project.Latitude,
            Longitude = project.Longitude
        };
    }

    private static DateTime? ToUtc(DateTime? value) => DateTimeUtility.ToUtc(value);
}
