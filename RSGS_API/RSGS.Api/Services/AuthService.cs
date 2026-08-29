using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Exceptions;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;

namespace RSGS.Api.Services;

public class AuthService : IAuthService
{
    private readonly AppDbContext _context;
    private readonly JwtService _jwtService;
    private readonly PasswordService _passwordService;
    private readonly IActivityLogService _activityLogService;
    private readonly IConfiguration _configuration;

    public AuthService(
        AppDbContext context,
        JwtService jwtService,
        PasswordService passwordService,
        IActivityLogService activityLogService,
        IConfiguration configuration)
    {
        _context = context;
        _jwtService = jwtService;
        _passwordService = passwordService;
        _activityLogService = activityLogService;
        _configuration = configuration;
    }

    public async Task<bool> RegisterAdminAsync()
    {
        // PostgreSQL is the production provider. Use a database transaction and
        // transaction-scoped advisory lock to serialize concurrent bootstrap attempts.
        // Keep the service usable with EF InMemory for unit tests.
        var isPostgreSql = _context.Database.ProviderName?.Contains("Npgsql", StringComparison.OrdinalIgnoreCase) == true;
        Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction? transaction = null;

        if (isPostgreSql)
        {
            transaction = await _context.Database.BeginTransactionAsync();
            await _context.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock(hashtext('rsgs:admin-bootstrap'));" );
        }

        try
        {
            if (await _context.Users.AnyAsync(x => x.Role == UserRole.Admin))
            {
                if (transaction != null) await transaction.CommitAsync();
                return false;
            }

        var username = _configuration["Admin:Username"]?.Trim();
        var password = _configuration["Admin:Password"];
        var fullName = _configuration["Admin:FullName"]?.Trim();
        var email = _configuration["Admin:Email"]?.Trim();

        if (string.IsNullOrWhiteSpace(username) ||
            string.IsNullOrWhiteSpace(password) ||
            string.IsNullOrWhiteSpace(fullName) ||
            string.IsNullOrWhiteSpace(email))
        {
            throw new BusinessException("Admin configuration is missing.");
        }

        try
        {
            _passwordService.ValidateAndNormalize(password);
        }
        catch (ArgumentException ex)
        {
            throw new BusinessException(ex.Message);
        }

        if (await _context.Users.AnyAsync(x => x.Username == username))
            throw new BusinessException("Configured admin username already exists.");

        if (await _context.Users.AnyAsync(x => x.Email == email))
            throw new BusinessException("Configured admin email already exists.");

        var admin = new User
        {
            Username = username,
            PasswordHash = _passwordService.HashPassword(password),
            FullName = fullName,
            Email = email,
            Role = UserRole.Admin,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _context.Users.Add(admin);
            await _context.SaveChangesAsync();
            if (transaction != null) await transaction.CommitAsync();

            return true;
        }
        catch
        {
            if (transaction != null) await transaction.RollbackAsync();
            throw;
        }
        finally
        {
            if (transaction != null) await transaction.DisposeAsync();
        }
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest request)
    {
        var username = request.Username?.Trim();

        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(request.Password))
        {
            return new LoginResponse
            {
                Success = false,
                Message = "Username and password are required."
            };
        }

        var user = await _context.Users
            .FirstOrDefaultAsync(x => x.Username == username);

        if (user == null || !_passwordService.VerifyPassword(request.Password, user.PasswordHash))
        {
            return new LoginResponse
            {
                Success = false,
                Message = "Invalid username or password."
            };
        }

        if (!user.IsActive)
        {
            return new LoginResponse
            {
                Success = false,
                Message = "Your account has been disabled."
            };
        }

        await _activityLogService.CreateAsync(
            user.Id,
            "Login",
            "Auth",
            user.Id,
            $"{user.Username} logged into the system.");

        return new LoginResponse
        {
            Success = true,
            Message = "Login successful.",
            Token = _jwtService.GenerateToken(user),
            Id = user.Id,
            Username = user.Username,
            Email = user.Email,
            FullName = user.FullName,
            Role = user.Role.ToString()
        };
    }
}
