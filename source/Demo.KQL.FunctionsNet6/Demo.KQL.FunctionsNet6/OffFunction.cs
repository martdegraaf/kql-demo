using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using System;


namespace Demo.KQL.FunctionsNet6
{
    public class OffFunction
    {
        private readonly ILogger _logger;

        public OffFunction(ILogger<OffFunction> logger)
        {
            _logger = logger;
        }

        [FunctionName("OffFunction")]
        public void Run([TimerTrigger("0 5 * * * *")] TimerInfo myTimer)
        {
            _logger.LogInformation("C# Timer trigger function {functionName} executed at: {now}", nameof(OffFunction), DateTime.Now);
            _logger.LogInformation("Next timer schedule for {functionName} at: {next}", nameof(OffFunction), myTimer.ScheduleStatus.Next);



            var times = SimulateOtherDuplicateOperations();
        }

        private int SimulateOtherDuplicateOperations()
        {
            Random rnd = new();
            int times = rnd.Next(1, 3);
            for (int i = 0; i < times; i++)
            {
                _logger.LogInformation("Sending mail {mailType}, {someId}", "Duplicate", i);
            }

            return times;
        }
    }
}
