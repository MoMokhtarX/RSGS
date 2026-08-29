using RSGS.Api.DTOs;

namespace RSGS.Api.Interfaces;

public interface IUserService
{
    Task<List<UserResponseDto>> GetAllAsync();
    Task<List<UserResponseDto>> GetEngineersAsync();

    Task<UserResponseDto?> GetByIdAsync(int id);

    Task<UserResponseDto> CreateAsync(CreateUserDto dto);

    Task<UserResponseDto?> UpdateAsync(int id, UpdateUserDto dto);

    Task<bool> DeleteAsync(int id);

    Task<bool> ChangePasswordAsync(int userId, ChangePasswordDto dto);

    Task<bool> ResetPasswordAsync(int userId, string newPassword);

    Task<bool> SetActiveAsync(int userId, bool isActive);
}