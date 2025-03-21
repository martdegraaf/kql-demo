namespace Demo.KQL.FunctionsNet9;
using System;
using System.Text.Json;
using System.Text.Json.Serialization;

public class SensitiveJsonConverter : JsonConverter<object>
{
    public override object Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        return JsonSerializer.Deserialize(ref reader, typeToConvert, options);
    }

    public override void Write(Utf8JsonWriter writer, object value, JsonSerializerOptions options)
    {
        // Check if the value is null or a primitive type
        if (value == null || IsPrimitiveType(value.GetType()))
        {
            // If it's a primitive type, serialize it normally
            JsonSerializer.Serialize(writer, value, options);
            return;
        }

        // If it's a complex type, process its properties
        var type = value.GetType();
        writer.WriteStartObject();

        foreach (var property in type.GetProperties())
        {
            var isSensitive = Attribute.IsDefined(property, typeof(SensitiveAttribute));

            // Get the property value
            var propertyValue = property.GetValue(value);

            if (isSensitive)
            {
                writer.WriteString(property.Name, "****"); // Mask sensitive data
            }
            else
            {
                // Write the property value directly
                if (propertyValue == null || IsPrimitiveType(propertyValue.GetType()))
                {
                    writer.WritePropertyName(property.Name);
                    JsonSerializer.Serialize(writer, propertyValue, options);
                }
                else
                {
                    // Handle complex types directly
                    writer.WritePropertyName(property.Name);
                    writer.WriteStartObject();
                    WriteComplexType(writer, propertyValue, options);
                    writer.WriteEndObject();
                }
            }
        }

        writer.WriteEndObject();
    }

    private void WriteComplexType(Utf8JsonWriter writer, object value, JsonSerializerOptions options)
    {
        var type = value.GetType();
        foreach (var property in type.GetProperties())
        {
            var isSensitive = Attribute.IsDefined(property, typeof(SensitiveAttribute));
            var propertyValue = property.GetValue(value);

            if (isSensitive)
            {
                writer.WriteString(property.Name, "****"); // Mask sensitive data
            }
            else
            {
                // Write the property value directly
                if (propertyValue == null || IsPrimitiveType(propertyValue.GetType()))
                {
                    writer.WritePropertyName(property.Name);
                    JsonSerializer.Serialize(writer, propertyValue, options);
                }
                else
                {
                    // Handle nested complex types
                    writer.WritePropertyName(property.Name);
                    writer.WriteStartObject();
                    WriteComplexType(writer, propertyValue, options);
                    writer.WriteEndObject();
                }
            }
        }
    }

    private bool IsPrimitiveType(Type type)
    {
        // Check if the type is a primitive type or a string
        return type.IsPrimitive || type == typeof(string) || type.IsEnum || type == typeof(decimal);
    }
}
