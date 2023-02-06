using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using System;

namespace Demo.KQL.FunctionsNet6
{
    public class LoggingFunction
    {
        private readonly ILogger _logger;

        public LoggingFunction(ILoggerFactory loggerFactory)
        {
            _logger = loggerFactory.CreateLogger<LoggingFunction>();
        }

        [FunctionName("LoggingFunction")]
        public void Run([TimerTrigger("0 */5 * * * *")] TimerInfo myTimer)
        {
            _logger.LogInformation("C# Timer trigger function {functioName} executed at: {now}", nameof(BreakingFunction), DateTime.Now);
            _logger.LogInformation("Next timer schedule for {functionName} at: {next}", nameof(BreakingFunction), myTimer.ScheduleStatus.Next);


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
