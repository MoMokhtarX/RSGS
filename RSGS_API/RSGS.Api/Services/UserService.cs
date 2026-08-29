using Microsoft.EntityFrameworkCore;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Enums;
using RSGS.Api.Exceptions;

namespace RSGS.Api.Services;

public class UserService : IUserService
{
    private readonly AppDbContext _context;
    private readonly PasswordService _passwordService;
    private readonly IActivityLogService _activityLogService;
    private readonly ICurrentUserService _currentUser;

    public UserService(
        AppDbContext context,
        PasswordService passwordService,
        IActivityLogService activityLogService,
        ICurrentUserService currentUser)
    {
        _context = context;
        _passwordService = passwordService;
        _activityLogService = activityLogService;
        _currentUser = currentUser;
    }

    public async Task<List<UserResponseDto>> GetAllAsync()
    {
        return await _context.Users
            .OrderBy(x => x.FullName)
            .Select(x => new UserResponseDto
            {
                Id = x.Id,
                Username = x.Username,
                FullName = x.FullName,
                Email = x.Email,
                Role = x.Role,
                IsActive = x.IsActive,
                CreatedAt = x.CreatedAt
            })
            .ToListAsync();
    }

    public async Task<List<UserResponseDto>> GetEngineersAsync()
    {
        return await _context.Users
            .Where(x => x.Role == UserRole.Engineer)
            .OrderBy(x => x.FullName)
            .Select(x => new UserResponseDto
            {
                Id = x.Id,
                Username = x.Username,
                FullName = x.FullName,
                Email = x.Email,
                Role = x.Role,
                IsActive = x.IsActive,
                CreatedAt = x.CreatedAt
            })
            .ToListAsync();
    }

    public async Task<UserResponseDto?> GetByIdAsync(int id)
    {
        return await _context.Users
            .Where(x => x.Id == id)
            .Select(x => new UserResponseDto
            {
                Id = x.Id,
                Username = x.Username,
                FullName = x.FullName,
                Email = x.Email,
                Role = x.Role,
                IsActive = x.IsActive,
                CreatedAt = x.CreatedAt
            })
            .FirstOrDefaultAsync();
    }

