# Architecture

## Data flow

```text
┌─────────────────────────────┐
│ European Union Vulnerability│
│ Database (EUVD) public API  │
└──────────────┬──────────────┘
               │ HTTP GET (no authentication)
               ▼
┌─────────────────────────────┐
│ Azure Logic App              │
│ Consumption plan              │
│ Daily recurrence (01:00 UTC) │
│ User-assigned managed identity│
└──────────────┬──────────────┘
               │ Parse, normalize, transform
               ▼
┌─────────────────────────────┐
│ Data Collection Endpoint (DCE)│
│ Data Collection Rule (DCR)    │
│ Logs Ingestion API             │
│ (managed identity auth only)  │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│ Log Analytics Workspace       │
│ Custom table: EUVD_CL          │
│ Retention: 365 days            │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│ Microsoft Sentinel             │
│ Analytics rules, hunting,      │
│ workbooks, incidents            │
└─────────────────────────────┘
```

Monitoring and alerting run alongside the main flow: a diagnostic setting on the Logic
App streams run history to the workspace, and an Azure Monitor metric alert watches the
Logic App's `RunsFailed` metric, notifying the Action Group by email on any failure
(EUVD API error, parsing error, or ingestion error all surface as a failed run).

## Components

| Resource | Name | Purpose |
|---|---|---|
| Resource Group | `rg-euvd-prod` | Contains and manages all resources |
| User-Assigned Managed Identity | `mi-euvd-prod` | Sole authentication mechanism for the Logic App |
| Log Analytics Workspace | `law-euvd-prod` | Stores EUVD data, backs Sentinel, 365-day retention |
| Custom Table | `EUVD_CL` | Typed schema for vulnerability records |
| Data Collection Endpoint | `dce-euvd-prod` | Ingestion endpoint for the Logs Ingestion API |
| Data Collection Rule | `dcr-euvd-prod` | Routes the `Custom-EUVD_CL` stream into the table |
| Logic App (Consumption) | `la-euvd-prod` | Daily fetch, transform, and ingest workflow |
| Application Insights | `appi-euvd-prod` | Workspace-based monitoring, no separate key |
| Action Group | `ag-euvd-prod` | Email notification on pipeline failure |
| Metric Alert | `alert-euvd-logicapp-failure` | Detects failed Logic App runs |
| Microsoft Sentinel | on `law-euvd-prod` | Analytics rules, hunting, incidents, workbooks |

## Why the Logs Ingestion API instead of the Data Collector API

The classic Logic App connector for Log Analytics ("Azure Log Analytics Data Collector")
authenticates with the workspace's shared key — a static secret. Since this project
forbids all secrets and shared keys, the pipeline instead uses the modern **Logs
Ingestion API**: the Logic App's HTTP action authenticates with its managed identity
(a Microsoft Entra ID token), and the Data Collection Rule grants routing into the
custom table. This is the only ingestion path that satisfies both "get data into Log
Analytics" and "no secrets, ever."

## Region and naming

All resources are deployed to **Switzerland North** and follow the naming convention
`<prefix>-euvd-prod` (e.g. `rg-`, `law-`, `appi-`, `la-`, `mi-`, `ag-`), with the
`dce-`/`dcr-` prefixes added for the two Logs Ingestion resources that support the table.
Every resource carries the tags `Application=EUVD`, `Environment=Production`,
`Owner=Security`, `ManagedBy=Bicep`.
