@description('Name of Web App')
param votingWebAppName string = 'NavarApp'
param location string = resourceGroup().location
@allowed([
  'dev'
  'prod'
])
param env string = 'dev'

var votingApi_Name = 'web-votingapi-${votingWebAppName}-${env}'
var votingWeb_Name = 'web-${votingWebAppName}-${env}'
var votingRedisCache_Name = 'redis-voting-${votingWebAppName}-${env}'
var votingApiPlan_Name = 'plan-votingapi-${votingWebAppName}-${env}'
var votingWebPlan_Name = 'plan-votingweb-${votingWebAppName}-${env}'
var functionVoteCounter_Name = 'func-votecounter-${votingWebAppName}-${env}'
var sqlServer_Name = 'sql-voting-${votingWebAppName}-${env}'
var sqlDatabase_Name = 'sqldb-voting-${votingWebAppName}-${env}'
var serviceBusVotings_Name = 'sb-voting-${votingWebAppName}-${env}'
var functionVoteCounterPlan_Name = 'plan-func-votecounter-${votingWebAppName}-${env}'
var databaseAccounts_VotingCosmos_Name = 'cosmos-voting-${votingWebAppName}-${env}'
var functionStorageAccount = 'stfn-${votingWebAppName}-${env}'
var frontdoors_VotingFrontDoor_name = 'fd-voting-${votingWebAppName}-${env}'

resource redisCache 'Microsoft.Cache/redis@2021-06-01' = {
  name: votingRedisCache_Name
  location: location
  properties: {
    sku: {
      capacity: 3
      family: 'C'
      name: 'Basic'
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: databaseAccounts_VotingCosmos_Name
  kind: 'GlobalDocumentDB'
  properties: {
    createMode: 'Default'
    ipRules: []
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    capabilities: []
    cors: []
    networkAclBypassResourceIds: []
  }

  resource sqlDatabase 'sqlDatabases@2022-05-15' = {
    name: 'cacheDB'
    properties: {
      resource: {
        id: 'cacheDB'
      }
    }

    resource cacheContainer 'containers@2022-05-15' = {
      name: 'cacheContainer'
      properties: {
        resource: {
          id: 'cacheContainer'
          indexingPolicy: {
            indexingMode: 'consistent'
            automatic: true
          }
          partitionKey: {
            paths: [
              '/MessageType'
            ]
            kind: 'Hash'
          }
          conflictResolutionPolicy: {
            mode: 'LastWriterWins'
            conflictResolutionPath: '/_ts'
          }
        }
      }
    }
  }
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: serviceBusVotings_Name
  location: location
  sku: {
    name: 'Premium'
    tier: 'Premium'
    capacity: 1
  }

  resource authRule 'AuthorizationRules@2021-11-01' = {
    name: 'RootManagedSharedAccessKey'
    properties: {
      rights: [
        'Listen'
        'Manage'
        'Send'
      ]
    }
  }

  resource queue 'queues@2021-11-01' = {
    name: 'sbq-voting'
    properties: {
      maxMessageSizeInKilobytes: 1024
      lockDuration: 'PT1M'
      requiresDuplicateDetection: false
      requiresSession: false
      enableBatchedOperations: true
      maxDeliveryCount: 10
      enablePartitioning: false
      enableExpress: false
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: functionStorageAccount
  location: location
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        file: {
          enabled: true
        }
        blob: {
          enabled: true
        }
      }
    }
  }
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01-preview' = {
  name: sqlServer_Name
  location: location
  properties: {
    administratorLogin: ''
    administratorLoginPassword: ''
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }

  resource sqlDb 'databases@2021-11-01-preview' = {
    name: sqlDatabase_Name
    location: location
    sku: {
      name: 'Standard'
      tier: 'Standard'
    }
  }

  resource fwRule 'firewallRules@2021-02-01-preview' = {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }
}

resource functionVotePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: functionVoteCounterPlan_Name
  location: location
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

resource votingApiPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: votingApiPlan_Name
  location: location
  kind: 'app'
  sku: {
    name: 'S1'
    tier: 'Standard'
    size: 'S1'
    family: 'S'
    capacity: 1
  }
  properties: {
    perSiteScaling: false
    reserved: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
  }
}

resource votingWebPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: votingWebPlan_Name
  location: location
  kind: 'app'
  sku: {
    name: 'S1'
    tier: 'Standard'
    size: 'S1'
    family: 'S'
    capacity: 1
  }
  properties: {
    perSiteScaling: false
    reserved: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
  }
}

resource votingFunction 'Microsoft.Web/sites@2022-03-01' = {
  name: functionVoteCounter_Name
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    serverFarmId: functionVotePlan.id
    reserved: false
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    clientCertEnabled: false
    hostNamesDisabled: false
    containerSize: 1536
    dailyMemoryTimeQuota: 0
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: null
      phpVersion: null
      pythonVersion: null
      nodeVersion: null
      linuxFxVersion: ''
      requestTracingEnabled: false
      remoteDebuggingEnabled: false
      httpLoggingEnabled: false
      logsDirectorySizeLimit: 35
      detailedErrorLoggingEnabled: false
      publishingUsername: '$VotingWeb'
      appSettings: [
        {
          name: 'SERVICEBUS_CONNECTION_STRING'
          value: '${listkeys(serviceBus::authRule.id, serviceBus.apiVersion).primaryConnectionString}'
        }
        {
          name: 'AzureWebJobStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[1].value}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[1].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
      ]
    }
  }
}

