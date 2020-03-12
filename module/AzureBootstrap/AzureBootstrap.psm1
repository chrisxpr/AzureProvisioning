<#
.Synopsis
    Azure Bootstrap gets you started building out your Azure infrastructure
.Description 
    This powershell contains helper functions for managing the deployment and configuration of azure infrastructure
		
#>

function Format-ResourceName {
	Param(
		[Parameter(Mandatory=$true,HelpMessage="Resource")]
		[psobject]$resource,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName,
		[Parameter(Mandatory=$false,HelpMessage="LocationKey")]
		[psobject]$locationKey
	)
	
	$localResourceName = ($resource -replace "{environment}", $environmentName).ToLower()
	$localResourceName = ($localResourceName -replace "{prefix}", $conventions.prefix).ToLower()
	$localResourceName = ($localResourceName -replace "{longPrefix}", $conventions.longPrefix).ToLower()
	
	if ($locationKey -ne '') {
		$localResourceName = ($localResourceName -replace "{locationKey}", $locationKey).ToLower()
	}
	
	Write-Host "[Format-ResourceName] Resource Name created: $localResourceName"
	return $localResourceName
}

function Get-PrimaryLocation {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions
	)
	
	Reset-UI
	
	$location = $conventions.locations | where { $_.isPrimary -eq $true }
	return $location[0]
}

function Get-LocationByKey {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="Key")]
		[string]$key,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions
	)
	
	Reset-UI

	$location = $conventions.locations | where { $_.key -eq $key }
	return $location[0]
}

function Add-ADGroups {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName
	)
	
	$settings.ad.groups | foreach {
		$currentADGroup = $_
		$currentADGroupType = $currentADGroup[0].type
		$deploySettings = $currentADGroup[0].deploy | where { $_.env -eq $environmentName }  
		$deployEnabled = $false
		if ($deploySettings -ne $null) {
			$deployEnabled = $deploySettings[0].enabled
		}
		
		if ($deployEnabled -eq $true)
		{
			$adGroup = Add-ADGroup -adGroup $currentADGroup -Settings $settings -conventions $conventions -EnvironmentName $environmentName
		}
		else
		{
			Write-Host "Skipping ad group creation for type:$currentADGroupType and deployEnabled:$deployEnabled"
		}
	}
	
	return $true
}

function Get-ADGroup {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="Type")]
		[string]$type,
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName
	)
	
	$adg = $null
	
	Write-Host "[Get-ADGroup] Retrieving AD Group from config.ad.groups for type:$type"
	
	$adGroup = $settings.ad.groups | where { $_.type -eq $type }  
	$adGroupName = $adGroup[0].name
	$adGroupName = Format-ResourceName -Resource $adGroupName -Conventions $conventions -EnvironmentName $environmentName
	
	Write-Host "adGroupName to retrieve:$adGroupName"
	
	if ($adGroupName -ne $null)
	{
		$adg = az ad group show --group $adGroupName 
		return ($adg | ConvertFrom-Json)
	}
	else {
		Write-Host "Unable to determine adGroupName please check config.ad.groups"
	}
}

function Add-ADGroup {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="AD Group")]
		[psobject]$adGroup,
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName
	)
	
	$adGroupName = $adGroup[0].name
	$groupName = Format-ResourceName -Resource $adGroupName -Conventions $conventions -EnvironmentName $environmentName
	
	Write-Host "[Add-ADGroup] Creating AD Group: $groupName"
	
	if ($groupName -ne $null)
	{
		$adgId = az ad group show --group $groupName --query id --output TSV 
		
		if ($adgId -eq $null) { 
			az ad group create --display-name $groupName --mail-nickname $groupName
		}
		else {
			Write-Host "Skipping create of AD group: $groupName - already exists"
		}
	}
	else {
		Write-Host "groupName empty please check config and try again"
	}
}

function Get-ADGroupName {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="Type")]
		[string]$type,
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName
	)
	
	Reset-UI
	
	Write-Host ""
	Write-Host "----------------------------------------------"
	Write-Host "Get-ADGroupName"
	Write-Host "----------------------------------------------"
	Write-Host "Retrieving AD Group from config.ad.groups for type:$type"
	
	$adGroup = $settings.ad.groups | where { $_.type -eq $type }  
	$adGroupName = $adGroup[0].name
	$adGroupName = Format-ResourceName -Resource $adGroupName -Conventions $conventions -EnvironmentName $environmentName
	
	return $adGroupName
}

