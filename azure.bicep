
{
  "$schema": https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#,
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "bicep",
      "version": "0.25.53.49325",
      "templateHash": "6587483520975479408"
    }
  },
  "parameters": {
    "adminUsername": {
      "type": "string",
      "metadata": {
        "description": "Admin username"
      }
    },
    "adminPassword": {
      "type": "securestring",
      "metadata": {
        "description": "Admin password"
      }
    },
    "vmNamePrefix": {
      "type": "string",
      "defaultValue": "BackendVM",
      "metadata": {
        "description": "Prefix to use for VM names"
      }
    },
    "location": {
      "type": "string",
      "defaultValue": "[resourceGroup().location]",
      "metadata": {
        "description": "Location for all resources."
      }
    },
    "vmSize": {
      "type": "string",
      "defaultValue": "Standard_B1s",
      "metadata": {
        "description": "Size of the virtual machines"
      }
    }
  },
  "variables": {
    "availabilitySetName": "AvSet",
    "storageAccountType": "Standard_LRS",
    "storageAccountName": "[uniqueString(resourceGroup().id)]",
    "virtualNetworkName": "vNet",
    "subnetName": "backendSubnet",
    "loadBalancerName": "ilb",
    "networkInterfaceName": "nic",
    "subnetRef": "[resourceId('Microsoft.Network/virtualNetworks/subnets', variables('virtualNetworkName'), variables('subnetName'))]",
    "numberOfInstances": 2
  },
  "resources": [
    {
      "type": "Microsoft.Storage/storageAccounts",
      "apiVersion": "2023-01-01",
      "name": "[variables('storageAccountName')]",
      "location": "[parameters('location')]",
      "sku": {
        "name": "[variables('storageAccountType')]"
      },
      "kind": "StorageV2"
    },
    {
      "type": "Microsoft.Compute/availabilitySets",
      "apiVersion": "2023-09-01",
      "name": "[variables('availabilitySetName')]",
      "location": "[parameters('location')]",
      "sku": {
        "name": "Aligned"
      },
      "properties": {
        "platformUpdateDomainCount": 2,
        "platformFaultDomainCount": 2
      }
    },
    {
      "type": "Microsoft.Network/virtualNetworks",
      "apiVersion": "2023-09-01",
      "name": "[variables('virtualNetworkName')]",
      "location": "[parameters('location')]",
      "properties": {
        "addressSpace": {
          "addressPrefixes": [
            "10.0.0.0/16"
          ]
        },
        "subnets": [
          {
            "name": "[variables('subnetName')]",
            "properties": {
              "addressPrefix": "10.0.2.0/24"
            }
          }
        ]
      }
    },
    {
      "copy": {
        "name": "networkInterface",
        "count": "[length(range(0, variables('numberOfInstances')))]"
      },
      "type": "Microsoft.Network/networkInterfaces",
      "apiVersion": "2023-09-01",
      "name": "[format('{0}{1}', variables('networkInterfaceName'), range(0, variables('numberOfInstances'))[copyIndex()])]",
      "location": "[parameters('location')]",
      "properties": {
        "ipConfigurations": [
          {
            "name": "ipconfig1",
            "properties": {
              "privateIPAllocationMethod": "Dynamic",
              "subnet": {
                "id": "[variables('subnetRef')]"
              },
              "loadBalancerBackendAddressPools": [
                {
                  "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', variables('loadBalancerName'), 'BackendPool1')]"
                }
              ]
            }
          }
        ]
      },
      "dependsOn": [
        "[resourceId('Microsoft.Network/loadBalancers', variables('loadBalancerName'))]",
        "[resourceId('Microsoft.Network/virtualNetworks', variables('virtualNetworkName'))]"
      ]
    },
    {
      "type": "Microsoft.Network/loadBalancers",
      "apiVersion": "2023-09-01",
      "name": "[variables('loadBalancerName')]",
      "location": "[parameters('location')]",
      "sku": {
        "name": "Standard"
      },
      "properties": {
        "frontendIPConfigurations": [
          {
            "properties": {
              "subnet": {
                "id": "[variables('subnetRef')]"
              },
              "privateIPAddress": "10.0.2.6",
              "privateIPAllocationMethod": "Static"
            },
            "name": "LoadBalancerFrontend"
          }
        ],
        "backendAddressPools": [
          {
            "name": "BackendPool1"
          }
        ],
        "loadBalancingRules": [
          {
            "properties": {
              "frontendIPConfiguration": {
                "id": "[resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', variables('loadBalancerName'), 'LoadBalancerFrontend')]"
              },
              "backendAddressPool": {
                "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', variables('loadBalancerName'), 'BackendPool1')]"
              },
              "probe": {
                "id": "[resourceId('Microsoft.Network/loadBalancers/probes', variables('loadBalancerName'), 'lbprobe')]"
              },
              "protocol": "Tcp",
              "frontendPort": 80,
              "backendPort": 80,
              "idleTimeoutInMinutes": 15
            },
            "name": "lbrule"
          }
        ],
        "probes": [
          {
            "properties": {
              "protocol": "Tcp",
              "port": 80,
              "intervalInSeconds": 15,
              "numberOfProbes": 2
            },
            "name": "lbprobe"
          }
        ]
      },
      "dependsOn": [
        "[resourceId('Microsoft.Network/virtualNetworks', variables('virtualNetworkName'))]"
      ]
    },
    {
      "copy": {
        "name": "vm",
        "count": "[length(range(0, variables('numberOfInstances')))]"
      },
      "type": "Microsoft.Compute/virtualMachines",
      "apiVersion": "2023-09-01",
      "name": "[format('{0}{1}', parameters('vmNamePrefix'), range(0, variables('numberOfInstances'))[copyIndex()])]",
      "location": "[parameters('location')]",
      "properties": {
        "availabilitySet": {
          "id": "[resourceId('Microsoft.Compute/availabilitySets', variables('availabilitySetName'))]"
        },
        "hardwareProfile": {
          "vmSize": "[parameters('vmSize')]"
        },
        "osProfile": {
          "computerName": "[format('{0}{1}', parameters('vmNamePrefix'), range(0, variables('numberOfInstances'))[copyIndex()])]",
          "adminUsername": "[parameters('adminUsername')]",
          "adminPassword": "[parameters('adminPassword')]"
        },
        "storageProfile": {
          "imageReference": {
            "publisher": "MicrosoftWindowsServer",
            "offer": "WindowsServer",
            "sku": "2019-Datacenter",
            "version": "latest"
          },
          "osDisk": {
            "createOption": "FromImage"
          }
        },
        "networkProfile": {
          "networkInterfaces": [
            {
              "id": "[resourceId('Microsoft.Network/networkInterfaces', format('{0}{1}', variables('networkInterfaceName'), range(0, variables('numberOfInstances'))[range(0, variables('numberOfInstances'))[copyIndex()]]))]"
            }
          ]
        },
        "diagnosticsProfile": {
          "bootDiagnostics": {
            "enabled": true,
            "storageUri": "[reference(resourceId('Microsoft.Storage/storageAccounts', variables('storageAccountName')), '2023-01-01').primaryEndpoints.blob]"
          }
        }
      },
      "dependsOn": [
        "[resourceId('Microsoft.Compute/availabilitySets', variables('availabilitySetName'))]",
        "[resourceId('Microsoft.Network/networkInterfaces', format('{0}{1}', variables('networkInterfaceName'), range(0, variables('numberOfInstances'))[range(0, variables('numberOfInstances'))[copyIndex()]]))]",
        "[resourceId('Microsoft.Storage/storageAccounts', variables('storageAccountName'))]"
      ]
    }
  ],
  "outputs": {
    "location": {
      "type": "string",
      "value": "[parameters('location')]"
    },
    "name": {
      "type": "string",
      "value": "[variables('loadBalancerName')]"
    },
    "resourceGroupName": {
      "type": "string",
      "value": "[resourceGroup().name]"
    },
    "resourceId": {
      "type": "string",
      "value": "[resourceId('Microsoft.Network/loadBalancers', variables('loadBalancerName'))]"
    }
  }
}
