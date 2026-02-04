# Azure Arc automation Logic Apps

This repository contains multiple Logic Apps aimed to help with management of onboarded Azure Arc machines.

## Scheduled

1. **Ensure Software Assurance benefits are enabled on eligible Windows Server machines** - Azure resource graph query for qualifying machines and enables the benefits
2. **Ensure Software Assurance benefits are enabled on eligble machines with SQL Server installed** - Azure resource graph query for qualifying machines and enables the benefits

## Triggered by Event Grid

1. **Enable Windows Server benefits as soon as machine is onboraded to Azure Arc** - Triggered by Event Grid system topic that subscribes to Resource Graphs events and listens for new Arc machine objects. 

## Deployment

Main Bicep script is `main.bicep` with parameters file `main.bicepparam` that needs to be updated at least with list of Azure subscription IDs where Event Grid should listen to Azure resource manager events. 

## Azure CLI

1. Ensure you are logged in and the resource group exists (name: `arc`).
2. Run the deployment command from this folder:

```bash
az deployment group create --resource-group arc --template-file main.bicep --parameters main.bicepparam
```
