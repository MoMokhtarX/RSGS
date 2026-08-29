using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.Interfaces;
using RSGS.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/Quotations/{quotationId:int}/history")]
[Authorize(Roles = "Admin,Sales,Engineer,Accountant,Manager")]
public class QuotationHistoryController : BaseApiController
{
    private readonly IQuotationVersionService _versions;
    private readonly AppDbContext _db;
    private readonly ICurrentUserService _currentUser;

    public QuotationHistoryController(IQuotationVersionService versions, AppDbContext db, ICurrentUserService currentUser)
    {
        _versions = versions; _db = db; _currentUser = currentUser;
    }

    [HttpGet]
    public async Task<IActionResult> GetHistory(int quotationId)
    {
        var quotation = await _db.Quotations.AsNoTracking().Include(x => x.Project).Include(x => x.Customer).FirstOrDefaultAsync(x => x.Id == quotationId);
        if (quotation == null) return NotFoundResponse("Quotation not found.");
        if (_currentUser.Role == "Engineer" && quotation.Project?.EngineerId != _currentUser.UserId && quotation.Customer?.AssignedUserId != _currentUser.UserId)
            return Forbid();
        return Success(await _versions.GetHistoryAsync(quotationId));
    }
}
