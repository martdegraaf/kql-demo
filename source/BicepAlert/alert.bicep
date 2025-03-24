param version string = utcNow('yyMMddHHmm')
var location = resourceGroup().location

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'FunctionActionGroup'
  location: 'Global'
  properties: {
    groupShortName: 'FuncAG'
    enabled: true
    webhookReceivers: [
      {
        name: 'FunctionWebhook'
        serviceUri: 'https://bicep-fnapp-mart.azurewebsites.net/api/Function1'
      }
    ]
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing =  {
  name: 'bicep-appi-mart'
}

resource alert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: 'ExceptionAlert'
  location: location
  properties: {
    description: 'Alert for specific exception'
    enabled: true
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
    scopes:[
      applicationInsights.id
    ]
    criteria: {
      allOf: [
        {
          query: 'exceptions | where exceptionType == "Demo.KQL.FunctionsNet9.DemoException"'
          timeAggregation: 'Count'
          
          operator: 'GreaterThan'
          threshold: 0
        }
      ]
    }
    evaluationFrequency: 'PT5M' // every 5 min
    windowSize: 'PT5M'
    severity: 1 //0 Critical, 1 Error, 2 Warning, 3 Informational, 4 Verbose
  }
}
