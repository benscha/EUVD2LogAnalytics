# EUVD to Microsoft Sentinel – Vollständiger Projektbeschrieb

# Projektname

EUVD to Microsoft Sentinel Vulnerability Intelligence Platform

---

# Projektübersicht

Dieses Projekt implementiert eine vollständig Azure-native, serverlose und produktionsreife Lösung zur automatisierten Integration der European Union Vulnerability Database (EUVD) in Microsoft Sentinel.

Die Plattform ruft täglich aktuelle Schwachstelleninformationen direkt über die öffentliche EUVD API ab und speichert diese in einem Azure Log Analytics Workspace. Die Daten stehen anschließend in Microsoft Sentinel für Hunting, Analytics Rules, Workbooks, Dashboards und Incident Management zur Verfügung.

Die Lösung wird vollständig über Infrastructure as Code (Bicep) bereitgestellt und verwendet keine Secrets, Zertifikate oder andere statische Zugangsdaten.

Die Architektur folgt den Prinzipien:

- Zero Trust
- Least Privilege
- Cloud Native Design
- Infrastructure as Code
- Secure by Default
- Cost Optimized
- Serverless First

Die EUVD API ist öffentlich verfügbar und benötigt keine Authentifizierung. Alle Endpunkte werden über HTTP GET angesprochen. [1](https://euvd.enisa.europa.eu/apidoc)[2](https://rud.is/euvd-api/)

---

# Projektziele

## Hauptziele

- Automatische tägliche Erfassung von Schwachstellendaten aus der EUVD
- Aufbereitung und Normalisierung der Daten
- Speicherung in einem Azure Log Analytics Workspace
- Nutzung der Daten in Microsoft Sentinel
- Überwachung des gesamten Datenflusses
- Automatische Fehlererkennung
- Automatische Benachrichtigung bei Fehlern
- Vollständige Bereitstellung per Bicep
- Kein Einsatz von Secrets oder Zertifikaten

---

# Anwendungsfälle

## Threat Intelligence

Security Analysten können aktuelle EUVD Vulnerabilities innerhalb von Sentinel durchsuchen und analysieren.

## Threat Hunting

KQL Queries können genutzt werden um:

- Kritische Schwachstellen
- Neu veröffentlichte Schwachstellen
- Aktiv ausgenutzte Schwachstellen
- Herstellerbezogene Risiken

auszuwerten.

## Security Monitoring

Automatische Erkennung von:

- Kritischen CVEs
- Exploited Vulnerabilities
- Hoch priorisierten Schwachstellen

---

# Zielarchitektur

```text
┌─────────────────────────────┐
│ European Union Vulnerability│
│ Database (EUVD)             │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Azure Logic App             │
│ Consumption Plan            │
│ Daily Trigger               │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Data Transformation         │
│ JSON Parsing                │
│ Data Normalization          │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Azure Monitor               │
│ Logs Ingestion              │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Log Analytics Workspace     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Microsoft Sentinel          │
│ Analytics Rules             │
│ Workbooks                   │
│ Hunting                     │
│ Incidents                   │
└─────────────────────────────┘
```

---

# Azure Region

Die gesamte Lösung wird in folgender Region bereitgestellt:

```text
Switzerland North
```

---

# Komponenten

## Resource Group

```text
rg-euvd-prod
```

Verantwortlich für:

- Zentrale Verwaltung aller Ressourcen
- Lifecycle Management
- Kostenkontrolle

---

## Logic App

```text
la-euvd-prod
```

Typ:

```text
Consumption
```

Aufgaben:

- Täglicher Trigger
- Abruf der EUVD API
- Fehlerbehandlung
- Datennormalisierung
- Übergabe an Log Analytics

Gründe für Consumption:

- Niedrige Kosten
- Keine Infrastruktur
- Vollständig Serverless

---

## Managed Identity

```text
mi-euvd-prod
```

Verwendung:

- Authentifizierung gegenüber Azure Ressourcen
- RBAC-basierte Berechtigungen

Es dürfen keine Secrets oder Zertifikate verwendet werden.

---

## Log Analytics Workspace

```text
law-euvd-prod
```

Aufgaben:

- Speicherung der Schwachstellendaten
- Analyse per KQL
- Datengrundlage für Sentinel

Retention:

```text
365 Tage
```

---

## Microsoft Sentinel

Aktivierung auf:

```text
law-euvd-prod
```

Verwendung:

- Incidents
- Hunting
- Dashboards
- Workbooks
- Analytics Rules

---

## Application Insights

```text
appi-euvd-prod
```

Verwendung:

- Monitoring
- Fehlererkennung
- Tracing
- Performanceanalyse

---

## Azure Monitor

Verwendung:

- Alert Regeln
- Metriken
- Überwachung

---

## Action Group

```text
ag-euvd-prod
```

Verwendung:

- E-Mail Benachrichtigungen
- Automatische Alarmierung

---

# Datenquelle

## EUVD API

Basis URL:

```text
https://euvdservices.enisa.europa.eu
```

Mögliche Endpunkte:

### Neue Vulnerabilities

```text
/api/lastvulnerabilities
```

### Kritische Vulnerabilities

```text
/api/criticalvulnerabilities
```

### Exploitierte Vulnerabilities

```text
/api/exploitedvulnerabilities
```

### Suchfunktion

```text
/api/search
```

Die API benötigt keine Authentifizierung. [1](https://euvd.enisa.europa.eu/apidoc)[2](https://rud.is/euvd-api/)

---

# Trigger-Konfiguration

Intervall:

```text
1 Tag
```

Ausführungszeit:

```text
01:00 UTC
```

Logic App Trigger:

```text
Recurrence
```

---

# Datenmodell

## Custom Table

```text
EUVD_CL
```

---

## Felder

```json
{
  "TimeGenerated": "",
  "EUVDId": "",
  "Description": "",
  "PublishedDate": "",
  "UpdatedDate": "",
  "CVSSScore": "",
  "CVSSVersion": "",
  "EPSS": "",
  "Vendor": "",
  "Product": "",
  "Aliases": "",
  "References": "",
  "Exploited": ""
}
```

---

# Datenverarbeitung

## Schritt 1

Daily Trigger startet Logic App.

---

## Schritt 2

HTTP GET gegen:

```text
https://euvdservices.enisa.europa.eu/api/search
```

---

## Schritt 3

JSON Parsing.

---

## Schritt 4

Normalisierung:

- Datumswerte
- Arrays
- Hersteller
- Produkte

---

## Schritt 5

Transformation in das Zielschema.

---

## Schritt 6

Schreiben in den Log Analytics Workspace.

---

## Schritt 7

Verifikation der erfolgreichen Aufnahme.

---

# Berechtigungen

## Managed Identity

Erforderliche Rollen:

```text
Monitoring Contributor
Log Analytics Contributor
```

Nur minimale Berechtigungen vergeben.

---

# Sentinel Analytics Rules

## Regel 1

### Kritische Vulnerabilities

Bedingung:

```text
CVSS >= 9
```

---

## Regel 2

### Exploitierte Vulnerabilities

Bedingung:

```text
Exploited = true
```

---

## Regel 3

### Neue kritische Vulnerabilities

Bedingung:

```text
CVSS >= 9
AND
Published within last 24h
```

---

# Monitoring

## Logic App

Überwachung:

- Erfolgreiche Ausführungen
- Fehlgeschlagene Ausführungen
- Laufzeiten

---

## Application Insights

Überwachung:

- Exceptions
- Traces
- Failures
- Dependency Errors

---

## Azure Monitor

Überwachung:

- Metriken
- Alerts
- Verfügbarkeit

---

# Fehlerbehandlung

## Retry Policy

Modell:

```text
Exponential Backoff
```

Anzahl:

```text
3 Versuche
```

---

## Fehlerworkflow

Bei Fehlern:

1. Fehler erfassen
2. Application Insights schreiben
3. Azure Monitor Alert erzeugen
4. Action Group auslösen
5. E-Mail senden

---

# Benachrichtigungen

## Kanal

```text
E-Mail
```

---

## Auslöser

- Logic App Failure
- API Error
- Parsing Error
- Ingestion Error

---

# Security Anforderungen

## Erlaubt

```text
Managed Identity
Azure RBAC
Azure Monitor
Azure AD / Entra ID
```

---

## Verboten

```text
Client Secrets
Certificates
Shared Keys
Hardcoded Credentials
Connection Strings
Local Authentication
```

---

# Naming Convention

```text
rg-euvd-prod
law-euvd-prod
appi-euvd-prod
la-euvd-prod
mi-euvd-prod
ag-euvd-prod
```

---

# Tags

Alle Ressourcen erhalten:

```json
{
  "Application": "EUVD",
  "Environment": "Production",
  "Owner": "Security",
  "ManagedBy": "Bicep"
}
```

---

# Infrastruktur als Code

Bereitstellung ausschließlich mit:

```text
Bicep
```

---

# Repositorystruktur

```text
EUVD-Sentinel
│
├── main.bicep
│
├── modules
│   ├── workspace.bicep
│   ├── sentinel.bicep
│   ├── logicapp.bicep
│   ├── appinsights.bicep
│   ├── alerts.bicep
│   ├── monitor.bicep
│   ├── identity.bicep
│   ├── roles.bicep
│   └── tables.bicep
│
├── parameters
│   └── prod.bicepparam
│
├── docs.md
├── README.md
├── architecture.md
├── deployment-guide.md
├── operations-guide.md
└── troubleshooting-guide.md
```

---

# Deployment

## Resource Group

```bash
az group create \
  --name rg-euvd-prod \
  --location switzerlandnorth
```

## Bicep

```bash
az deployment group create \
  --resource-group rg-euvd-prod \
  --template-file main.bicep \
  --parameters parameters/prod.bicepparam
```

---

# Validierung

Prüfen:

- Logic App vorhanden
- Log Analytics Workspace vorhanden
- Sentinel aktiviert
- Application Insights aktiv
- Alerts vorhanden
- Action Group vorhanden
- Managed Identity vorhanden

---

# Beispiel KQL

## Kritische Schwachstellen

```kusto
EUVD_CL
| where CVSSScore_d >= 9
```

## Exploitierte Schwachstellen

```kusto
EUVD_CL
| where Exploited_s == "true"
```

## Herstellerübersicht

```kusto
EUVD_CL
| summarize Count=count() by Vendor_s
| order by Count desc
```

---

# Disaster Recovery

Die gesamte Umgebung muss jederzeit reproduzierbar sein.

Wiederherstellung erfolgt ausschließlich durch:

```bash
az deployment group create \
 --resource-group rg-euvd-prod \
 --template-file main.bicep
```

Keine manuellen Konfigurationen dürfen erforderlich sein.

---

# Abnahmekriterien

Die Lösung gilt als erfolgreich umgesetzt, wenn:

- Bicep Deployment erfolgreich durchläuft
- Alle Ressourcen automatisch erstellt werden
- Logic App täglich ausgeführt wird
- EUVD Daten erfolgreich abgerufen werden
- Daten im Log Analytics Workspace landen
- Daten in Sentinel sichtbar sind
- KQL Abfragen funktionieren
- Monitoring aktiv ist
- Alerts ausgelöst werden können
- Dokumentation vollständig vorhanden ist
- Keine Secrets verwendet werden
- Managed Identity für Azure-Zugriffe eingesetzt wird
- Die Lösung vollständig reproduzierbar ist

# Ende des Projektbeschriebs