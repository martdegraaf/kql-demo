using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace Demo.KQL.FunctionsNet6
{
    public class SamplingDemoFunction
    {
        [FunctionName("SamplingDemoFunction")]
        public void Run([TimerTrigger("0 */5 * * * *")] TimerInfo myTimer, ILogger log)
        {
            for (int i = 1; i <= 1000; i++)
            {
                log.LogInformation("Logging messages from {functionName} iteration: {i}", nameof(SamplingDemoFunction), i);
            }
        }
    }
}
