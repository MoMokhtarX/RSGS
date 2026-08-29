using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace RSGS.Api.Utilities;

public static class ChangeLogBuilder
{
    /// <summary>
    /// Build a descriptive change log for two objects by comparing public properties with matching names.
    /// The returned string will be either "{entityName} was updated." or
    /// "{entityName} was updated. Changes: Prop: 'old' -> 'new'; ...".
    /// </summary>
    public static string BuildDescription(object? previous, object? current, string entityName, IEnumerable<string>? includeProperties = null)
    {
        var changes = new List<string>();

        if (previous == null && current == null)
            return $"{entityName} was updated.";

        var prevProps = previous?.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance) ?? Array.Empty<PropertyInfo>();
        var currProps = current?.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance) ?? Array.Empty<PropertyInfo>();

        // If previous is null (create) compare current props against null to show new values
        if (previous == null && current != null)
        {
            foreach (var cp in currProps)
            {
                if (includeProperties != null && !includeProperties.Contains(cp.Name, StringComparer.OrdinalIgnoreCase))
                    continue;

                var newVal = cp.GetValue(current);
                var newS = FormatValue(newVal);
                if (!string.Equals(newS, "null", StringComparison.Ordinal))
                {
                    changes.Add($"{cp.Name}: 'null' -> '{newS}'");
                }
            }

            if (changes.Count == 0)
                return $"{entityName} was created.";

            return $"{entityName} was created. Changes: {string.Join("; ", changes)}";
        }

        // If current is null (delete) compare previous props against null to show removed values
        if (current == null && previous != null)
        {
            foreach (var p in prevProps)
            {
                if (includeProperties != null && !includeProperties.Contains(p.Name, StringComparer.OrdinalIgnoreCase))
                    continue;

                var oldVal = p.GetValue(previous);
                var oldS = FormatValue(oldVal);
                if (!string.Equals(oldS, "null", StringComparison.Ordinal))
                {
                    changes.Add($"{p.Name}: '{oldS}' -> 'null'");
                }
            }

            if (changes.Count == 0)
                return $"{entityName} was deleted.";

            return $"{entityName} was deleted. Changes: {string.Join("; ", changes)}";
        }

        var currMap = currProps.ToDictionary(p => p.Name, StringComparer.OrdinalIgnoreCase);

        foreach (var p in prevProps)
        {
            if (includeProperties != null && !includeProperties.Contains(p.Name, StringComparer.OrdinalIgnoreCase))
                continue;

            if (!currMap.TryGetValue(p.Name, out var cp))
                continue;

            var oldVal = p.GetValue(previous);
            var newVal = cp.GetValue(current);

            var oldS = FormatValue(oldVal);
            var newS = FormatValue(newVal);

            if (!string.Equals(oldS, newS, StringComparison.Ordinal))
            {
                changes.Add($"{p.Name}: '{oldS}' -> '{newS}'");
            }
        }

        if (changes.Count == 0)
            return $"{entityName} was updated.";

        return $"{entityName} was updated. Changes: {string.Join("; ", changes)}";
    }

    private static string FormatValue(object? value)
    {
        if (value == null) return "null";
        if (value is DateTime dt) return dt.ToString("u"); // universal sortable
        if (value is DateTimeOffset dto) return dto.ToString("u");
        return value.ToString() ?? "null";
    }
}
