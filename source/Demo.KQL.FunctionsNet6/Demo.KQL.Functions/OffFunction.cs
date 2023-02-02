using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace Demo.KQL.Functions
{
    public class OffFunction
    {
        private readonly ILogger _logger;

        public OffFunction(ILoggerFactory loggerFactory)
        {
            _logger = loggerFactory.CreateLogger<OffFunction>();
        }

        [Function("OffFunction")]
        public void Run([TimerTrigger("0 */10 * * * *")] MyInfo myTimer)
        {
            _logger.LogInformation($"C# Timer trigger function executed at: {DateTime.Now}");
            _logger.LogInformation($"Next timer schedule at: {myTimer.ScheduleStatus.Next}");


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
