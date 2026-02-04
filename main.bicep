param location string = resourceGroup().location

param deployArcWebhook bool = true

param windowsServerLogicAppWebhookName string = 'la-arc-sa-windows-webhook'
param windowsServerLogicAppScheduledName string = 'la-arc-sa-windows-scheduled'
param sqlServerLogicAppScheduledName string = 'la-arc-sa-sql-scheduled'
param integrationAccountName string = 'ia-arc-logic'

// list of Azure subscription IDs to monitor Arc resources
param arcSubscriptions array = []

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'mi-arc-logicapps'
  location: location
}

resource scheduledLogicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: windowsServerLogicAppScheduledName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    definition: loadJsonContent('logicApps/sa-server-scheduled.json', 'definition')
  }
}

resource scheduledSqlLogicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: sqlServerLogicAppScheduledName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    definition: loadJsonContent('logicApps/sa-sql-scheduled.json', 'definition')
  }
}

resource integrationAccount 'Microsoft.Logic/integrationAccounts@2019-05-01' = if (deployArcWebhook) {
  name: integrationAccountName
  location: location
  sku: {
    name: 'Free'
  }
  properties: {}
}

resource webhookLogicApp 'Microsoft.Logic/workflows@2019-05-01' = if (deployArcWebhook) {
  name: windowsServerLogicAppWebhookName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    integrationAccount: {
      id: integrationAccount.id
    }

    definition: loadJsonContent('logicApps/sa-server-webhook.json', 'definition')
  }
}

resource systemTopic 'Microsoft.EventGrid/systemTopics@2021-12-01' = [
  for subscriptionId in arcSubscriptions: if (deployArcWebhook) {
    name: 'st-arc-resource-events-${subscriptionId}'
    location: 'global'
    properties: {
      source: '/subscriptions/${subscriptionId}'
      topicType: 'Microsoft.Resources.Subscriptions'
    }
  }
]

resource eventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2021-12-01' = [
  for (subscriptionId, index) in arcSubscriptions: if (deployArcWebhook) {
    parent: systemTopic[index]
    name: 'sub-arc-machines-creation-${subscriptionId}'
    properties: {
      destination: {
        endpointType: 'WebHook'
        properties: {
          endpointUrl: listCallbackUrl('${webhookLogicApp.id}/triggers/When_a_resource_event_occurs', '2016-06-01').value
        }
      }
      filter: {
        includedEventTypes: [
          'Microsoft.Resources.ResourceWriteSuccess'
        ]

        advancedFilters: [
          {
            operatorType: 'StringContains'
            key: 'data.resourceUri'
            values: [
              'providers/Microsoft.HybridCompute/machines'
            ]
          }
          {
            operatorType: 'StringIn'
            key: 'data.operationName'
            values: [
              'Microsoft.HybridCompute/machines/write'
            ]
          }
        ]
      }
    }
  }
]

var azureConnectedMachineResourceAdminRoleId = 'cd570a14-e51a-42ad-bac8-bafd67325302'
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, webhookLogicApp.id, azureConnectedMachineResourceAdminRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      azureConnectedMachineResourceAdminRoleId
    )
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
