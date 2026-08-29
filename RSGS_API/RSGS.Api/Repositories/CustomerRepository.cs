using Microsoft.EntityFrameworkCore;
using RSGS.Api.Common;
using RSGS.Api.Data;
using RSGS.Api.Models;
using RSGS.Api.Repositories.Interfaces;

namespace RSGS.Api.Repositories;

public class CustomerRepository : GenericRepository<Customer>, ICustomerRepository
{
    public CustomerRepository(AppDbContext context)
        : base(context)
    {
    }

    public async Task<Customer?> GetWithProjectsAsync(
        int id,
        int? assignedUserId = null)
    {
        IQueryable<Customer> query = _context.Customers
            .Include(c => c.Projects)
            .Include(c => c.AssignedUser);

        if (assignedUserId.HasValue)
        {
            query = query.Where(c => c.AssignedUserId == assignedUserId.Value);
        }

        return await query.FirstOrDefaultAsync(c => c.Id == id);
    }

    public async Task<PagedResult<Customer>> SearchAsync(
        CustomerQueryParameters parameters,
        int? assignedUserId = null)
    {
        IQueryable<Customer> query = _context.Customers
            .Include(c => c.AssignedUser);

        // Server-side assignment scope.
        // This value comes from the authenticated user for Engineer
        // requests and cannot be overridden by the client.
        if (assignedUserId.HasValue)
        {
            query = query.Where(c =>
                c.AssignedUserId == assignedUserId.Value);
        }

        if (!string.IsNullOrWhiteSpace(parameters.Search))
        {
            var search = parameters.Search.Trim();

            if (_context.Database.IsRelational())
            {
                var pattern = $"%{search}%";
                query = query.Where(c =>
                    EF.Functions.ILike(c.Name, pattern) ||
                    (c.Phone != null && EF.Functions.ILike(c.Phone, pattern)) ||
                    (c.Email != null && EF.Functions.ILike(c.Email, pattern)));
            }
            else
            {
                var fallback = search.ToLowerInvariant();
                query = query.Where(c =>
                    c.Name.ToLower().Contains(fallback) ||
                    (c.Phone != null && c.Phone.ToLower().Contains(fallback)) ||
                    (c.Email != null && c.Email.ToLower().Contains(fallback)));
            }
        }
        if (!string.IsNullOrWhiteSpace(parameters.Governorate))
        {
            query = query.Where(c =>
                c.Governorate == parameters.Governorate);
        }

        if (!string.IsNullOrWhiteSpace(parameters.City))
        {
            query = query.Where(c =>
                c.City == parameters.City);
        }

        if (!string.IsNullOrWhiteSpace(parameters.Channel))
        {
            query = query.Where(c =>
                c.Channel == parameters.Channel);
        }

        if (!string.IsNullOrWhiteSpace(parameters.FollowUpStatus))
        {
            query = query.Where(c =>
                c.FollowUpStatus == parameters.FollowUpStatus);
        }

        // AssignedUserId is a normal filter for privileged roles.
        // For Engineer requests, CustomerService passes the authenticated
        // user's ID as the server-side scope and does not trust this value.
        if (parameters.AssignedUserId.HasValue &&
            !assignedUserId.HasValue)
        {
            query = query.Where(c =>
                c.AssignedUserId == parameters.AssignedUserId.Value);
        }

        query = parameters.SortBy?.ToLower() switch
        {
            "name" => parameters.Descending
                ? query.OrderByDescending(c => c.Name)
                : query.OrderBy(c => c.Name),

            "date" => parameters.Descending
                ? query.OrderByDescending(c => c.CreatedAt)
                : query.OrderBy(c => c.CreatedAt),

            _ => query.OrderByDescending(c => c.Id)
        };

        var totalCount = await query.CountAsync();

        var customers = await query
            .Skip((parameters.PageNumber - 1) * parameters.PageSize)
            .Take(parameters.PageSize)
            .ToListAsync();

        return new PagedResult<Customer>
        {
            Items = customers,
            PageNumber = parameters.PageNumber,
            PageSize = parameters.PageSize,
            TotalCount = totalCount
        };
    }
}
