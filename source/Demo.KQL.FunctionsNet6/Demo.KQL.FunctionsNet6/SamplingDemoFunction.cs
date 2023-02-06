using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace Demo.KQL.FunctionsNet6
{
    public class SamplingDemoFunction
    {
        private readonly ILogger<SamplingDemoFunction> _logger;

        public SamplingDemoFunction(ILogger<SamplingDemoFunction> logger)
        {
            _logger = logger;
        }

        [FunctionName("SamplingDemoFunction")]
        public void Run([TimerTrigger("0 */5 * * * *")] TimerInfo myTimer)
        {
            for (int i = 1; i <= 1000; i++)
            {
                _logger.LogInformation("Logging messages from {functionName} iteration: {i}", nameof(SamplingDemoFunction), i);
            }
        }
    }
}
