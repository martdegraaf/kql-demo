
using Microsoft.Azure.Functions.Worker;
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

        [Function("SamplingDemoFunction")]
        public void Run([TimerTrigger("0 */10 * * * *")] TimerInfo myTimer)
        {
            for (int i = 1; i <= 1000; i++)
            {
                _logger.LogInformation("Logging messages from {functionName} iteration: {i}", nameof(SamplingDemoFunction), i);
            }
        }
    }
}
