/*
** Parameters
*/
@minLength(3)
@maxLength(6)
@description('Prefix to be used by all resources deployed by this template')
param resourcePrefix string = 'martkqldemo'

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Standard_RAGRS'
  'Premium_LRS'
  'Premium_ZRS'
])
@description('Storage account SKU name')
param storageSkuName string = 'Standard_LRS'

@description('API key for external service')
@secure()
param apiKey string


param appServicePlanSkuName string = 'Y1'

/*
** Variables
*/
var location = resourceGroup().location
var resourceSuffix = substring(uniqueString(resourceGroup().id), 0, 7)
var storageAccountName = '${resourcePrefix}st${resourceSuffix}'
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'
var appInsightsName = '${resourcePrefix}-appi-${resourceSuffix}'
var appServicePlanName = '${resourcePrefix}-asp-${resourceSuffix}'
var keyVaultName = '${resourcePrefix}-kv-${resourceSuffix}'
var functionAppName = '${resourcePrefix}-fnapp-${resourceSuffix}'
var functionAppName2 = '${resourcePrefix}-fnapp-${resourceSuffix}-2'
var logAnalyticsName = '${resourcePrefix}-law-${resourceSuffix}'

var storageBlobDataContributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
var keyVaultSecretsUserRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

/*
** Resources
*/

// Deploy the storage account and create a container to hold resources which might be used by the Function App
// later on
resource storage 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
        queue: {
          enabled: true
        }
        table: {
          enabled: true
        }
      }
    }
  }
  
  resource blobService 'blobServices' = {
    name: 'default'

    resource content 'containers' = {
      name: 'content'
    }
  }
}

// Assign permissions to the storage account for the Azure Function app
resource storageFunctionAppPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storage.id, funcApp.name, storageBlobDataContributorRole)
  scope: storage
  properties: {
    principalId: funcApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataContributorRole
  }
}

// Create a new Log Analytics workspace to back the Azure Application Insights instance
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Application Insights instance
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'other'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    SamplingPercentage: 40
    DisableIpMasking: false
    WorkspaceResourceId: logAnalytics.id
  }
}

// Deploy a consumption plan instance
resource plan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: appServicePlanSkuName
  }
  properties: {
    reserved: true
  }
}

// Create the KeyVault instance and add the API key as a secret to it. Enable RBAC for authorization rather than using
// access policies
resource kv 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: false
  }

  resource storageNameSecret 'secrets' = {
    name: 'ExternalServiceApiKey'
    properties: {
      contentType: 'text/plain'
      value: apiKey
    }
  }
}

// Assign secret user permissions to the Azure Function app
resource kvFunctionAppPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(kv.id, funcApp.name, keyVaultSecretsUserRole)
  scope: kv
  properties: {
    principalId: funcApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: keyVaultSecretsUserRole
  }
}

// Deploy the Azure Function app with application settings including one which references the API Key
// held in KeyVault
resource funcApp 'Microsoft.Web/sites@2021-02-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  tags: {Owner:'Mart',Service:'demo',Team:'martteam'}
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'DOTNET|7.0'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      netFrameworkVersion: 'v7.0'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'ApiKey'
          value: '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=${kv::storageNameSecret.name})'
        }
        {
          name: 'ContentStorageAccount'
          value: storage.name
        }
        {
          name: 'ContentContainer'
          value: storage::blobService::content.name
        }
      ]
    }
  }
}


// Deploy the Azure Function app with application settings including one which references the API Key
// held in KeyVault
resource funcApp2 'Microsoft.Web/sites@2021-02-01' = {
  name: functionAppName2
  location: location
  kind: 'functionapp,linux'
  tags: {Owner:'Mart',Service:'demo 2',Team:'martteam 2'}
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'DOTNET|6.0'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      netFrameworkVersion: 'v6.0'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'ApiKey'
          value: '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=${kv::storageNameSecret.name})'
        }
        {
          name: 'ContentStorageAccount'
          value: storage.name
        }
        {
          name: 'ContentContainer'
          value: storage::blobService::content.name
        }
      ]
    }
  }
}

