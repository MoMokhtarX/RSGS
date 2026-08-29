using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Exceptions;
using RSGS.Api.Repositories;
using RSGS.Api.Services;
using RSGS.Api.Utilities;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class NotificationAndCalendarServiceTests
{
    [Fact]
    public async Task NotificationLifecycle_ValidatesTrimsReadsAndDeletes()
    {
        await using var db = Db();
        var service = new NotificationService(new NotificationRepository(db));
        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(new CreateNotificationDto { Title = " ", Message = "Message" }));
        var created = await service.CreateAsync(new CreateNotificationDto { Title = " Title ", Message = " Message ", Type = NotificationType.Reminder });
        Assert.Equal("Title", created.Title);
        Assert.Single(await service.GetUnreadAsync());
        var read = await service.MarkAsReadAsync(created.Id);
        Assert.True(read!.IsRead);
        Assert.Empty(await service.GetUnreadAsync());
        Assert.True(await service.DeleteAsync(created.Id));
        Assert.False(await service.DeleteAsync(created.Id));
    }

    [Fact]
    public async Task CalendarLifecycle_ValidatesRangeReferencesAndCompletion()
    {
        await using var db = Db();
        var service = new CalendarEventService(new CalendarEventRepository(db));
        await Assert.ThrowsAsync<BusinessException>(() => service.GetByDateRangeAsync(DateTime.UtcNow, DateTime.UtcNow.AddDays(-1)));
        await Assert.ThrowsAsync<BusinessException>(() => service.GetByReferenceAsync("", 1));
        await Assert.ThrowsAsync<BusinessException>(() => service.GetByReferenceAsync("Project", 0));
        var created = await service.CreateAsync(new CreateCalendarEventDto { Title = " Meeting ", EventDate = DateTime.UtcNow, Type = CalendarEventType.Meeting, ReferenceType = "Project", ReferenceId = 7 });
        Assert.Equal("Meeting", created.Title);
        Assert.Single(await service.GetByReferenceAsync("Project", 7));
        Assert.True((await service.MarkCompletedAsync(created.Id))!.IsCompleted);
        Assert.True(await service.DeleteAsync(created.Id));
        Assert.Null(await service.MarkCompletedAsync(created.Id));
    }

    [Fact]
    public async Task CalendarAndNotificationDates_AreNormalizedToUtc()
    {
        await using var db = Db();
        var calendar = new CalendarEventService(new CalendarEventRepository(db));
        var notification = new NotificationService(new NotificationRepository(db));
        var unspecified = new DateTime(2026, 8, 28, 12, 30, 0, DateTimeKind.Unspecified);

        var calendarEvent = await calendar.CreateAsync(new CreateCalendarEventDto
        { Title = "UTC", EventDate = unspecified, Type = CalendarEventType.Meeting });
        var createdNotification = await notification.CreateAsync(new CreateNotificationDto
        { Title = "UTC", Message = "Message", Type = NotificationType.Reminder, ScheduledFor = unspecified });

        Assert.Equal(DateTimeKind.Utc, calendarEvent.EventDate.Kind);
        Assert.Equal(unspecified, calendarEvent.EventDate);
        Assert.Equal(DateTimeKind.Utc, createdNotification.ScheduledFor!.Value.Kind);
        Assert.Equal(unspecified, createdNotification.ScheduledFor.Value);
    }

    private static AppDbContext Db() => new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
}
