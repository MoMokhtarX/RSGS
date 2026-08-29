using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/Health")]
public sealed class HealthController : ControllerBase
{
    private readonly AppDbContext _context;

    public HealthController(AppDbContext context) => _context = context;

    [AllowAnonymous]
    [HttpGet]
    public async Task<IActionResult> Get()
    {
        var databaseAvailable = await _context.Database.CanConnectAsync();
        return Ok(new
        {
            status = databaseAvailable ? "Healthy" : "Degraded",
            database = databaseAvailable ? "Connected" : "Unavailable",
            utc = DateTime.UtcNow,
            version = "1.0.0"
        });
    }
}
