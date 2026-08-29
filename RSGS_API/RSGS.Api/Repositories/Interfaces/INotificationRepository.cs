using RSGS.Api.Models;

namespace RSGS.Api.Repositories.Interfaces;

public interface INotificationRepository
    : IGenericRepository<Notification>
{
    Task<IEnumerable<Notification>> GetUnreadAsync();

    Task MarkAllAsReadAsync();
}