# Deployment Guide

## Prerequisites

- Azure CLI (`az`) installed and logged in (`az login`).
- Access to an Azure subscription with permissions to create resource groups,
  role assignments (`Owner` or `Contributor` + `User Access Administrator`), Log
  Analytics workspaces, Logic Apps, and Microsoft Sentinel.
- No secrets, API keys, or certificates need to be prepared in advance — this solution
  does not use any.

## Step 1 — Create the resource group

```bash
az group create \
  --name rg-euvd-prod \
  --location switzerlandnorth
```

## Step 2 — Review the alert email

The notification mailbox is defined in `main.bicep` as the `alertEmail` parameter
default:

```bicep
param alertEmail string = 'benjamin.zulliger@fhnw.ch'
```

Change this value in `main.bicep` if a different mailbox should receive pipeline
failure notifications.

## Step 3 — (Optional) Validate the template

```bash
az bicep build --file main.bicep

az deployment group validate \
  --resource-group rg-euvd-prod \
  --template-file main.bicep \
  --parameters parameters/prod.bicepparam
```

## Step 4 — Deploy

By default, the deployment creates and repairs the managed identity role assignments.
The deploying account therefore needs `Owner` or `User Access Administrator` on the
target resource group or subscription:

```bash
az deployment group create \
  --resource-group rg-euvd-prod \
  --template-file main.bicep \
  --parameters parameters/prod.bicepparam
```

If the deploying account cannot create role assignments, set
`deployRoleAssignments=false`. The Logic App will not be able to ingest data until the
assignments are created by an account with sufficient permissions.

Sentinel analytics rules are skipped by default during the first deployment to avoid
workspace onboarding timing issues. After the workspace is visible in Sentinel, deploy
the rules with:

```bash
az deployment group create \
  --resource-group rg-euvd-prod \
  --template-file main.bicep \
  --parameters parameters/prod.bicepparam deploySentinelAnalyticsRules=true
```

The deployment creates every resource described in [architecture.md](architecture.md),
including role assignments by default and Sentinel analytics rules when enabled. New
role assignments can take up to ~30 minutes to propagate — see
[troubleshooting-guide.md](troubleshooting-guide.md) if the first Logic App run fails
with an authorization error.

## Step 5 — Verify

After the deployment completes (and after allowing time for role propagation), check:

- [ ] `rg-euvd-prod` contains all expected resources
- [ ] `law-euvd-prod` exists and has Microsoft Sentinel enabled
- [ ] `EUVD_CL` table is visible under the workspace's custom tables
- [ ] `la-euvd-prod` exists and is enabled
- [ ] `ag-euvd-prod` exists with the correct email receiver
- [ ] `alert-euvd-logicapp-failure` exists and targets the Logic App
- [ ] `mi-euvd-prod` exists and is assigned to the Logic App

To trigger the pipeline immediately instead of waiting for the 01:00 UTC schedule, run
the workflow manually from the Azure Portal (Logic App → Run Trigger) or with:

```bash
az rest --method post \
  --uri "$(az logic workflow show -g rg-euvd-prod -n la-euvd-prod --query id -o tsv)/triggers/Daily_Recurrence/run?api-version=2019-05-01"
```

Then confirm data landed:

```kusto
EUVD_CL
| take 10
```

## Disaster recovery

The environment is fully reproducible. To rebuild it from scratch (or repair drift),
simply re-run:

```bash
az deployment group create \
  --resource-group rg-euvd-prod \
  --template-file main.bicep \
  --parameters parameters/prod.bicepparam
```

No manual configuration steps are ever required.
