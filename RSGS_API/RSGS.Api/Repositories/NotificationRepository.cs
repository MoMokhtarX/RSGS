using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.Models;
using RSGS.Api.Repositories.Interfaces;

namespace RSGS.Api.Repositories;

public class NotificationRepository
    : GenericRepository<Notification>,
      INotificationRepository
{

    public NotificationRepository(
        AppDbContext context)
        : base(context){}

    public async Task<IEnumerable<Notification>> GetUnreadAsync()
    {
        return await _context.Notifications
            .AsNoTracking()
            .Where(x => !x.IsRead)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();
    }

    public async Task MarkAllAsReadAsync()
    {
        var notifications = await _context.Notifications
            .Where(x => !x.IsRead)
            .ToListAsync();

        foreach (var notification in notifications)
        {
            notification.IsRead = true;
        }

        await _context.SaveChangesAsync();
    }
}