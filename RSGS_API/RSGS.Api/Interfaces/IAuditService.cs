using System.Collections.Generic;

namespace RSGS.Api.Interfaces;

public interface IAuditService
{
    Task CreateAsync(int userId, string entity, int entityId, object? previous, object? current, IEnumerable<string>? includeProperties = null);

    Task UpdateAsync(int userId, string entity, int entityId, object? previous, object? current, IEnumerable<string>? includeProperties = null);

    Task DeleteAsync(int userId, string entity, int entityId, object? previous, object? current, IEnumerable<string>? includeProperties = null);

    Task LogActionAsync(int userId, string action, string entity, int entityId, string description);
}
