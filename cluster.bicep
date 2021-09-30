param sshKey string
param adminPassword string

resource aksCluster 'Microsoft.ContainerService/managedClusters@2021-05-01' = {
  name: 'aks-apparmor'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: 3
        vmSize: 'Standard_DS2_v2'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
      {
        name: 'user'
        mode: 'User'
        count: 3
        vmSize: 'Standard_DS2_v2'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        nodeTaints: [
          'WaitingForAppArmorProfiles=true:NoSchedule'
        ]
      }
    ]
    dnsPrefix: 'pahl-apparmor'
    linuxProfile: {
      adminUsername: 'azureuser'
      ssh: {
        publicKeys: [
          {
            keyData: sshKey
          }
        ]
      }
    }
    windowsProfile: {
      adminUsername: 'azureuser'
      adminPassword: adminPassword
    }
    enableRBAC: true
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      podCidr: '10.1.0.0/17'
      serviceCidr: '10.1.128.0/18'
      dnsServiceIP: '10.1.128.10'
      dockerBridgeCidr: '10.1.192.1/24'
      outboundType: 'loadBalancer'
      loadBalancerSku: 'standard'
    }
    aadProfile: {
      managed: true
    }
    servicePrincipalProfile: {
      clientId: 'msi'
    }
  }
  sku: {
    name: 'Basic'
    tier: 'Paid'
  }
}