function Get-ResourceGroup {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="Type")]
		[string]$type,
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName,
		[Parameter(Mandatory=$false,HelpMessage="LocationKey")]
		[string]$locationKey
	)
	
	Reset-UI
	
	Write-Host ""
	Write-Host "----------------------------------------------"
	Write-Host "Get-ResourceGroup"
	Write-Host "----------------------------------------------"
	$resourceGroupId = $null
	
	$resourceGroup = $settings.resourceGroups | where { $_.type -eq $type }  

	Write-Host "location key: $LocationKey"
	$resourceGroupName = Format-ResourceName $resourceGroup[0].name -EnvironmentName $environmentName -Conventions $conventions -LocationKey $locationKey
	
	Write-Host "Resource Group Type:$type resolves to:$resourceGroupName"
	$location = Get-LocationByKey -Key $locationKey -Conventions $conventions
	$locationName = $location.Name
	
	$rg = az group show --name $resourceGroupName
	
	if ($rg -eq $null)
	{
		Reset-UI
		
		Write-Host "Resource Group not found - proceeding to create"
		$rg = az group create --name $resourceGroupName --location $locationName
		
		$deploySettings = $currentGroup.deploy | where { $_.env -eq $environmentName }  
		$contributors = $deploySettings[0].contributors.split(",")
		
		$contributors | foreach {
			$contributorName = $_
			Write-Host "Adding contributor role for ad group: $contributorName"
			$adGroup = Get-ADGroup -Type $contributorName -Settings $settings -conventions $conventions -EnvironmentName $environmentName
			
			if ($adGroup -ne $null) {
				$adGroupId = $adGroup.objectId
				Write-Host "Assigning Contributor role to $adGroupId"
				az role assignment create --role Contributor --assignee $adGroup.objectId --resource-group $resourceGroupName
			}
			else
			{
				Write-Host "Unable to load ad group: $contributorName - skipping role assignment"
			}
		}
	}
	else
	{
		Write-Host "Resource Group:$resourceGroupName already exists - skipping create"
	}
	
	return ($rg | ConvertFrom-Json)
}

function Add-ResourceGroups {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName
	)
	
	$settings.resourceGroups | foreach {
		$currentGroup = $_
		$currentGroupType = $currentGroup.type
		
		$deploySettings = $currentGroup.deploy | where { $_.env -eq $environmentName }  
		$deployEnabled = $false
		if ($deploySettings -ne $null) {
			$deployEnabled = $deploySettings[0].enabled
		}
		
		if ($deployEnabled -eq $true)
		{
			$locationList = $currentGroup.location.split(",")
			$locationList | foreach {
				$locationKey = $_
				Get-ResourceGroup -Type $currentGroup.type -Settings $settings -Conventions $conventions -EnvironmentName $environmentName -LocationKey $locationKey
			}
		}
		else
		{
			Write-Host "Skipping resource group creation for type:$currentGroupType and deployEnabled:$deployEnabled"
		}		
	}
	
	return $true
}

function Get-ResourceGroupName {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="Type")]
		[string]$type,
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName,
		[Parameter(Mandatory=$false,HelpMessage="LocationKey")]
		[string]$LocationKey
	)
	
	Reset-UI
	
	$resourceGroup = $settings.resourceGroups | where { $_.type -eq $type }  
	$resourceGroupTemplate = $resourceGroup.name
	
	Write-Host "[Get-ResourceGroupName] resourceGroupTemplate: $resourceGroupTemplate"
	$resourceGroupName = Format-ResourceName $resourceGroupTemplate -EnvironmentName $environmentName -Conventions $conventions -LocationKey $locationKey
	Write-Host "[Get-ResourceGroupName] Resource Group Name: $resourceGroupName"
	return $resourceGroupName
}