resource votingApi 'Microsoft.Web/sites@2022-03-01' = {
  name: votingApi_Name
  location: location
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    hostNameSslStates: [
      {
        name: '${votingApi_Name}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${votingApi_Name}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Repository'
      }
    ]
    serverFarmId: votingApiPlan.id
    reserved: false
    scmSiteAlsoStopped: false
    clientAffinityEnabled: true
    clientCertEnabled: false
    hostNamesDisabled: false
    containerSize: 0
    dailyMemoryTimeQuota: 0
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: null
      phpVersion: null
      pythonVersion: null
      nodeVersion: null
      linuxFxVersion: ''
      requestTracingEnabled: false
      remoteDebuggingEnabled: false
      httpLoggingEnabled: false
      logsDirectorySizeLimit: 35
      detailedErrorLoggingEnabled: false
      publishingUsername: '$VotingWeb'
      appSettings: [
        {
          name: 'ConnectionStrings:SqlDbConnection'
          value: ''
        }
      ]
    }
  }
}

resource votingWeb 'Microsoft.Web/sites@2022-03-01' = {
  name: votingWeb_Name
  location: location
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    hostNameSslStates: [
      {
        name: '${votingWeb_Name}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${votingWeb_Name}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Repository'
      }
    ]
    serverFarmId: votingWebPlan.id
    reserved: false
    scmSiteAlsoStopped: false
    clientAffinityEnabled: true
    clientCertEnabled: false
    hostNamesDisabled: false
    containerSize: 0
    dailyMemoryTimeQuota: 0
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: null
      phpVersion: null
      pythonVersion: null
      nodeVersion: null
      linuxFxVersion: ''
      requestTracingEnabled: false
      remoteDebuggingEnabled: false
      httpLoggingEnabled: false
      logsDirectorySizeLimit: 35
      detailedErrorLoggingEnabled: false
      publishingUsername: '$VotingWeb'
      appSettings: [
        {
          name: 'ConnectionStrings:sbConnectionString'
          value: '${listkeys(serviceBus::authRule.id, serviceBus.apiVersion).primaryConnectionString}'
        }
        {
          name: 'ConnectionStrings:VotingDataAPIBaseUri'
          value: 'https://${votingApi_Name}.azurewebsite.net'
        }
        {
          name: 'ConnectionStrings:RedisConnectionString'
          value: '${votingRedisCache_Name}.redis.cache.windows.net:6380,abortConnect=false,ssl=true,password=${listKeys(redisCache.id, redisCache.apiVersion).primaryKey}'
        }
        {
          name: 'ConnectionStrings:queueName"'
          value: 'sbq-voting'
        }
        {
          name: 'ConnectionStrings:CosmosUri"'
          value: 'https://${databaseAccounts_VotingCosmos_Name}.documents.azure.com:433/'
        }
        {
          name: 'ConnectionStrings:CosmosKey"'
          value: '${listKeys(cosmosDb.id, cosmosDb.apiVersion).primaryMasterKey}'
        }
      ]
    }
  }
}

resource frontDoor 'Microsoft.Network/frontDoors@2020-05-01' = {
  name: frontdoors_VotingFrontDoor_name
  location: 'global'
  properties: {
    friendlyName: frontdoors_VotingFrontDoor_name
    enabledState: 'Enabled'
    healthProbeSettings: [
      {
        name: 'default'
        properties: {
          path: '/'
          protocol: 'Https'
          intervalInSeconds: 30
          healthProbeMethod: 'GET'
          enabledState: 'Enabled'
        }
      }
    ]
    loadBalancingSettings: [
      {
        name: 'default'
        properties: {
          sampleSize: 4
          successfulSamplesRequired: 2
          additionalLatencyMilliseconds: 0
        }
      }
    ]
    frontendEndpoints: [
      {
        name: 'default'
        properties: {
          hostName: 'NavarVotingApp.azurefd.net'
          sessionAffinityEnabledState: 'Disabled'
          sessionAffinityTtlSeconds: 0
        }
      }
    ]
    backendPools: [
      {
        name: 'voting-web'
        properties: {
          backends: [
            {
              address: '${votingWeb_Name}.azurewebsites.net'
              enabledState: 'Enabled'
              httpPort: 80
              httpsPort: 443
              priority: 1
              weight: 50
              backendHostHeader: '${votingWeb_Name}.azurewebsites.net'
            }
          ]
          healthProbeSettings: {
            id: resourceId('Microsoft.Network/frontdoors/healthProbeSettings',  frontdoors_VotingFrontDoor_name,  'default')
          }
          loadBalancingSettings: {
            id: resourceId('Microsoft.Network/frontdoors/loadBalancingSettings',  frontdoors_VotingFrontDoor_name,  'default')
          }
        }
      }
    ]
    routingRules:[
      {
        name: 'all'
        properties: {
          frontendEndpoints: [
            {
              id: resourceId('Microsoft.Network/frontdoors/frontendEndpoints',  frontdoors_VotingFrontDoor_name,  'default')
            }
          ]
          acceptedProtocols:[
            'Http'
            'Https'
          ]
          patternsToMatch: [
            '/*'
          ]
          enabledState: 'Enabled'
          routeConfiguration: {
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
            customForwardingPath: null
            forwardingProtocol: 'MatchRequest'
            backendPool: {
              id: resourceId('Microsoft.Network/frontdoors/backendPools',  frontdoors_VotingFrontDoor_name,  'voting-web')
            }
            cacheConfiguration: null
          }
        }
      }
    ]
    backendPoolsSettings: {
      enforceCertificateNameCheck: 'Enabled'
      sendRecvTimeoutSeconds: 30
    }
  }
}
