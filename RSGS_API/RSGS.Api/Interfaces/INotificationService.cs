using RSGS.Api.DTOs;

namespace RSGS.Api.Interfaces;

public interface INotificationService
{
    Task<IEnumerable<NotificationDto>> GetAllAsync();

    Task<IEnumerable<NotificationDto>> GetUnreadAsync();

    Task<NotificationDto?> GetByIdAsync(int id);

    Task<NotificationDto> CreateAsync(
        CreateNotificationDto dto);

    Task<NotificationDto?> UpdateAsync(
        int id,
        UpdateNotificationDto dto);

    Task<bool> DeleteAsync(int id);

    Task<NotificationDto?> MarkAsReadAsync(int id);

    Task MarkAllAsReadAsync();
}