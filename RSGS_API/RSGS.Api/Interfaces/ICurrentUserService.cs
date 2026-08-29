namespace RSGS.Api.Interfaces;

public interface ICurrentUserService
{
    int UserId { get; }

    string Username { get; }

    string Role { get; }

    bool IsAuthenticated { get; }
}