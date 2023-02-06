using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using System;

namespace Demo.KQL.FunctionsNet6
{
    public class BreakingFunction
    {
        private readonly ILogger<BreakingFunction> _logger;

        public BreakingFunction(ILogger<BreakingFunction> logger)
        {
            _logger = logger;
        }

        [FunctionName("BreakingFunction")]
        public void Run([TimerTrigger("0 */5 * * * *")] TimerInfo myTimer)
        {
            _logger.LogInformation("Executing {function}", nameof(BreakingFunction));

            Random rnd = new();
            int times = rnd.Next(1, 3);
            try
            {
                int randomnessWillGuide = times switch
                {
                    1 => throw new Exception("We rolled 1 so heres exception 1"),
                    2 => throw new InvalidOperationException("We rolled 1 so heres exception 2"),
                    3 => throw new DemoException("We rolled 1 so heres exception 3"),
                    _ => throw new Exception("This should be litteraly impossiblee"),
                };
            }
            catch (DemoException ex)
            {
                _logger.LogError(ex, "A demo error occured during BreakingFunction {times}", times);
                // we expected this exception and will swallow, no exception today.
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "A unexpected occured during BreakingFunction {times}", times);
                throw;
            }
        }
    }
}
