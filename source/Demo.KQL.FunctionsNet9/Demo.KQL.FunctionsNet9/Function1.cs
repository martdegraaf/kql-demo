using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;


namespace Demo.KQL.FunctionsNet9
{
    public partial class Function1
    {
        private readonly ILogger<Function1> _logger;

        public Function1(ILogger<Function1> logger)
        {
            _logger = logger;
        }

        [Function("Function1")]
        public IActionResult Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequest req)
        {
            _logger.LogWarning("C# HTTP trigger function processed a request.");

            var model = new MyModel
            {
                Name = "John Doe",
                SensitiveData = "Secret123"
            };

            // Log the model (the sensitive data will be masked)
            LogMySensitiveModel(_logger, model);

            return new JsonResult(model);
        }

        [LoggerMessage(
            Level = LogLevel.Debug,
            Message = "Logging Sesnsitive model: {model}")]
        private static partial void LogMySensitiveModel(ILogger logger, [LogProperties] MyModel model);
    }
}
