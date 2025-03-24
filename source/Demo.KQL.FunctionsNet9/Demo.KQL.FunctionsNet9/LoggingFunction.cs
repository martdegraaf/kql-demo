using Demo.KQL.FunctionsNet9.SensitiveLogging;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using System;

namespace Demo.KQL.FunctionsNet9
{
    public class LoggingFunction
    {
        private readonly ILogger _logger;

        public LoggingFunction(ILogger<LoggingFunction> logger)
        {
            _logger = logger;
        }

        [Function("LoggingFunction")]
        public void Run([TimerTrigger("0 */5 * * * *")] TimerInfo myTimer)
        {
            _logger.LogInformation("C# Timer trigger function {functionName} executed at: {now}", nameof(LoggingFunction), DateTime.Now);
            _logger.LogInformation("Next timer schedule for {functionName} at: {next}", nameof(LoggingFunction), myTimer.ScheduleStatus.Next);


            var model = new MyModel
            {
                Name = "John Doe",
                SensitiveData = "Secret123",
                NoLogThis= "Kiekeleboe"
            };

            // Log the model (the sensitive data will be masked)
            _logger.LogInformation("Logging model: {@Model}", model);

            var times = SimulateDuplicateOperations();
            try
            {
                SimulateExceptions();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "A demo error occured during SimulateExceptions {times}", times);
            }
        }

        private int SimulateDuplicateOperations()
        {
            Random rnd = new();
            int times = rnd.Next(1, 3);
            for (int i = 0; i < times; i++)
            {
                _logger.LogInformation("Sending mail {mailType}, {someId}", "Duplicate", i);
            }

            return times;
        }

        private static void SimulateExceptions()
        {
            Random rnd = new();
            int times = rnd.Next(1, 3);
            int randomnessWillGuide = times switch
            {
                1 => throw new Exception("We rolled 1 so heres exception 1"),
                2 => throw new InvalidOperationException("We rolled 1 so heres exception 2"),
                3 => throw new DemoException("We rolled 1 so heres exception 3"),
                _ => throw new Exception("This should be litteraly impossiblee"),
            };
        }
    }
}
