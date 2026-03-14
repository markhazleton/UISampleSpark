namespace UISampleSpark.UI.Extensions;

/// <summary>
/// Extension methods for working with application configuration
/// </summary>
public static class ConfigurationExtensions
{
    /// <summary>
    /// Converts a string value to an integer
    /// </summary>
    /// <param name="Value">The string value to convert</param>
    /// <param name="defaultValue">Default value to use if conversion fails</param>
    /// <returns>The converted integer or default value</returns>
    private static int GetInt(string Value, string? defaultValue = null)
    {
        if (!string.IsNullOrEmpty(Value))
        {

            return Value.Split<int>(',', out _).FirstOrDefault();
        }
        if (string.IsNullOrEmpty(defaultValue))
        {
            return default;
        }
        return defaultValue.Split<int>(',', out _).FirstOrDefault();
    }

    /// <summary>
    /// Converts a comma-separated string to an array of integers
    /// </summary>
    /// <param name="Value">The comma-separated string to convert</param>
    /// <param name="defaultValue">Default value to use if conversion fails</param>
    /// <returns>An array of integers</returns>
    private static int[] GetIntList(string Value, string? defaultValue = null)
    {

        if (!string.IsNullOrEmpty(Value))
        {
            return Value.Split<int>(',', out _).ToArray() ?? Array.Empty<int>();
        }

        if (string.IsNullOrEmpty(defaultValue))
        {
            return Array.Empty<int>();
        }
        return defaultValue.Split<int>(',', out _).ToArray() ?? Array.Empty<int>();
    }

    /// <summary>
    /// Gets a string value or returns a default if null or empty
    /// </summary>
    /// <param name="Value">The string value to check</param>
    /// <param name="defaultValue">Default value to use if input is null or empty</param>
    /// <returns>The string value or default</returns>
    private static string GetString(string Value, string? defaultValue = null)
    {
        if (!string.IsNullOrEmpty(Value))
        {
            return Value;
        }
        if (string.IsNullOrEmpty(defaultValue))
        {
            return string.Empty;
        }
        return defaultValue;
    }

    /// <summary>
    /// Converts a comma-separated string to an array of strings
    /// </summary>
    /// <param name="Value">The comma-separated string to split</param>
    /// <param name="defaultValue">Default value to use if input is null or empty</param>
    /// <returns>An array of strings</returns>
    private static string[] GetStringList(string Value, string? defaultValue = null)
    {
        if (!string.IsNullOrEmpty(Value))
        {
            return Value.Split(",") ?? Array.Empty<string>();
        }

        if (string.IsNullOrEmpty(defaultValue))
        {
            return Array.Empty<string>();
        }
        return defaultValue.Split(",") ?? Array.Empty<string>();
    }

    /// <summary>
    /// Splits a string by a separator and converts each element to the specified type
    /// </summary>
    /// <typeparam name="T">The target type to convert elements to</typeparam>
    /// <param name="this">The input string to split</param>
    /// <param name="separator">The character used to separate elements</param>
    /// <param name="AllConverted">Output parameter indicating if all conversions were successful</param>
    /// <returns>A list of converted elements</returns>
    private static List<T> Split<T>(this string @this, char separator, out bool AllConverted)
    {
        List<T> returnVals = new();
        AllConverted = true;
        string[] itens = @this.Split(separator);
        foreach (string item in itens)
        {
            try
            {
                returnVals.Add((T)Convert.ChangeType(item, typeof(T)));
            }
            catch (InvalidCastException) 
            { 
                AllConverted = false; 
            }
            catch (FormatException) 
            { 
                AllConverted = false; 
            }
        }
        return returnVals;
    }

    /// <summary>
    /// Gets an integer value from the configuration
    /// </summary>
    /// <param name="_config">The configuration instance</param>
    /// <param name="configKey">The configuration key to look up</param>
    /// <param name="defaultValue">Default value to use if the key is not found or conversion fails</param>
    /// <returns>The integer value from configuration or default</returns>
    public static int GetInt(this IConfiguration _config, string configKey, string? defaultValue = null)
    {
        ArgumentNullException.ThrowIfNull(_config);
        return GetInt(_config.GetSection(configKey).Value, defaultValue);
    }

    /// <summary>
    /// Gets an array of integers from the configuration
    /// </summary>
    /// <param name="_config">The configuration instance</param>
    /// <param name="configKey">The configuration key to look up</param>
    /// <param name="defaultValue">Default value to use if the key is not found or conversion fails</param>
    /// <returns>An array of integers from configuration or default</returns>
    public static int[] GetIntList(this IConfiguration _config, string configKey, string? defaultValue = null)
    {
        ArgumentNullException.ThrowIfNull(_config);
        return GetIntList(_config.GetSection(configKey).Value, defaultValue);
    }

    /// <summary>
    /// Gets a string value from the configuration
    /// </summary>
    /// <param name="_config">The configuration instance</param>
    /// <param name="configKey">The configuration key to look up</param>
    /// <param name="defaultValue">Default value to use if the key is not found</param>
    /// <returns>The string value from configuration or default</returns>
    public static string GetString(this IConfiguration _config, string configKey, string? defaultValue = null)
    {
        ArgumentNullException.ThrowIfNull(_config);
        return GetString(_config.GetSection(configKey).Value, defaultValue);
    }

    /// <summary>
    /// Gets an array of strings from the configuration
    /// </summary>
    /// <param name="_config">The configuration instance</param>
    /// <param name="configKey">The configuration key to look up</param>
    /// <param name="defaultValue">Default value to use if the key is not found</param>
    /// <returns>An array of strings from configuration or default</returns>
    public static string[] GetStringList(this IConfiguration _config, string configKey, string? defaultValue = null)
    {
        ArgumentNullException.ThrowIfNull(_config);
        return GetStringList(_config.GetSection(configKey).Value, defaultValue);
    }
}


