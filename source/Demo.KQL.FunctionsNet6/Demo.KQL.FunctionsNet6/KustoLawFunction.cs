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

namespace Demo.KQL.FunctionsNet6
{
    public static class KustoLawFunction
    {
        //https://learn.microsoft.com/en-us/azure/data-explorer/query-monitor-data#add-a-log-analyticsapplication-insights-workspace-to-azure-data-explorer-client-tools
        [FunctionName("KustoLawFunction")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = "GetKustoLawOutput")] HttpRequest req,
            ILogger log)
        {
            var client = Kusto.Data.Net.Client.KustoClientFactory.CreateCslQueryProvider("https://ade.loganalytics.io/subscriptions/5bb4a4b4-11df-4ed5-a790-cd6c34a98417/resourcegroups/kql-demo/providers/microsoft.operationalinsights/workspaces/bicep-law-2wej7bj;Fed=true;Initial Catalog=bicep-law-2wej7bj");
            using var reader = client.ExecuteQuery("AppExceptions | where TimeGenerated > ago(2h) | count");
            log.LogInformation($"KustoLawFunction function started");

            var list = reader.ToEnumerable<Int64>().ToList();
            return new OkObjectResult(list.First());
        }
    }
}