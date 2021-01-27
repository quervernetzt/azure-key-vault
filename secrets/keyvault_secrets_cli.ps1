<#
.SYNOPSIS
    Generate and store as well as update secrets in KeyVault
#>

param(
	[Parameter(Mandatory = $True)]
	[string]
	$KeyVaultName,

	[Parameter(Mandatory = $True)]
	[string]
	$SecretsConfiguration
)

[bool]$isLocalTesting = $false


########################################################
# Functions
########################################################
function New-PasswordString {
	param(
		[Parameter(Mandatory = $false)]
		[ValidateRange(3, 9999)]
		[int]$Length = 20, 

		[Parameter(Mandatory = $false)]
		[ValidateRange(0, 9999)]
		[int]$NumberOfSpecialCharacters = 2
	)

	if ($NumberOfSpecialCharacters -gt $Length) { $NumberOfSpecialCharacters = $Length }

	# 0-9, A-Z, a-z, length is based on $Length minus $NumberOfSpecialCharacters for a total length of $Length
	[string]$pwNoSpecialCharacters = ( -join ((48..57) + (65..90) + (97..122) | Get-Random -Count ($Length - $NumberOfSpecialCharacters) | ForEach-Object { [char]$_ }))
	# Special Characters String based on $NumberOfSpecialCharacters 
	[string]$specialCharacters = ( -join ((33..46) + (58..64) | Get-Random -Count $NumberOfSpecialCharacters | ForEach-Object { [char]$_ }))
	# Concat non- and specialChar strings, and randomize order
	[string]$password = -join (($pwNoSpecialCharacters + $specialCharacters) -split '' | Sort-Object { Get-Random })

	return $password
}

function createUpdateSecret() {
	param(
		[Parameter(Mandatory = $True)]
		[string]
		$KeyVaultName,

		[Parameter(Mandatory = $True)]
		[string]
		$KeyVaultSecretName,

		[Parameter(Mandatory = $False)]
		[string]
		$KeyVaultSecretValuePlain,

		[Parameter(Mandatory = $True)]
		[int]
		$SecretNumberOfCharacters,

		[Parameter(Mandatory = $True)]
		[int]
		$SecretNumberOfSpecialCharacters,

		[Parameter(Mandatory = $True)]
		[bool]
		$SecretActivationStatus,

		[Parameter(Mandatory = $True)]
		[string]
		$SecretContentType
	)

	Write-Host "Generating secret value..."
	if ([string]::IsNullOrEmpty($KeyVaultSecretValuePlain)) {
		[string]$keyVaultSecretValueWithAnd = New-PasswordString -Length $SecretNumberOfCharacters -NumberOfSpecialCharacters $SecretNumberOfSpecialCharacters
		[string]$keyVaultSecretValue = $keyVaultSecretValueWithAnd.Replace("&", ".")
	}
	else {
		[string]$keyVaultSecretValue = $KeyVaultSecretValuePlain.Replace("&", ".")
	}

	Write-Host "Setting secret..."
	if ($SecretActivationStatus -eq $true) {
		$dummy = az keyvault secret set --vault-name $KeyVaultName --name $KeyVaultSecretName --value $keyVaultSecretValue --disabled $False
	} 
	else {
		$dummy = az keyvault secret set --vault-name $KeyVaultName --name $KeyVaultSecretName --value $keyVaultSecretValue --disabled $True
	}

	Write-Host "Setting attributes..."
	$dummy = az keyvault secret set-attributes --vault-name $KeyVaultName --name $KeyVaultSecretName --content-type $SecretContentType

	Write-Host "Checking secret..."
	[object[]]$secretObjectCheck = az keyvault secret show --vault-name $KeyVaultName --name $KeyVaultSecretName
	if ($secretObjectCheck) {
		Write-Host "The secret exists..."

		[string]$secretValue = ($secretObjectCheck | ConvertFrom-Json).value

		if ($secretValue -eq $keyVaultSecretValue) {
			Write-Host "Secret is correct..."
		}
		else {
			Throw "Secret is not correct..."
		}
	}
	else {
		Throw "The secret does not exist..."
	}
}


########################################################
# Log In
########################################################
if ($isLocalTesting) {
	Write-Host "Connecting to Azure..."

	[string]$SubscriptionId = "xxx"
	[string]$TenantId = "xxx"
	[string]$KeyVaultName = "xxx"
	[string]$SecretsConfiguration = 
		'
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
		'
	
	az login --tenant $TenantId
	az account set --subscription $SubscriptionId
}


########################################################
# Main
########################################################

[PSCustomObject]$secretsConfigurationObject = $SecretsConfiguration | ConvertFrom-Json

foreach ($secretConfiguration in $secretsConfigurationObject) {
	[string]$keyVaultSecretName = $secretConfiguration.name
	[string]$keyVaultSecretValuePlain = $secretConfiguration.value
	[string]$secretContentType = $secretConfiguration.contentType
	[bool]$secretActivationStatus = $secretConfiguration.enabled
	[int]$secretNumberOfCharacters = $secretConfiguration.numberOfCharacters
	[int]$secretNumberOfSpecialCharacters = $secretConfiguration.numberOfSpecialCharacters
	[bool]$secretUpdateIfExists = $secretConfiguration.updateIfExists

	########################################################
	# Check if secret already exist
	########################################################
	Write-Host "Checking if secret '$keyVaultSecretName' in Key Vault '$KeyVaultName' already exists..."
	[object[]]$secretObject = az keyvault secret show --vault-name $KeyVaultName --name $keyVaultSecretName

	if ($secretObject) {
		Write-Host "The secret already exists..."

		if ($secretUpdateIfExists) {
			Write-Host "The secret is being updated..."
			createUpdateSecret `
				-KeyVaultName $KeyVaultName `
				-KeyVaultSecretName $keyVaultSecretName `
				-KeyVaultSecretValuePlain $keyVaultSecretValuePlain `
				-SecretNumberOfCharacters $secretNumberOfCharacters `
				-SecretNumberOfSpecialCharacters $secretNumberOfSpecialCharacters `
				-SecretActivationStatus $secretActivationStatus `
				-SecretContentType $secretContentType
		}
		else {
			Write-Host "The secret is not being updated..."
		}
	}
	else {
		Write-Host "The secret does not exist, it will be created..."
		createUpdateSecret `
			-KeyVaultName $KeyVaultName `
			-KeyVaultSecretName $keyVaultSecretName `
			-KeyVaultSecretValuePlain $keyVaultSecretValuePlain `
			-SecretNumberOfCharacters $secretNumberOfCharacters `
			-SecretNumberOfSpecialCharacters $secretNumberOfSpecialCharacters `
			-SecretActivationStatus $secretActivationStatus `
			-SecretContentType $secretContentType
	}

	Write-Host "--------------------------------------------------------"
	Write-Host "--------------------------------------------------------"
}