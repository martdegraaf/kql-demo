using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace Demo.KQL.FunctionsNet9
{
    public class Function1
    {
        private readonly ILogger<Function1> _logger;

        public Function1(ILogger<Function1> logger)
        {
            _logger = logger;
        }

        [Function("Function1")]
        public IActionResult Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequest req)
        {
            _logger.LogInformation("C# HTTP trigger function processed a request.");

            var model = new MyModel
            {
                Name = "John Doe",
                SensitiveData = "Secret123"
            };

            // Log the model (the sensitive data will be masked)
            _logger.LogInformation("Logging model: {@Model}", model);

            return new JsonResult(model);
        }
    }
}
