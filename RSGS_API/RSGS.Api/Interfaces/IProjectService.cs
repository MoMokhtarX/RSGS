using RSGS.Api.DTOs;
using RSGS.Api.Enums;

namespace RSGS.Api.Interfaces;

public interface IProjectService
{
    Task<List<ProjectListItemDto>> GetAllAsync();
    Task<ProjectResponseDto?> GetByIdAsync(int id);
    Task<ProjectResponseDto> CreateAsync(CreateProjectDto dto);
    Task<ProjectResponseDto?> UpdateAsync(int id, UpdateProjectDto dto);
    Task<bool> DeleteAsync(int id);
    Task<int> DeleteAllAsync();
    Task<bool> AssignEngineerAsync(int projectId, int engineerId);
    Task<bool> ChangeStatusAsync(int projectId, ProjectStatus status);
    Task<string> GetNextProjectNumberAsync();
}
