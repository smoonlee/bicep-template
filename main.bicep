targetScope = 'subscription'

param deployGuid string
param deployedBy string
param subscriptionId string
param location string
param locationShortCode string
param environmentType string
param customerName string
param projectName string

param tags object = {
  Environment: environmentType
  deployedBy: deployedBy
  LastUpdatedOn: utcNow('d')
}

// Variables
param resourceGroupName string = 'iac-rg-${customerName}-${projectName}-${environmentType}-${locationShortCode}'
param StaticWebAppName string = 'iac-static-web-${customerName}-${projectName}-${environmentType}-${locationShortCode}'

//
// NO HARD CODED VALUES UNDER HERE!
//

module createResourceGroup 'br/public:avm/res/resources/resource-group:0.3.0' = {
  name: 'createResourceGroup-${deployGuid}'
  scope: subscription(subscriptionId)
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

module createStaticWebApp 'br/public:avm/res/web/static-site:0.4.0' = {
  name: 'createStaticWebApp-${deployGuid}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: StaticWebAppName
    location: location
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}
