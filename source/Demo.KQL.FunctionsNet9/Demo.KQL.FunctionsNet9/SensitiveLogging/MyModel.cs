using Microsoft.Extensions.Logging;

namespace Demo.KQL.FunctionsNet9.SensitiveLogging
{
    public class MyModel
    {
        public string Name { get; set; }

        [LogPropertyIgnore]
        public string SensitiveData { get; set; }

        [LogPropertyIgnore]
        public string NoLogThis { get; set; }
        public string? NullableString { get; set; }
    }
}
