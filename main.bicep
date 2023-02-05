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
  kind: 'functionapp'
  tags: {Owner:'Mart',Service:'demo',Team:'martteam'}
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: plan.id
    siteConfig: {
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
  kind: 'functionapp'
  tags: {Owner:'Mart',Service:'demo 2',Team:'martteam 2'}
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: plan.id
    siteConfig: {
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
