# General

- Script that can be run locally as well as in a pipeline to create respectively update secrets

- Versions are in PowerShell, one using CLI the other using Az commands


# Parameters

- KeyVaultName: The name of the Key Vault

- SecretsConfiguration: The configuration for the secrets to be created respectively updated
    - You can either provide a value for the secret (first object) or let it be created (second object)

```
[
	{
		"name": "test5",
		"contentType": "virtual-machine-username",
		"value": "vmadmin",
		"enabled": true,
		"updateIfExists": true
	},
	{
		"name": "test6",
		"contentType": "virtual-machine-password",
		"enabled": true,
		"numberOfCharacters": 20,
		"numberOfSpecialCharacters": 1,
		"updateIfExists": false
	}
]
```


# How to use

## Local Run

### As local test run

- Set `$isLocalTesting` to `$true`

- Update variable values

````
[string]$SubscriptionId
[string]$TenantId
[string]$KeyVaultName
[string]$SecretsConfiguration
````

### As script run

- Requires an authenticated context

- Set `$isLocalTesting` to `$false`

- Run script and provide input parameters


## Pipeline Run

- Requires an authenticated context

- Set `$isLocalTesting` to `$false`

- Include script execution in pipeline definition and provide input parameters