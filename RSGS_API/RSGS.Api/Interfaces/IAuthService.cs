using RSGS.Api.DTOs;

namespace RSGS.Api.Interfaces;

public interface IAuthService
{
    Task<bool> RegisterAdminAsync();
    Task<LoginResponse> LoginAsync(LoginRequest request);
}
