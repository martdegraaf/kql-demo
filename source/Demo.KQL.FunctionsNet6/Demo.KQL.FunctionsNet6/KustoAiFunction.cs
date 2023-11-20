using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Microsoft.Azure.WebJobs.Kusto;
using System.Collections.Generic;
using Kusto.Cloud.Platform.Utils;
using static System.Net.WebRequestMethods;
using Kusto.Cloud.Platform.Data;
using System.Linq;
using Kusto.Data;

namespace Demo.KQL.FunctionsNet6
{
    public static class KustoAiFunction
    {
        [FunctionName("KustoAiFunction")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = "GetKustoAiOutput")] HttpRequest req,
            ILogger log)
        {
            var kustoUri = "https://ade.applicationinsights.io/subscriptions/5bb4a4b4-11df-4ed5-a790-cd6c34a98417/resourcegroups/kql-demo/providers/microsoft.insights/components/bicep-appi-2wej7bj";
            var kustoConnectionStringBuilder = new KustoConnectionStringBuilder(kustoUri)
#if DEBUG
                .WithAadUserPromptAuthentication();
#else
                .WithAadSystemManagedIdentity();
#endif
            kustoConnectionStringBuilder.InitialCatalog = "bicep-appi-2wej7bj";
            var client = Kusto.Data.Net.Client.KustoClientFactory.CreateCslQueryProvider(kustoConnectionStringBuilder);

            using var reader = client.ExecuteQuery("exceptions | where timestamp > ago(2h) | count");
            log.LogInformation($"KustoAiFunction function started");

            var list = reader.ToEnumerable<Int64>().ToList();
            return new OkObjectResult(list.First());
        }
    }
}