namespace UISampleSpark.Core.Extensions;

/// <summary>
/// LogExtensions Static Class
/// </summary>
public static class LogExtensions
{
    /// <summary>
    /// GetSerializeObjectString
    /// </summary>
    /// <typeparam name="T"></typeparam>
    /// <param name="objectToSerialize">The object to serialize.</param>
    /// <returns>System.String.</returns>
    public static string GetSerializeObjectString<T>(this T objectToSerialize)
    {
        try
        {
            using StringWriter writer = new();
            XmlSerializer oXS = new(typeof(T));
            XmlDocument myXML = new();
            oXS.Serialize(writer, objectToSerialize);
            myXML.LoadXml(writer.ToString());
            return myXML.OuterXml;
        }
        catch (InvalidOperationException)
        {
            // Serialization failed, fall back to text representation
            return objectToSerialize.GetTextObjectString();
        }
        catch (System.Xml.XmlException)
        {
            // XML parsing failed, fall back to text representation
            return objectToSerialize.GetTextObjectString();
        }
    }

    /// <summary>
    /// GetSerializeObjectString
    /// </summary>
    /// <typeparam name="T"></typeparam>
    /// <param name="lstObjectToSerialize">The LST object to serialize.</param>
    /// <returns>System.String.</returns>
    public static string GetSerializeObjectString<T>(this List<T> lstObjectToSerialize)
    {
        try
        {
            using StringWriter writer = new();
            XmlSerializer oXS = new(typeof(List<T>));
            XmlDocument myXML = new();
            oXS.Serialize(writer, lstObjectToSerialize);
            myXML.LoadXml(writer.ToString());
            return myXML.OuterXml;
        }
        catch (InvalidOperationException)
        {
            // Serialization failed, fall back to text representation
            return lstObjectToSerialize.GetTextObjectString();
        }
        catch (System.Xml.XmlException)
        {
            // XML parsing failed, fall back to text representation
            return lstObjectToSerialize.GetTextObjectString();
        }
    }

    /// <summary>
    /// IsSimpleType
    /// </summary>
    /// <param name="type">The type.</param>
    /// <returns><c>true</c> if [is simple type] [the specified type]; otherwise, <c>false</c>.</returns>
    public static bool IsSimpleType(this Type type)
    {
        ArgumentNullException.ThrowIfNull(type);
        Type[] simpleTypes =
        [
            typeof(string),
            typeof(decimal),
            typeof(DateTime),
            typeof(DateTimeOffset),
            typeof(TimeSpan),
            typeof(Guid)
        ];

        return type.IsValueType ||
               type.IsPrimitive ||
               simpleTypes.Contains(type) ||
               Convert.GetTypeCode(type) != TypeCode.Object;
    }

    /// <summary>
    /// To get Dictionary of Single record with property.
    /// </summary>
    /// <param name="record">record as object</param>
    /// <returns>Dictionary object</returns>
    private static Dictionary<string, object> GetDictionaryWithPropertiesForOneRecord(object? record)
    {
        if (record is null)
            return [];

        Type type = record.GetType();
        PropertyInfo[] properties = type.GetProperties();
        Dictionary<string, object> dictionary = [];

        foreach (PropertyInfo propertyInfo in properties.Where(p => IsSimpleType(p.PropertyType)))
        {
            object? value = propertyInfo.GetValue(record, []);
            if (value is not null)
            {
                dictionary.Add(propertyInfo.Name, value);
            }
        }

        return dictionary;
    }

    /// <summary>
    /// To get record with their properties
    /// </summary>
    /// <param name="record">record as object</param>
    /// <returns>String</returns>
    private static string GetTextObjectString(this object? record)
    {
        if (record is null)
            return string.Empty;

        StringBuilder recordLog = new();
        Dictionary<string, object> recordDictionary = GetDictionaryWithPropertiesForOneRecord(record);

        try
        {
            foreach (KeyValuePair<string, object> kvp in recordDictionary)
            {
                object? value = kvp.Value;
                recordLog.Append(value is not null 
                    ? $"{kvp.Key}:{value}|" 
                    : $"{kvp.Key}:[NULL]|");
            }
        }
        catch (InvalidOperationException ex)
        {
            // Collection was modified during iteration
            recordLog.AppendLine(ex.Message);
        }
        catch (ArgumentException ex)
        {
            // Invalid argument in string formatting
            recordLog.AppendLine(ex.Message);
        }

        return recordLog.ToString();
    }
}