    public async Task<UserResponseDto> CreateAsync(CreateUserDto dto)
    {
        var username = dto.Username.Trim();
        var email = dto.Email.Trim();

        if (!Enum.IsDefined(dto.Role))
            throw new BusinessException("Invalid user role.");

        if (string.IsNullOrWhiteSpace(dto.FullName))
            throw new BusinessException("Full name is required.");

        try
        {
            _passwordService.ValidateAndNormalize(dto.Password);
        }
        catch (ArgumentException ex)
        {
            throw new BusinessException(ex.Message);
        }

        if (await _context.Users.AnyAsync(x => x.Username == username))
            throw new BusinessException("Username already exists.");

        if (await _context.Users.AnyAsync(x => x.Email == email))
            throw new BusinessException("Email already exists.");

        var user = new User
        {
            Username = username,
            PasswordHash = _passwordService.HashPassword(dto.Password),
            FullName = dto.FullName,
            Email = email,
            Role = dto.Role,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        _context.Users.Add(user);

        await _context.SaveChangesAsync();

        await _activityLogService.CreateAsync(
            _currentUser.UserId,
            "Create",
            "User",
            user.Id,
            $"User '{user.Username}' was created.");

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return new UserResponseDto
        {
            Id = user.Id,
            Username = user.Username,
            FullName = user.FullName,
            Email = user.Email,
            Role = user.Role,
            IsActive = user.IsActive,
            CreatedAt = user.CreatedAt
        };
    }

    public async Task<UserResponseDto?> UpdateAsync(int id, UpdateUserDto dto)
    {
        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        // Serialize changes to the admin set. Without this lock, two concurrent
        // requests can both observe themselves as the last active Admin and both
        // remove admin protection.
        if (_context.Database.IsRelational())
        {
            await _context.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock(43, 1);");
        }

        var user = await _context.Users.FindAsync(id);

        if (user == null)
            return null;

        var email = dto.Email.Trim();

        if (!Enum.IsDefined(dto.Role))
            throw new BusinessException("Invalid user role.");

        if (string.IsNullOrWhiteSpace(dto.FullName))
            throw new BusinessException("Full name is required.");

        if (await _context.Users.AnyAsync(x => x.Email == email && x.Id != id))
            throw new BusinessException("Email already exists.");

        // Prevent disabling yourself
        if (!dto.IsActive && user.Id == _currentUser.UserId)
            throw new BusinessException("You cannot disable your own account.");

        // Prevent removing the last active Admin
        if (user.Role == UserRole.Admin && user.IsActive)
        {
            bool losingAdminRole = dto.Role != UserRole.Admin;
            bool beingDisabled = !dto.IsActive;

            if (losingAdminRole || beingDisabled)
            {
                var activeAdminCount = await _context.Users
                    .CountAsync(x =>
                        x.Role == UserRole.Admin &&
                        x.IsActive);

                if (activeAdminCount <= 1)
                    throw new BusinessException(
                        "Cannot remove the last active Admin.");
            }
        }

        user.FullName = dto.FullName.Trim();
        user.Email = email;
        user.Role = dto.Role;
        user.IsActive = dto.IsActive;

        await _context.SaveChangesAsync();

        await _activityLogService.CreateAsync(
            _currentUser.UserId,
            "Update",
            "User",
            user.Id,
            $"User '{user.Username}' was updated.");

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return new UserResponseDto
        {
            Id = user.Id,
            Username = user.Username,
            FullName = user.FullName,
            Email = user.Email,
            Role = user.Role,
            IsActive = user.IsActive,
            CreatedAt = user.CreatedAt
        };
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        if (_context.Database.IsRelational())
        {
            await _context.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock(43, 1);");
        }

        var user = await _context.Users.FindAsync(id);

        if (user == null)
            return false;

        // Prevent deleting yourself
        if (user.Id == _currentUser.UserId)
            throw new BusinessException("You cannot delete your own account.");

        // Prevent deleting the last active Admin
        if (user.Role == UserRole.Admin)
        {
            var activeAdminCount = await _context.Users
                .CountAsync(x =>
                    x.Role == UserRole.Admin &&
                    x.IsActive);

            if (activeAdminCount <= 1)
                throw new BusinessException("Cannot delete the last active Admin.");
        }

        _context.Users.Remove(user);

        await _context.SaveChangesAsync();

        await _activityLogService.CreateAsync(
            _currentUser.UserId,
            "Delete",
            "User",
            user.Id,
            $"User '{user.Username}' was deleted.");

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return true;
    }

    public async Task<bool> ChangePasswordAsync(int userId, ChangePasswordDto dto)
    {
        var user = await _context.Users.FindAsync(userId);

        if (user == null)
            return false;

        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        if (!_passwordService.VerifyPassword(dto.CurrentPassword, user.PasswordHash))
            throw new BusinessException("Current password is incorrect.");

        if (dto.NewPassword != dto.ConfirmPassword)
            throw new BusinessException("Passwords do not match.");

        try
        {
            _passwordService.ValidateAndNormalize(dto.NewPassword);
        }
        catch (ArgumentException ex)
        {
            throw new BusinessException(ex.Message);
        }

        user.PasswordHash = _passwordService.HashPassword(dto.NewPassword);

        await _context.SaveChangesAsync();

        await _activityLogService.CreateAsync(
            _currentUser.UserId,
            "Change Password",
            "User",
            user.Id,
            $"Password changed for '{user.Username}'.");

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return true;
    }

    public async Task<bool> ResetPasswordAsync(int userId, string newPassword)
    {
        var user = await _context.Users.FindAsync(userId);

        if (user == null)
            return false;

        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        try
        {
            _passwordService.ValidateAndNormalize(newPassword);
        }
        catch (ArgumentException ex)
        {
            throw new BusinessException(ex.Message);
        }

        user.PasswordHash = _passwordService.HashPassword(newPassword);

        await _context.SaveChangesAsync();

        await _activityLogService.CreateAsync(
            _currentUser.UserId,
            "Reset Password",
            "User",
            user.Id,
            $"Password reset for '{user.Username}'.");

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return true;
    }

    public async Task<bool> SetActiveAsync(int userId, bool isActive)
    {
        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        if (_context.Database.IsRelational())
        {
            await _context.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock(43, 1);");
        }

        var user = await _context.Users.FindAsync(userId);

        if (user == null)
            return false;

        // Prevent disabling yourself
        if (!isActive && user.Id == _currentUser.UserId)
            throw new BusinessException("You cannot disable your own account.");

        // Prevent disabling the last active Admin
        if (!isActive && user.Role == UserRole.Admin && user.IsActive)
        {
            var activeAdminCount = await _context.Users
                .CountAsync(x =>
                    x.Role == UserRole.Admin &&
                    x.IsActive);

            if (activeAdminCount <= 1)
                throw new BusinessException("Cannot disable the last active Admin.");
        }

        user.IsActive = isActive;

        await _context.SaveChangesAsync();

        await _activityLogService.CreateAsync(
            _currentUser.UserId,
            isActive ? "Enable User" : "Disable User",
            "User",
            user.Id,
            $"{user.Username} status changed.");

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return true;
    }

}
