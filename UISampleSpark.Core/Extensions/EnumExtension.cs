namespace UISampleSpark.Core.Extensions;

/// <summary>
/// ENUM Extension Methods
/// </summary>
public static class EnumExtension
{
    /// <summary>
    /// Converts to Description String.
    /// </summary>
    /// <typeparam name="TEnum">The type of the t enum.</typeparam>
    /// <param name="enum">The enum.</param>
    /// <returns>System.String.</returns>
    public static string GetDescription(this Enum e)
    {
        if (e == null)
            return string.Empty;

        FieldInfo? fieldInfo = e.GetType().GetField(e.ToString());

        if (fieldInfo?.GetCustomAttributes(typeof(DisplayAttribute), false) is not DisplayAttribute[] descriptionAttributes
            || descriptionAttributes.Length == 0)
            return e.ToString();

        return descriptionAttributes[0].Description;
    }

    /// <summary>
    /// Gets Display Name of enum
    /// </summary>
    /// <param name="e">enum key name</param>
    /// <returns>enum value</returns>
    public static string GetDisplayName(this Enum e)
    {
        if (e == null)
            return string.Empty;

        FieldInfo? fieldInfo = e.GetType().GetField(e.ToString());

        if (fieldInfo?.GetCustomAttributes(typeof(DisplayAttribute), false) is not DisplayAttribute[] descriptionAttributes
            || descriptionAttributes.Length == 0)
            return e.ToString();

        return descriptionAttributes[0].Name;
    }

    /// <summary>
    /// Returns whether the given enum value is a defined value for its type.
    /// </summary>
    /// <typeparam name="T"></typeparam>
    /// <param name="enumValue">The enum value.</param>
    /// <returns><c>true</c> if the specified enum value is defined; otherwise, <c>false</c>.</returns>
    public static bool IsDefined<T>(this T enumValue)
        where T : Enum => EnumValueCache<T>.DefinedValues.Contains(enumValue);

    /// <summary>
    /// Generates Dictionary of int,string for an Enum
    /// </summary>
    /// <param name="enumValue">The enum value.</param>
    /// <returns>Dictionary&lt;System.Int32, System.String&gt;.</returns>
    public static Dictionary<int, string> ToDictionary(this Enum enumValue)
    {
        ArgumentNullException.ThrowIfNull(enumValue);
        Type enumType = enumValue.GetType();
        return Enum.GetValues(enumType).Cast<Enum>().ToDictionary(t => Convert.ToInt32(t), t => t.ToString());
    }

    /// <summary>
    /// Caches the defined values for each enum type for which this class is accessed.
    /// </summary>
    /// <typeparam name="T"></typeparam>
    private static class EnumValueCache<T>
        where T : Enum
    {
        /// <summary>
        /// The defined values
        /// </summary>
        public static readonly HashSet<T> DefinedValues = new((T[])Enum.GetValues(typeof(T)));
    }

    public static IEnumerable<T> GetAllValues<T>() where T : Enum
    {
        return Enum.GetValues(typeof(T)).Cast<T>();
    }
    public static TEnum ParseCaseInsensitive<TEnum>(string value) where TEnum : Enum
    {
        return (TEnum)Enum.Parse(typeof(TEnum), value, ignoreCase: true);
    }
    public static string[] GetNames<T>() where T : Enum
    {
        return Enum.GetNames(typeof(T));
    }
    public static Type GetUnderlyingType<T>() where T : Enum
    {
        return Enum.GetUnderlyingType(typeof(T));
    }




}
