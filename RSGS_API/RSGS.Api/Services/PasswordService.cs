using BCrypt.Net;

namespace RSGS.Api.Services;

public class PasswordService
{
    public const int MinimumPasswordLength = 12;

    public string ValidateAndNormalize(string password)
    {
        if (string.IsNullOrWhiteSpace(password))
            throw new ArgumentException("Password is required.", nameof(password));

        if (password.Length < MinimumPasswordLength)
            throw new ArgumentException($"Password must be at least {MinimumPasswordLength} characters.", nameof(password));

        return password;
    }

    public string HashPassword(string password)
    {
        password = ValidateAndNormalize(password);
        return BCrypt.Net.BCrypt.HashPassword(password);
    }

    public bool VerifyPassword(string password, string hash)
    {
        if (string.IsNullOrWhiteSpace(password) || string.IsNullOrWhiteSpace(hash))
            return false;

        return BCrypt.Net.BCrypt.Verify(password, hash);
    }
}
