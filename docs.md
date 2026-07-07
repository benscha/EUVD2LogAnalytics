# Technical Reference

## EUVD API usage

Base URL: `https://euvdservices.enisa.europa.eu/api`. No authentication required.

Endpoint used: `GET /search`, called twice per run:

| Call | Query parameters | Purpose |
|---|---|---|
| All new vulnerabilities | `fromDate`, `toDate`, `page`, `size=100` | Every vulnerability published in the last day |
| Exploited vulnerabilities | `fromDate`, `toDate`, `exploited=true`, `page`, `size=100` | Subset of the above known to be actively exploited |

Both calls page through results (up to 20 pages / 2,000 records per run as a safety
bound) until a page returns fewer than `size` items.

## Response field mapping

| EUVD API field | `EUVD_CL` column | Notes |
|---|---|---|
| `id` | `EUVDId` | e.g. `EUVD-2025-13580` |
| `description` | `Description` | |
| `datePublished` | `PublishedDate` | |
| `dateUpdated` | `UpdatedDate` | |
| `baseScore` | `CVSSScore` | real |
| `baseScoreVersion` | `CVSSVersion` | e.g. `3.1` |
| `epss` | `EPSS` | real, 0.0-1.0 |
| `enisaIdVendor[0].vendor.name` | `Vendor` | first vendor name when present |
| `enisaIdProduct[0].product.name` | `Product` | first product name when present |
| `aliases` | `Aliases` | newline-separated in the source |
| `references` | `References` | newline-separated in the source |
| n/a (derived) | `Exploited` | `true` if the id also appears in the `exploited=true` result set for the same window |
| n/a (generated) | `TimeGenerated` | set to the ingestion timestamp |

## Data model

`EUVD_CL` custom table columns and types (declared explicitly in `modules/tables.bicep`,
not auto-created by a legacy ingestion API, so no `_s`/`_d`/`_b` suffixes apply):

```
TimeGenerated   datetime
EUVDId          string
Description     string
PublishedDate   datetime
UpdatedDate     datetime
CVSSScore       real
CVSSVersion     string
EPSS            real
Vendor          string
Product         string
Aliases         string
References      string
Exploited       boolean
```

Retention: 365 days (workspace-level).

## RBAC

| Role | Scope | Held by | Why |
|---|---|---|---|
| Monitoring Contributor | Resource group | `mi-euvd-prod` | Required by the project specification |
| Log Analytics Contributor | Resource group | `mi-euvd-prod` | Required by the project specification |
| Monitoring Metrics Publisher | Data Collection Rule (`dcr-euvd-prod`) | `mi-euvd-prod` | Required by the Logs Ingestion API — the only way to write data without a shared workspace key |

No other principals are granted access. No secrets, certificates, shared keys,
connection strings, or local authentication are used anywhere in this solution.

## Ingestion path

Logic App → HTTP POST (managed identity, audience `https://monitor.azure.com`) →
Data Collection Endpoint → Data Collection Rule (stream `Custom-EUVD_CL`) →
Log Analytics workspace table `EUVD_CL`.

This replaces the legacy Azure Log Analytics Data Collector API/connector, which
requires a shared workspace key and was therefore not an option under this project's
"no secrets" constraint.
