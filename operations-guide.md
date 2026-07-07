# Operations Guide

## Daily run

The `la-euvd-prod` Logic App runs once per day at 01:00 UTC. Each run:

1. Computes a one-day window (`fromDate`/`toDate`).
2. Pages through `GET /api/search` on the EUVD API for vulnerabilities published in
   that window.
3. Pages through the same endpoint with `exploited=true` to identify which of those are
   actively exploited.
4. Transforms each vulnerability into the `EUVD_CL` schema.
5. Sends the batch to Log Analytics via the Logs Ingestion API, authenticated with the
   Logic App's managed identity.
6. Marks the run as `Failed` if any step failed, which is what the metric alert detects.

Check run history under the Logic App's **Overview → Runs history** blade, or query the
diagnostic logs sent to the workspace.

## KQL samples

Critical vulnerabilities:

```kusto
EUVD_CL
| where CVSSScore >= 9
```

Exploited vulnerabilities:

```kusto
EUVD_CL
| where Exploited == true
```

Newly published critical vulnerabilities (last 24 hours):

```kusto
EUVD_CL
| where CVSSScore >= 9 and PublishedDate >= ago(24h)
```

Vendor overview:

```kusto
EUVD_CL
| summarize Count = count() by Vendor
| order by Count desc
```

> Note: these columns are declared with real types (`real`, `boolean`, `datetime`) in
> the custom table schema, so no `_d`/`_s`/`_b` suffixes are needed — unlike tables
> auto-created by the legacy Data Collector API.

## Analytics rules

Three scheduled analytics rules run hourly against a 24-hour lookback window:

| Rule | Condition | Severity |
|---|---|---|
| EUVD - Critical Vulnerabilities | `CVSSScore >= 9` | High |
| EUVD - Exploited Vulnerabilities | `Exploited == true` | High |
| EUVD - Newly Published Critical Vulnerabilities | `CVSSScore >= 9` and published within 24h | High |

Each rule creates a Sentinel incident when it fires.

## Monitoring

- **Logic App run history** — successful/failed runs and durations.
- **Diagnostic settings** — `la-euvd-prod` streams all logs and metrics to
  `law-euvd-prod`.
- **Metric alert** `alert-euvd-logicapp-failure` — fires on any failed run in a rolling
  24-hour window and notifies `ag-euvd-prod` by email.

## Retention

The workspace retains data for 365 days, per the project requirement.
