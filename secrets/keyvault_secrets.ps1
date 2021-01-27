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
		[string]$keyVaultSecretValue = New-PasswordString -Length $SecretNumberOfCharacters -NumberOfSpecialCharacters $SecretNumberOfSpecialCharacters
	}
	else {
		[string]$keyVaultSecretValue = $KeyVaultSecretValuePlain
	}

	[securestring]$keyVaultSecretValueSecure = ConvertTo-SecureString $keyVaultSecretValue -AsPlainText -Force

	Write-Host "Setting secret..."
	if ($SecretActivationStatus -eq $true) {
		$dummy = Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName -SecretValue $keyVaultSecretValueSecure -ContentType $SecretContentType
	} 
	else {
		$dummy = Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName -SecretValue $keyVaultSecretValueSecure -ContentType $SecretContentType -Disable
	}

	Write-Host "Checking secret..."
	[Microsoft.Azure.Commands.KeyVault.Models.PSKeyVaultSecret]$secretObjectCheck = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName
	if ($secretObjectCheck) {
		Write-Host "The secret exists..."

		[securestring]$secretValueSecure = $secretObjectCheck.SecretValue
		[string]$secretValue = (New-Object PSCredential '.', $secretValueSecure).GetNetworkCredential().Password
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
				"numberOfSpecialCharacters": 4,
				"updateIfExists": false
			}
		]
		'
	
	Connect-AzAccount -TenantId $tenantId -SubscriptionId $subscriptionId
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
	[Microsoft.Azure.Commands.KeyVault.Models.PSKeyVaultSecret]$secretObject = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultSecretName

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