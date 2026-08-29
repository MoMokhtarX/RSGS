using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.Models;
using RSGS.Api.Repositories.Interfaces;

namespace RSGS.Api.Repositories;

public class QuotationRepository
    : GenericRepository<Quotation>,
      IQuotationRepository
{
    public QuotationRepository(AppDbContext context)
        : base(context)
    {
    }

    public override async Task<List<Quotation>> GetAllAsync()
    {
        return await _context.Quotations
            .Include(q => q.Customer)
            .Include(q => q.Project)
            .Include(q => q.Items.OrderBy(i => i.SortOrder))
                .ThenInclude(i => i.ProductComponent)
            .OrderByDescending(q => q.Id)
            .ToListAsync();
    }

    public async Task<Quotation?> GetDetailsAsync(int id)
    {
        return await _context.Quotations
            .Include(q => q.Customer)
            .Include(q => q.Project)
            .Include(q => q.Items
                .OrderBy(i => i.SortOrder))
            .ThenInclude(i => i.ProductComponent)
            .FirstOrDefaultAsync(q => q.Id == id);
    }

    public async Task<List<Quotation>> GetAllScopedAsync(int? engineerId)
    {
        var query = _context.Quotations
            .Include(q => q.Customer)
            .Include(q => q.Project)
            .Include(q => q.Items
                .OrderBy(i => i.SortOrder))
            .ThenInclude(i => i.ProductComponent)
            .AsQueryable();

        if (engineerId.HasValue)
        {
            query = query.Where(q =>
                (q.ProjectId.HasValue &&
                 q.Project != null &&
                 q.Project.EngineerId == engineerId.Value)
                ||
                (q.Customer != null &&
                 q.Customer.AssignedUserId == engineerId.Value));
        }

        return await query
            .OrderByDescending(q => q.Id)
            .ToListAsync();
    }

    public async Task<Quotation?> GetByQuotationNumberAsync(
        string quotationNumber)
    {
        return await _context.Quotations
            .FirstOrDefaultAsync(
                q => q.QuotationNumber == quotationNumber);
    }

    public async Task UpdateWithItemsAsync(
        Quotation quotation)
    {
        // Get existing items from database
        var existingItems = await _context.QuotationItems
            .Where(x => x.QuotationId == quotation.Id)
            .ToListAsync();

        // Remove old items
        _context.QuotationItems.RemoveRange(existingItems);

        // Add current items
        if (quotation.Items != null &&
            quotation.Items.Count > 0)
        {
            foreach (var item in quotation.Items)
            {
                item.Id = 0;
                item.QuotationId = quotation.Id;

                _context.QuotationItems.Add(item);
            }
        }

        // Mark quotation as modified
        _context.Quotations.Update(quotation);

        await _context.SaveChangesAsync();
    }
}