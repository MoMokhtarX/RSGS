using RSGS.Api.DTOs;
using RSGS.Api.Exceptions;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Repositories.Interfaces;
using RSGS.Api.Utilities;

namespace RSGS.Api.Services;

public class NotificationService : INotificationService
{
    private readonly INotificationRepository _repository;

    public NotificationService(
        INotificationRepository repository)
    {
        _repository = repository;
    }

    public async Task<IEnumerable<NotificationDto>> GetAllAsync()
    {
        var notifications = await _repository.GetAllAsync();

        return notifications
            .OrderByDescending(x => x.CreatedAt)
            .Select(MapToDto);
    }

    public async Task<IEnumerable<NotificationDto>> GetUnreadAsync()
    {
        var notifications = await _repository.GetUnreadAsync();

        return notifications.Select(MapToDto);
    }

    public async Task<NotificationDto?> GetByIdAsync(int id)
    {
        var notification = await _repository.GetByIdAsync(id);

        return notification == null
            ? null
            : MapToDto(notification);
    }

    public async Task<NotificationDto> CreateAsync(
        CreateNotificationDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Title))
            throw new BusinessException(
                "Notification title is required.");

        if (string.IsNullOrWhiteSpace(dto.Message))
            throw new BusinessException(
                "Notification message is required.");

        var notification = new Notification
        {
            Title = dto.Title.Trim(),
            Message = dto.Message.Trim(),
            Type = dto.Type,
            IsRead = false,
            CreatedAt = DateTime.UtcNow,
            ScheduledFor = DateTimeUtility.ToUtc(dto.ScheduledFor)
        };

        await _repository.AddAsync(notification);

        return MapToDto(notification);
    }

    public async Task<NotificationDto?> UpdateAsync(
        int id,
        UpdateNotificationDto dto)
    {
        var notification = await _repository.GetByIdAsync(id);

        if (notification == null)
            return null;

        if (string.IsNullOrWhiteSpace(dto.Title))
            throw new BusinessException(
                "Notification title is required.");

        if (string.IsNullOrWhiteSpace(dto.Message))
            throw new BusinessException(
                "Notification message is required.");

        notification.Title = dto.Title.Trim();
        notification.Message = dto.Message.Trim();
        notification.Type = dto.Type;
        notification.IsRead = dto.IsRead;
        notification.ScheduledFor = DateTimeUtility.ToUtc(dto.ScheduledFor);

        await _repository.UpdateAsync(notification);

        return MapToDto(notification);
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var notification = await _repository.GetByIdAsync(id);

        if (notification == null)
            return false;

        await _repository.DeleteAsync(notification);

        return true;
    }

    public async Task<NotificationDto?> MarkAsReadAsync(int id)
    {
        var notification = await _repository.GetByIdAsync(id);

        if (notification == null)
            return null;

        notification.IsRead = true;

        await _repository.UpdateAsync(notification);

        return MapToDto(notification);
    }

    public async Task MarkAllAsReadAsync()
    {
        await _repository.MarkAllAsReadAsync();
    }

    private static NotificationDto MapToDto(
        Notification notification)
    {
        return new NotificationDto
        {
            Id = notification.Id,
            Title = notification.Title,
            Message = notification.Message,
            Type = notification.Type,
            IsRead = notification.IsRead,
            CreatedAt = notification.CreatedAt,
            ScheduledFor = notification.ScheduledFor
        };
    }
}