// Consumption Logic App that runs daily, pulls new vulnerabilities from the public
// EUVD API, normalizes them, and pushes them to Log Analytics via the Logs Ingestion
// API using managed identity authentication only (no API keys, no workspace keys).
param logicAppName string
param diagnosticSettingName string
param location string
param tags object
param identityId string
param workspaceId string
param logsIngestionEndpoint string
param dcrImmutableId string
param streamName string

@description('Base URL of the public EUVD API. No authentication is required by this API.')
param euvdApiBaseUrl string = 'https://euvdservices.enisa.europa.eu/api'

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        euvdApiBaseUrl: { type: 'string' }
        logsIngestionEndpoint: { type: 'string' }
        dcrImmutableId: { type: 'string' }
        streamName: { type: 'string' }
        managedIdentityResourceId: { type: 'string' }
      }
      triggers: {
        Daily_Recurrence: {
          type: 'Recurrence'
          recurrence: {
            frequency: 'Day'
            interval: 1
            timeZone: 'UTC'
            schedule: {
              hours: [
                '1'
              ]
              minutes: [
                0
              ]
            }
          }
        }
      }
      actions: {
        Initialize_FromDate: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'fromDate'
                type: 'string'
                value: '@{formatDateTime(addDays(utcNow(), -1), \'yyyy-MM-dd\')}'
              }
            ]
          }
          runAfter: {}
        }
        Initialize_ToDate: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'toDate'
                type: 'string'
                value: '@{formatDateTime(utcNow(), \'yyyy-MM-dd\')}'
              }
            ]
          }
          runAfter: {
            Initialize_FromDate: [
              'Succeeded'
            ]
          }
        }
        Initialize_AllItems: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'allItems'
                type: 'array'
                value: []
              }
            ]
          }
          runAfter: {
            Initialize_ToDate: [
              'Succeeded'
            ]
          }
        }
        Initialize_ExploitedIds: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'exploitedIds'
                type: 'array'
                value: []
              }
            ]
          }
          runAfter: {
            Initialize_AllItems: [
              'Succeeded'
            ]
          }
        }
        Initialize_TransformedItems: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'transformedItems'
                type: 'array'
                value: []
              }
            ]
          }
          runAfter: {
            Initialize_ExploitedIds: [
              'Succeeded'
            ]
          }
        }
        Initialize_CurrentPage: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'currentPage'
                type: 'integer'
                value: 0
              }
            ]
          }
          runAfter: {
            Initialize_TransformedItems: [
              'Succeeded'
            ]
          }
        }
        Initialize_HasMorePages: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'hasMorePages'
                type: 'boolean'
                value: true
              }
            ]
          }
          runAfter: {
            Initialize_CurrentPage: [
              'Succeeded'
            ]
          }
        }
        Initialize_ExploitedPage: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'exploitedPage'
                type: 'integer'
                value: 0
              }
            ]
          }
          runAfter: {
            Initialize_HasMorePages: [
              'Succeeded'
            ]
          }
        }
        Initialize_HasMoreExploitedPages: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'hasMoreExploitedPages'
                type: 'boolean'
                value: true
              }
            ]
          }
          runAfter: {
            Initialize_ExploitedPage: [
              'Succeeded'
            ]
          }
        }
        Initialize_BatchSize: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'batchSize'
                type: 'integer'
                value: 500
              }
            ]
          }
          runAfter: {
            Initialize_HasMoreExploitedPages: [
              'Succeeded'
            ]
          }
        }
        Initialize_BatchStart: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'batchStart'
                type: 'integer'
                value: 0
              }
            ]
          }
          runAfter: {
            Initialize_BatchSize: [
              'Succeeded'
            ]
          }
        }
        Initialize_HasMoreBatches: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'hasMoreBatches'
                type: 'boolean'
                value: false
              }
            ]
          }
          runAfter: {
            Initialize_BatchStart: [
              'Succeeded'
            ]
          }
        }
        Scope_Main: {
          type: 'Scope'
          runAfter: {
            Initialize_HasMoreBatches: [
              'Succeeded'
            ]
          }
          actions: {
            Until_AllVulnerabilities: {
              type: 'Until'
              expression: '@equals(variables(\'hasMorePages\'), false)'
              limit: {
                count: 500
                timeout: 'PT1H'
              }
              runAfter: {}
              actions: {
                Get_Vulnerabilities_Page: {
                  type: 'Http'
                  inputs: {
                    method: 'GET'
                    uri: '@{parameters(\'euvdApiBaseUrl\')}/search'
                    queries: {
                      fromDate: '@variables(\'fromDate\')'
                      toDate: '@variables(\'toDate\')'
                      page: '@string(variables(\'currentPage\'))'
                      size: '100'
                    }
                  }
                  runAfter: {}
                }
                For_each_Vulnerability_Page_Item: {
                  type: 'Foreach'
                  foreach: '@coalesce(body(\'Get_Vulnerabilities_Page\')?[\'items\'], createArray())'
                  operationOptions: 'Sequential'
                  actions: {
                    Append_AllItem: {
                      type: 'AppendToArrayVariable'
                      inputs: {
                        name: 'allItems'
                        value: '@items(\'For_each_Vulnerability_Page_Item\')'
                      }
                      runAfter: {}
                    }
                  }
                  runAfter: {
                    Get_Vulnerabilities_Page: [
                      'Succeeded'
                    ]
                  }
                }
                Set_HasMorePages: {
                  type: 'SetVariable'
                  inputs: {
                    name: 'hasMorePages'
                    value: '@equals(length(coalesce(body(\'Get_Vulnerabilities_Page\')?[\'items\'], createArray())), 100)'
                  }
                  runAfter: {
                    For_each_Vulnerability_Page_Item: [
                      'Succeeded'
                    ]
                  }
                }
                Increment_CurrentPage: {
                  type: 'IncrementVariable'
                  inputs: {
                    name: 'currentPage'
                    value: 1
                  }
                  runAfter: {
                    Set_HasMorePages: [
                      'Succeeded'
                    ]
                  }
                }
              }
            }
            Until_ExploitedVulnerabilities: {
              type: 'Until'
              expression: '@equals(variables(\'hasMoreExploitedPages\'), false)'
              limit: {
                count: 500
                timeout: 'PT1H'
              }
              runAfter: {}
              actions: {
                Get_Exploited_Page: {
                  type: 'Http'
                  inputs: {
                    method: 'GET'
                    uri: '@{parameters(\'euvdApiBaseUrl\')}/search'
                    queries: {
                      fromDate: '@variables(\'fromDate\')'
                      toDate: '@variables(\'toDate\')'
                      exploited: 'true'
                      page: '@string(variables(\'exploitedPage\'))'
                      size: '100'
                    }
                  }
                  runAfter: {}
                }
                For_each_Exploited_Page_Item: {
                  type: 'Foreach'
                  foreach: '@coalesce(body(\'Get_Exploited_Page\')?[\'items\'], createArray())'
                  operationOptions: 'Sequential'
                  actions: {
                    Append_ExploitedId: {
                      type: 'AppendToArrayVariable'
                      inputs: {
                        name: 'exploitedIds'
                        value: '@items(\'For_each_Exploited_Page_Item\')?[\'id\']'
                      }
                      runAfter: {}
                    }
                  }
                  runAfter: {
                    Get_Exploited_Page: [
                      'Succeeded'
                    ]
                  }
                }
                Set_HasMoreExploitedPages: {
                  type: 'SetVariable'
                  inputs: {
                    name: 'hasMoreExploitedPages'
                    value: '@equals(length(coalesce(body(\'Get_Exploited_Page\')?[\'items\'], createArray())), 100)'
                  }
                  runAfter: {
                    For_each_Exploited_Page_Item: [
                      'Succeeded'
                    ]
                  }
                }
                Increment_ExploitedPage: {
                  type: 'IncrementVariable'
                  inputs: {
                    name: 'exploitedPage'
                    value: 1
                  }
                  runAfter: {
                    Set_HasMoreExploitedPages: [
                      'Succeeded'
                    ]
                  }
                }
              }
            }
            For_each_Vulnerability: {
              type: 'Foreach'
              foreach: '@variables(\'allItems\')'
              operationOptions: 'Sequential'
              runAfter: {
                Until_AllVulnerabilities: [
                  'Succeeded'
                ]
                Until_ExploitedVulnerabilities: [
                  'Succeeded'
                ]
              }
              actions: {
                Compose_AliasesNormalized: {
                  type: 'Compose'
                  inputs: '@{replace(replace(replace(replace(string(coalesce(items(\'For_each_Vulnerability\')?[\'aliases\'], \'\')), \'[\', \'\'), \']\', \'\'), \'"\', \'\'), \',\', decodeUriComponent(\'%0A\'))}'
                  runAfter: {}
                }
                Compose_TransformedItem: {
                  type: 'Compose'
                  inputs: {
                    TimeGenerated: '@{utcNow()}'
                    EUVDId: '@{items(\'For_each_Vulnerability\')?[\'id\']}'
                    Description: '@{items(\'For_each_Vulnerability\')?[\'description\']}'
                    PublishedDate: '@{items(\'For_each_Vulnerability\')?[\'datePublished\']}'
                    UpdatedDate: '@{items(\'For_each_Vulnerability\')?[\'dateUpdated\']}'
                    CVSSScore: '@items(\'For_each_Vulnerability\')?[\'baseScore\']'
                    CVSSVersion: '@{items(\'For_each_Vulnerability\')?[\'baseScoreVersion\']}'
                    EPSS: '@items(\'For_each_Vulnerability\')?[\'epss\']'
                    Vendor: '@{if(empty(coalesce(items(\'For_each_Vulnerability\')?[\'enisaIdVendor\'], createArray())), \'\', first(coalesce(items(\'For_each_Vulnerability\')?[\'enisaIdVendor\'], createArray()))?[\'vendor\']?[\'name\'])}'
                    Product: '@{if(empty(coalesce(items(\'For_each_Vulnerability\')?[\'enisaIdProduct\'], createArray())), \'\', first(coalesce(items(\'For_each_Vulnerability\')?[\'enisaIdProduct\'], createArray()))?[\'product\']?[\'name\'])}'
                    CveId: '@{if(contains(outputs(\'Compose_AliasesNormalized\'), \'CVE-\'), concat(\'CVE-\', trim(replace(first(split(last(split(outputs(\'Compose_AliasesNormalized\'), \'CVE-\')), decodeUriComponent(\'%0A\'))), decodeUriComponent(\'%0D\'), \'\'))), \'\')}'
                    GHSAId: '@{if(contains(outputs(\'Compose_AliasesNormalized\'), \'GHSA-\'), concat(\'GHSA-\', trim(replace(first(split(last(split(outputs(\'Compose_AliasesNormalized\'), \'GHSA-\')), decodeUriComponent(\'%0A\'))), decodeUriComponent(\'%0D\'), \'\'))), \'\')}'
                    Aliases: '@{outputs(\'Compose_AliasesNormalized\')}'
                    References: '@{items(\'For_each_Vulnerability\')?[\'references\']}'
                    Exploited: '@contains(variables(\'exploitedIds\'), items(\'For_each_Vulnerability\')?[\'id\'])'
                  }
                  runAfter: {
                    Compose_AliasesNormalized: [
                      'Succeeded'
                    ]
                  }
                }
                Append_TransformedItem: {
                  type: 'AppendToArrayVariable'
                  inputs: {
                    name: 'transformedItems'
                    value: '@outputs(\'Compose_TransformedItem\')'
                  }
                  runAfter: {
                    Compose_TransformedItem: [
                      'Succeeded'
                    ]
                  }
                }
              }
            }
            Condition_HasItems: {
              type: 'If'
              expression: '@greater(length(variables(\'transformedItems\')), 0)'
              runAfter: {
                For_each_Vulnerability: [
                  'Succeeded'
                ]
              }
              actions: {
                Set_BatchStart: {
                  type: 'SetVariable'
                  inputs: {
                    name: 'batchStart'
                    value: 0
                  }
                  runAfter: {}
                }
                Set_HasMoreBatches_True: {
                  type: 'SetVariable'
                  inputs: {
                    name: 'hasMoreBatches'
                    value: true
                  }
                  runAfter: {
                    Set_BatchStart: [
                      'Succeeded'
                    ]
                  }
                }
                Until_SendInBatches: {
                  type: 'Until'
                  expression: '@equals(variables(\'hasMoreBatches\'), false)'
                  limit: {
                    count: 1000
                    timeout: 'PT1H'
                  }
                  runAfter: {
                    Set_HasMoreBatches_True: [
                      'Succeeded'
                    ]
                  }
                  actions: {
                    Compose_CurrentBatch: {
                      type: 'Compose'
                      inputs: '@take(skip(variables(\'transformedItems\'), variables(\'batchStart\')), variables(\'batchSize\'))'
                      runAfter: {}
                    }
                    Condition_BatchHasItems: {
                      type: 'If'
                      expression: '@greater(length(outputs(\'Compose_CurrentBatch\')), 0)'
                      runAfter: {
                        Compose_CurrentBatch: [
                          'Succeeded'
                        ]
                      }
                      actions: {
                        Send_Batch_To_Logs_Ingestion_API: {
                          type: 'Http'
                          inputs: {
                            method: 'POST'
                            uri: '@{parameters(\'logsIngestionEndpoint\')}/dataCollectionRules/@{parameters(\'dcrImmutableId\')}/streams/@{parameters(\'streamName\')}?api-version=2023-01-01'
                            headers: {
                              'Content-Type': 'application/json'
                            }
                            body: '@outputs(\'Compose_CurrentBatch\')'
                            authentication: {
                              type: 'ManagedServiceIdentity'
                              identity: '@parameters(\'managedIdentityResourceId\')'
                              audience: 'https://monitor.azure.com'
                            }
                          }
                          runAfter: {}
                        }
                      }
                      else: {
                        actions: {}
                      }
                    }
                    Set_HasMoreBatches: {
                      type: 'SetVariable'
                      inputs: {
                        name: 'hasMoreBatches'
                        value: '@greater(length(skip(variables(\'transformedItems\'), add(variables(\'batchStart\'), variables(\'batchSize\')))), 0)'
                      }
                      runAfter: {
                        Condition_BatchHasItems: [
                          'Succeeded'
                        ]
                      }
                    }
                    Increment_BatchStart: {
                      type: 'IncrementVariable'
                      inputs: {
                        name: 'batchStart'
                        value: '@variables(\'batchSize\')'
                      }
                      runAfter: {
                        Set_HasMoreBatches: [
                          'Succeeded'
                        ]
                      }
                    }
                  }
                }
              }
              else: {
                actions: {}
              }
            }
          }
        }
        Terminate_OnFailure: {
          type: 'Terminate'
          runAfter: {
            Scope_Main: [
              'Failed'
              'TimedOut'
              'Skipped'
            ]
          }
          inputs: {
            runStatus: 'Failed'
            runError: {
              code: 'EuvdIngestionFailed'
              message: 'The EUVD ingestion pipeline failed. Check the run history of Scope_Main for the failing action.'
            }
          }
        }
      }
      outputs: {}
    }
    parameters: {
      euvdApiBaseUrl: {
        value: euvdApiBaseUrl
      }
      logsIngestionEndpoint: {
        value: logsIngestionEndpoint
      }
      dcrImmutableId: {
        value: dcrImmutableId
      }
      streamName: {
        value: streamName
      }
      managedIdentityResourceId: {
        value: identityId
      }
    }
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingName
  scope: logicApp
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output id string = logicApp.id
output name string = logicApp.name
