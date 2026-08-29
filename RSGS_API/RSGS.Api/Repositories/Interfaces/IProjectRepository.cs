using RSGS.Api.Models;

namespace RSGS.Api.Repositories.Interfaces;

public interface IProjectRepository : IGenericRepository<Project>
{
    Task<List<Project>> GetAllScopedAsync(int? engineerId = null);

    Task<Project?> GetProjectDetailsAsync(
        int id,
        int? engineerId = null);

    Task<bool> ProjectNumberExistsAsync(string projectNumber);

    Task<bool> CustomerExistsAsync(int customerId);

    Task<bool> IsValidEngineerAsync(int engineerId);

    Task<string> GetNextProjectNumberAsync(int year);
}
