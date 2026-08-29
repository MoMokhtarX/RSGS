namespace RSGS.Api.Utilities;

/// <summary>
/// Centralizes API DateTime normalization. The API stores timestamps as UTC.
/// For an unspecified DateTime (common when JSON contains no offset), the API
/// intentionally treats the value as UTC to preserve the existing contract.
/// </summary>
public static class DateTimeUtility
{
    public static DateTime ToUtc(DateTime value) => value.Kind switch
    {
        DateTimeKind.Utc => value,
        DateTimeKind.Local => value.ToUniversalTime(),
        _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
    };

    public static DateTime? ToUtc(DateTime? value) =>
        value.HasValue ? ToUtc(value.Value) : null;
}
