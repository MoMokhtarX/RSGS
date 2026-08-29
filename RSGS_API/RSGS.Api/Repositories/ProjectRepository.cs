using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.Enums;
using RSGS.Api.Models;
using RSGS.Api.Repositories.Interfaces;

namespace RSGS.Api.Repositories;

public class ProjectRepository : GenericRepository<Project>, IProjectRepository
{
    public ProjectRepository(AppDbContext context) : base(context) { }

    public async Task<List<Project>> GetAllScopedAsync(int? engineerId = null)
    {
        IQueryable<Project> query = _context.Projects
            .Include(p => p.Customer)
            .Include(p => p.Engineer);

        if (engineerId.HasValue)
        {
            query = query.Where(p => p.EngineerId == engineerId.Value);
        }

        return await query
            .OrderByDescending(p => p.Id)
            .ToListAsync();
    }

    public async Task<Project?> GetProjectDetailsAsync(
        int id,
        int? engineerId = null)
    {
        IQueryable<Project> query = _context.Projects
            .Include(p => p.Customer)
            .Include(p => p.Engineer);

        query = query.Where(p => p.Id == id);

        if (engineerId.HasValue)
        {
            query = query.Where(p => p.EngineerId == engineerId.Value);
        }

        return await query.FirstOrDefaultAsync();
    }

    public async Task<bool> ProjectNumberExistsAsync(string projectNumber) =>
        await _context.Projects.AnyAsync(
            p => p.ProjectNumber == projectNumber);

    public async Task<bool> CustomerExistsAsync(int customerId) =>
        await _context.Customers.AnyAsync(
            c => c.Id == customerId);

    public async Task<bool> IsValidEngineerAsync(int engineerId) =>
        await _context.Users.AnyAsync(u =>
            u.Id == engineerId &&
            u.Role == UserRole.Engineer &&
            u.IsActive);

    public async Task<string> GetNextProjectNumberAsync(int year)
    {
        var prefix = $"RSG-{year}-";

        var numbers = await _context.Projects
            .Where(p => p.ProjectNumber.StartsWith(prefix))
            .Select(p => p.ProjectNumber)
            .ToListAsync();

        var max = 0;

        foreach (var number in numbers)
        {
            var suffix = number[prefix.Length..];

            if (int.TryParse(suffix, out var value) && value > max)
            {
                max = value;
            }
        }

        return $"{prefix}{max + 1:0000}";
    }
}