function Add-LogAnalyticsWorkspaces {
	Param( 
			[Parameter(Mandatory=$true,HelpMessage="Settings")]
			[psobject]$settings,
			[Parameter(Mandatory=$true,HelpMessage="Conventions")]
			[psobject]$conventions,
			[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
			[string]$environmentName
	)
	
	$settings.logAnalytics | foreach {
		$currentWorkspace = $_
		$currentWorkspaceType = $currentWorkspace.type
		
		$deploySettings = $currentWorkspace.deploy | where { $_.env -eq $environmentName }  
		$deployEnabled = $false
		if ($deploySettings -ne $null) {
			$deployEnabled = $deploySettings[0].enabled
		}
		
		if ($deployEnabled -eq $true)
		{
			Write-Host "Proceeding to create law:$currentWorkspaceType"
			Add-LogAnalyticsWorkspace -Workspace $currentWorkspace -Settings $settings -Conventions $conventions -EnvironmentName $environmentName
		}
		else
		{
			Write-Host "Skipping workspace creation for type:$currentWorkspaceType and deployEnabled:$deployEnabled"
		}		
	}
	
	return $true
}

function Add-LogAnalyticsWorkspace {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="workspace")]
		[psobject]$workspace,
		[Parameter(Mandatory=$true,HelpMessage="settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="environmentName")]
		[string]$environmentName
	)
	
	if ($workspace -eq $null)
	{
		Write-Host "Skipping create of workspace - settings empty please check config"
		return $false
	}
	
	$logAnalyticsWorkspaceName = Format-ResourceName -Resource $workspace.workspaceName -EnvironmentName $environmentName -Conventions $conventions -LocationKey $workspace.location
	Write-Host "logAnalyticsWorkspaceName: $logAnalyticsWorkspaceName"
	
	$logAnalyticsSku = $workspace.sku
	$location = Get-LocationByKey -Key $workspace.location -Conventions $conventions
	$logAnalyticsLocation = $location.cloudKey
	$logAnalyticsRgKey = $workspace.rgKey
	
	Write-Host "logAnalyticsSku: $logAnalyticsSku"
	Write-Host "logAnalyticsLocation: $logAnalyticsLocation"
	Write-Host "logAnalyticsRgKey: $logAnalyticsRgKey"
	
	$resourceGroupName = Get-ResourceGroupName -Type $logAnalyticsRgKey -Settings $settings -Conventions $conventions -EnvironmentName $environmentName
	
	Write-Host "Display law resource for -n $logAnalyticsWorkspaceName -g $resourceGroupName"
	$laWorkspace = (az resource show -g $resourceGroupName -n $logAnalyticsWorkspaceName --resource-type 'Microsoft.OperationalInsights/workspaces') | ConvertFrom-Json

	if ($laWorkspace -eq $null)
	{
		Reset-UI
		
		az group deployment create --resource-group $resourceGroupName --template-file 'lawTemplate.json' --parameters workspaceName=$logAnalyticsWorkspaceName --parameters location=$logAnalyticsLocation --parameters pricingTier=$logAnalyticsSku
		$laWorkspace = (az resource show -g $resourceGroupName -n $logAnalyticsWorkspaceName --resource-type 'Microsoft.OperationalInsights/workspaces') | ConvertFrom-Json
	}
	else {
		Write-Host "Skipping create of workspace: $logAnalyticsWorkspaceName - already exists"
	}
}

function Get-LogAnalyticsWorkspace {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="type")]
		[psobject]$type,
		[Parameter(Mandatory=$true,HelpMessage="settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="environmentName")]
		[string]$environmentName
	)

	$workspace = $settings.logAnalytics | where { $_.type -eq $type }  

	$logAnalyticsWorkspaceName = Format-ResourceName -Resource $workspace.workspaceName -EnvironmentName $environmentName -Conventions $conventions -LocationKey $workspace.location
	$resourceGroupName = Get-ResourceGroupName -Type $workspace.rgKey -Settings $settings -Conventions $conventions -EnvironmentName $environmentName
	
	Write-Host "logAnalyticsWorkspaceName: $logAnalyticsWorkspaceName"
	Write-Host "resourceGroupName: $resourceGroupName"
	
	$laWorkspace = (az resource show -g $resourceGroupName -n $logAnalyticsWorkspaceName --resource-type 'Microsoft.OperationalInsights/workspaces') | ConvertFrom-Json

	return $laWorkspace
}

function Add-KeyVaults {
	Param(
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName
	)
	
	Write-Host ""
	Write-Host "[Add-KeyVaults]"
	Write-Host ""
	
	$keyVaultList = $settings.keyVaults.list
	
	if ($keyVaultList -eq $null)
	{
		Write-Host "Unable to locate service plan data please check configuration: config.keyVaults.list"
		return $false
	}
	
	$keyVaultList | foreach {
		$keyVault = $_
		$keyVaultType = $keyVault.type
		
		$deploySettings = $keyVault.deploy | where { $_.env -eq $environmentName }  
		
		$deployEnabled = $false
		if ($deploySettings -ne $null) {
			$deployEnabled = $deploySettings[0].enabled
		}
		
		$keyVaultName = Format-ResourceName $keyVault.name -EnvironmentName $environmentName -Conventions $conventions
		
		if ($deployEnabled -eq $true)
		{
			$resourceGroupName = Get-ResourceGroupName -Type $keyVault.rgKey -Settings $settings -conventions $conventions -EnvironmentName $environmentName
			
			Write-Host ""
			Write-Host "key vault settings"
			Write-Host "---------------------"
			Write-Host "keyVaultName:" $keyVaultName
			Write-Host "resourceGroupName:" $resourceGroupName
				
			$kv = (az keyvault show --name $keyVaultName --resource-group $resourceGroupName) | ConvertFrom-Json
			
			if ($kv -ne $null)
			{
				Write-Host "Skipping create of key vault - already exists"
				Write-Host ""
			}
			else
			{
				Reset-UI
				
				Write-Host "key vault $keyVaultName not found proceeding to create"
				Write-Host ""
				
				$kv = Add-KeyVault -keyVaultName $keyVaultName -resourceGroupName $resourceGroupName
			}
			
			$workspace = Get-LogAnalyticsWorkspace -type $keyVault.workspaceType -settings $settings -conventions $conventions -environmentName $environmentName
			
			if ($workspace -ne $null) {
		
				$diagnosticName = $keyVault.diagnosticName
				$workspaceId = $workspace.id
				Write-Host "Workspace ID: $workspaceId"
				$keyVaultResourceId = $kv.id
				Write-Host "KV Resource ID: $keyVaultResourceId"
				
				Write-Host "Creating monitor settings $diagnosticName"
				
				az monitor diagnostic-settings create --name $diagnosticName `
					--resource $keyVaultResourceId `
					--workspace $workspaceId `
					--logs "[{\""category\"": \""AuditEvent\"",\""enabled\"": true}]" `
					--metrics "[{\""category\"": \""AllMetrics\"",\""enabled\"": true}]"		
		
			}			
			
			Write-Host ""
			Write-Host "end key vault creation"
			Write-Host "---------------------"
			Write-Host ""
		}
		else
		{
			Write-Host "Skipping key vault creation for keyVaultName:$keyVaultName and deployEnabled:$deployEnabled"
		}	
	}
	
	return $true
}

