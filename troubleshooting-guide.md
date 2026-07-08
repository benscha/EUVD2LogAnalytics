# Troubleshooting Guide

## Logic App run fails with a 403 on the "Send_To_Logs_Ingestion_API" action

**Cause:** the managed identity's `Monitoring Metrics Publisher` role assignment on the
Data Collection Rule has not propagated yet. Azure RBAC role assignments can take up to
~30 minutes to become effective, and the Logs Ingestion API enforces this role strictly.

**Fix:** wait and re-run the trigger manually. This is expected shortly after the first
deployment and should not recur afterward.

## Logic App run fails on "Get_Vulnerabilities_Page" or "Get_Exploited_Page"

**Cause:** the public EUVD API is unreachable or returned a non-2xx status.

**Fix:** check the action's output in the run history for the HTTP status code and
response body. The EUVD API requires no authentication, so failures here are almost
always upstream availability issues or a change in the API's response shape. Retry the
trigger manually; if it persists, verify the API is reachable from
`https://euvdservices.enisa.europa.eu/api/search` directly.

## No data appears in `EUVD_CL` after a successful run

**Cause:** either no vulnerabilities were published in the last 24 hours (expected on
quiet days), or the batch send silently returned fewer records than expected due to a
schema mismatch between the Logic App's transformed object and the Data Collection
Rule's stream declaration.

**Fix:** confirm the run's `Send_To_Logs_Ingestion_API` action succeeded and check the
`transformedItems` count in the "Compose" outputs. Also confirm the DCR's
`streamDeclarations` columns still match the `EUVD_CL` table schema exactly (both are
defined in `modules/tables.bicep`, so they should never drift — but manual portal edits
to either would break this).

## The `Until` loop hits its iteration limit (20 pages / 2,000 records)

**Cause:** an unusually large number of vulnerabilities were published in a single day.

**Fix:** the Logic App now uses higher page limits and sends data to the Logs Ingestion
API in smaller batches, which is suitable for large initial backfills (for example,
365 days). If you still hit limits, increase the `count` in the `limit` property of
`Until_AllVulnerabilities` / `Until_ExploitedVulnerabilities` in
`modules/logicapp.bicep`.

## Deployment fails with "alertEmail" validation error

**Cause:** `main.bicep` has an empty or invalid `alertEmail` default, or a parameter
override supplied an empty value.

**Fix:** set `alertEmail` in `main.bicep` to a real mailbox before deploying — see
[deployment-guide.md](deployment-guide.md) Step 2.

## Deployment fails with `Microsoft.Authorization/roleAssignments/write`

**Cause:** the deploying user does not have permission to create Azure role assignments
at the resource group or Data Collection Rule scope. `Contributor` alone is not enough
for this action.

**Fix:** run the deployment with an account that has `Owner` or `User Access
Administrator` on the target resource group/subscription, or ask an administrator to
grant those permissions temporarily for the deployment.

By default, `deployRoleAssignments` is `true`, so a redeploy will create or repair the
required assignments. Set it to `false` only when you intentionally want to skip RBAC
changes.

## Sentinel analytics rules show no results even though data is landing

**Cause:** analytics rules query on a schedule (hourly, 24h lookback); they will not
show results until their first scheduled evaluation after data lands.

**Fix:** wait for the next hourly evaluation, or run the rule manually from the Sentinel
portal ("Run query now").

## Sentinel analytics rule deployment fails because the workspace cannot be found

**Cause:** Microsoft Sentinel can briefly reject analytics rule creation while workspace
onboarding is still becoming available to the SecurityInsights provider.

**Fix:** deploy the base infrastructure first with `deploySentinelAnalyticsRules=false`.
After the workspace is visible in Sentinel, re-run the deployment with
`deploySentinelAnalyticsRules=true`.