@description('Generated from /subscriptions/5bb4a4b4-11df-4ed5-a790-cd6c34a98417/resourceGroups/kql-demo/providers/Microsoft.Portal/dashboards/demo-dashboard')
resource demodashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          {
            position: {
              x: 0
              y: 0
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: []
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              settings: {
                content: {
                  settings: {
                    content: '## Marts KQL demo\r\nThis is just markdown... This dashboard is managed by a bicep template.'
                  }
                }
              }
            }
          }
          {
            position: {
              x: 6
              y: 0
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'resourceTypeMode'
                  isOptional: true
                }
                {
                  name: 'ComponentId'
                  isOptional: true
                }
                {
                  name: 'Scope'
                  value: {
                    resourceIds: [
                      '/subscriptions/5bb4a4b4-11df-4ed5-a790-cd6c34a98417/resourceGroups/kql-demo/providers/microsoft.insights/components/bicep-appi-2wej7bj'
                    ]
                  }
                  isOptional: true
                }
                {
                  name: 'PartId'
                  value: '993114d6-97a4-4adf-8623-e6b3038622bf'
                  isOptional: true
                }
                {
                  name: 'Version'
                  value: '2.0'
                  isOptional: true
                }
                {
                  name: 'TimeRange'
                  value: 'P1D'
                  isOptional: true
                }
                {
                  name: 'DashboardId'
                  isOptional: true
                }
                {
                  name: 'DraftRequestParameters'
                  isOptional: true
                }
                {
                  name: 'Query'
                  value: 'traces\n| summarize count() by Date = bin(timestamp, 1h), cloud_RoleName\n| render columnchart with (title="Traces per hour per rolename")\n\n'
                  isOptional: true
                }
                {
                  name: 'ControlType'
                  value: 'FrameControlChart'
                  isOptional: true
                }
                {
                  name: 'SpecificChart'
                  value: 'StackedColumn'
                  isOptional: true
                }
                {
                  name: 'PartTitle'
                  value: 'Traces per hour per rolename'
                  isOptional: true
                }
                {
                  name: 'PartSubTitle'
                  value: 'bicep-appi-2wej7bj'
                  isOptional: true
                }
                {
                  name: 'Dimensions'
                  value: {
                    xAxis: {
                      name: 'Date'
                      type: 'datetime'
                    }
                    yAxis: [
                      {
                        name: 'count_'
                        type: 'long'
                      }
                    ]
                    splitBy: [
                      {
                        name: 'cloud_RoleName'
                        type: 'string'
                      }
                    ]
                    aggregation: 'Sum'
                  }
                  isOptional: true
                }
                {
                  name: 'LegendOptions'
                  value: {
                    isEnabled: true
                    position: 'Bottom'
                  }
                  isOptional: true
                }
                {
                  name: 'IsQueryContainTimeRange'
                  value: false
                  isOptional: true
                }
              ]
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              settings: {
              }
            }
          }
          {
            position: {
              x: 0
              y: 4
              rowSpan: 5
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'partTitle'
                  value: 'resources-tags'
                  isOptional: true
                }
                {
                  name: 'query'
                  value: 'resources\r\n    | where isnotempty(tags)\r\n    | extend teamTag = tostring(tags["team"])\r\n    | extend serviceTag = tostring(tags["Service"])\r\n    | extend serviceTag2 = tostring(tags["service"])\r\n    | where resourceGroup == "kql-demo"\r\n    | project name, teamTag, serviceTag\r\n| order by [\'serviceTag\'] desc'
                  isOptional: true
                }
                {
                  name: 'chartType'
                  isOptional: true
                }
                {
                  name: 'isShared'
                  isOptional: true
                }
                {
                  name: 'queryId'
                  value: 'c0e6ac29-b998-4225-abfb-b475ad9abbbc'
                  isOptional: true
                }
                {
                  name: 'formatResults'
                  isOptional: true
                }
                {
                  name: 'queryScope'
                  value: {
                    scope: 0
                    values: []
                  }
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/ArgQueryGridTile'
              settings: {
              }
            }
          }
          {
            position: {
              x: 6
              y: 4
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'resourceTypeMode'
                  isOptional: true
                }
                {
                  name: 'ComponentId'
                  isOptional: true
                }
                {
                  name: 'Scope'
                  value: {
                    resourceIds: [
                      '/subscriptions/5bb4a4b4-11df-4ed5-a790-cd6c34a98417/resourceGroups/kql-demo/providers/microsoft.insights/components/bicep-appi-2wej7bj'
                    ]
                  }
                  isOptional: true
                }
                {
                  name: 'PartId'
                  value: '013f287c-4d6e-4193-a350-0457d11665e6'
                  isOptional: true
                }
                {
                  name: 'Version'
                  value: '2.0'
                  isOptional: true
                }
                {
                  name: 'TimeRange'
                  isOptional: true
                }
                {
                  name: 'DashboardId'
                  isOptional: true
                }
                {
                  name: 'DraftRequestParameters'
                  isOptional: true
                }
                {
                  name: 'Query'
                  value: 'union requests,dependencies,pageViews,browserTimings,exceptions,traces\n| where timestamp > ago(1d)\n| summarize RetainedPercentage = 100/avg(itemCount) by bin(timestamp, 1h), itemType\n| order by RetainedPercentage asc\n'
                  isOptional: true
                }
                {
                  name: 'ControlType'
                  value: 'AnalyticsGrid'
                  isOptional: true
                }
                {
                  name: 'SpecificChart'
                  isOptional: true
                }
                {
                  name: 'PartTitle'
                  value: 'Analytics'
                  isOptional: true
                }
                {
                  name: 'PartSubTitle'
                  value: 'bicep-appi-2wej7bj'
                  isOptional: true
                }
                {
                  name: 'Dimensions'
                  isOptional: true
                }
                {
                  name: 'LegendOptions'
                  isOptional: true
                }
                {
                  name: 'IsQueryContainTimeRange'
                  value: true
                  isOptional: true
                }
              ]
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              settings: {
              }
            }
          }
        ]
      }
    ]
    metadata: {
      model: {
        timeRange: {
          value: {
            relative: {
              duration: 24
              timeUnit: 1
            }
          }
          type: 'MsPortalFx.Composition.Configuration.ValueTypes.TimeRange'
        }
        filterLocale: {
          value: 'en-us'
        }
        filters: {
          value: {
            MsPortalFx_TimeRange: {
              model: {
                format: 'utc'
                granularity: 'auto'
                relative: '24h'
              }
              displayCache: {
                name: 'UTC Time'
                value: 'Past 24 hours'
              }
              filteredPartIds: [
                'StartboardPart-LogsDashboardPart-438ae423-c0a8-45d1-89a0-4b0401b8700b'
                'StartboardPart-LogsDashboardPart-438ae423-c0a8-45d1-89a0-4b0401b8700d'
              ]
            }
          }
        }
      }
    }
  }
  location: location
  tags: {
    'hidden-title': 'My demo Bicep dashboard'
  }
  name: 'demo-dashboard'
}