function Add-KeyVault {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="keyVaultName")]
		[string]$keyVaultName,
		[Parameter(Mandatory=$true,HelpMessage="resourceGroupName")]
		[string]$resourceGroupName
	)
	
	Write-Host ""
	Write-Host "[Add-KeyVault] Creating Key Vault: $keyVaultName"
	Write-Host ""
	
	if ($keyVaultName -ne $null) {
		$newKv = az keyvault create --name $keyVaultName --resource-group $resourceGroupName
		
		if ($newKv -eq $null) {
			Write-Host "Unable to create key vault please check config and try again"
			return $false
		}
		
		$defaultRoleGroups = $deploySettings[0].defaultRoleGroups
		
		if ($defaultRoleGroups -eq $null -or $defaultRoleGroups -eq "") 
		{
			Write-Host "$deploySettings[0].defaultRoleGroups is null or empty - skipping assignment"
		}
		else
		{
			Write-Host "Adding key vault permissions for default role"
		
			$roleList = $defaultRoleGroups.split(",")
			$roleList | foreach {
				$groupName = $_
				Write-Host "Adding key vault permissions for group: $groupName"
				$adGroup = Get-ADGroup -Type $groupName -Settings $settings -conventions $conventions -EnvironmentName $environmentName
				
				if ($adGroup -ne $null) {
					$adGroupId = $adGroup.objectId
					Write-Host "Assigning key vault permissions to role id: $adGroupId"
					az keyvault set-policy --name $keyVaultName --resource-group $resourceGroupName --secret-permissions get list --object-id $adGroupId
				}
				else
				{
					Write-Host "Unable to load ad group: $groupName - skipping permission assignment"
				}
			}
		}
		
		$adminRoleGroups = $deploySettings[0].adminRoleGroups
		
		if ($adminRoleGroups -eq $null -or $adminRoleGroups -eq "")  
		{
			Write-Host "$deploySettings[0].adminRoleGroups is null or empty - skipping assignment"
			return $false
		}
		else
		{
			Write-Host "Adding key vault permissions for admin role"
			$roleList = $adminRoleGroups.split(",")
			$roleList | foreach {
				$groupName = $_
				Write-Host "Adding key vault permissions for group: $groupName"
				$adGroup = Get-ADGroup -Type $groupName -Settings $settings -conventions $conventions -EnvironmentName $environmentName
				
				if ($adGroup -ne $null) {
					$adGroupId = $adGroup.objectId
					Write-Host "Assigning key vault permissions to role id: $adGroupId"
					az keyvault set-policy --name $keyVaultName --resource-group $resourceGroupName --secret-permissions backup delete get list purge recover restore set --object-id $adGroupId
				}
				else
				{
					Write-Host "Unable to load ad group: $groupName - skipping permission assignment"
				}
			}
		}
				
		return ($newKv | ConvertFrom-Json)
	}
	else {
		Write-Host "keyVaultName empty please check config.keyVaults"
		return $null
	}
}

$backgroundColor = $Host.UI.RawUI.BackgroundColor
$foregroundColor = $Host.UI.RawUI.ForegroundColor
  
function Reset-UI {
	$Host.UI.RawUI.BackgroundColor = $backgroundColor
	$Host.UI.RawUI.ForegroundColor = $foregroundColor
}