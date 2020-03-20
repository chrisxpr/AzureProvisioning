param (
	[Parameter(Mandatory=$true)] 
	[ValidateSet("local","dev","uat","prod")]
	[string] $EnvironmentName
)

Import-Module AzureBootstrap

function AppendSettings {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="CopyFrom")]
		[psobject]$CopyFrom,
		[Parameter(Mandatory=$true,HelpMessage="CopyTo")]
		[psobject]$CopyTo
	)
	
	foreach($Property in $copyFrom | Get-Member -type NoteProperty, Property){
	
		if ($Property.Name -eq 'ad') {
			if ($copyFrom.ad.groups -ne $null) {
				$copyFrom.ad.groups | foreach {
				
					if($copyTo.ad.groups -eq $null){
						$groups=@() 
						$copyTo.ad | Add-Member -MemberType NoteProperty -Value $groups -Name 'groups'
					}
					
					$copyTo.ad.groups += $_
				}
			}
			
			if ($copyFrom.ad.applications -ne $null) {
				$copyFrom.ad.applications | foreach {
					if($copyTo.ad.applications -eq $null){
						$applications=@() 
						$copyTo.ad | Add-Member -MemberType NoteProperty -Value $applications -Name 'applications'
					}

					$copyTo.ad.applications += $_
				}
			}
		}
		elseif ($Property.Name -eq 'resourceGroups') {
			$copyFrom.resourceGroups | foreach {
				if($copyTo.resourceGroups -eq $null){
					$resourceGroups=@() 
					$copyTo | Add-Member -MemberType NoteProperty -Value $resourceGroups -Name 'resourceGroups'
				}
				
				$copyTo.resourceGroups += $_
			}
		}
		elseif ($Property.Name -eq 'logAnalytics') {
			$copyFrom.logAnalytics | foreach {
				if($copyTo.logAnalytics -eq $null){
					$logAnalytics=@() 
					$copyTo | Add-Member -MemberType NoteProperty -Value $logAnalytics -Name 'logAnalytics'
				}
				$copyTo.logAnalytics += $_
			}
		}
		elseif ($Property.Name -eq 'keyVaults') {
			$copyFrom.keyVaults.list | foreach {
				if($copyTo.keyVaults -eq $null){
					$keyVaults=new-object psobject
					$copyTo | Add-Member -MemberType NoteProperty -Value $keyVaults -Name 'keyVaults'
					
					$list = @() 
					$copyTo.keyVaults | Add-Member -MemberType NoteProperty -Value $list -Name 'list'
				}
				
				$copyTo.keyVaults.list += $_
			}
		}
		
		elseif ($Property.Name -eq 'databaseServers') {
			$copyFrom.databaseServers | foreach {
				if($copyTo.databaseServers -eq $null){
					$databaseServers=@() 
					$copyTo | Add-Member -MemberType NoteProperty -Value $databaseServers -Name 'databaseServers'
				}
				
				$copyTo.databaseServers += $_
			}
		}
	}
}
		
function Add-SqlDatabases {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName
	)
	
	Write-Host ""
	Write-Host "[Add-DatabaseServers]"
	Write-Host ""
	
	$settings.databases | foreach {
		$database = $_
		$deploySettings = $database.deploy | where { $_.env -eq $environmentName }  
		$deployEnabled = $false
		if ($deploySettings -ne $null) {
			$deployEnabled = $deploySettings[0].enabled
		}
		
		if ($deployEnabled -eq $true)
		{
			$adGroup = Add-SqlDatabase -database $database -Settings $settings -conventions $conventions -EnvironmentName $environmentName
		}
		else
		{
			Write-Host "Skipping database creation for type:$currentType and deployEnabled:$deployEnabled"
		}
	}
	
	return $true
}

function Add-SqlDatabase {

	Param(
		[Parameter(Mandatory=$true,HelpMessage="Database")]
		[psobject]$database,
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName
	)
	Write-Host ""
	Write-Host "[Add-Database]"
	
	$location = Get-LocationByKey -Key $database.location -Conventions $conventions
	$locationName = $location.Name
	
	# Format the environment key formatting
	$resourceGroup = $settings.resourceGroups | where { $_.type -eq $database.rgKey }  
	$isSharedResourceGroup = $resourceGroup.isShared
	$sharedEnvironmentName = $environmentName
	
	if ($isSharedResourceGroup -ne $null -and $isSharedResourceGroup -eq $true) {
		$env = Get-EnvironmentByKey -Key $environmentName -Conventions $conventions	
		$sharedEnvironmentName = $env.sharedKey
		Write-Host "Overiding the environemt key to: $sharedEnvironmentName"
	}
	
	# End the environment key formatting
	$resourceGroupName = Get-ResourceGroupName -Type $database.rgKey -Settings $settings -Conventions $conventions -EnvironmentName $sharedEnvironmentName -LocationKey $database.location
	$serverDetails = $settings.databaseServers | where { $_.type -eq $database.server }
	
	if ($serverDetails -eq $null) {
		Write-Host "Unable to retrieve server details for type:" $database.server
		return $false
	}
	
	$deploySettings = $serverDetails[0].deploy | where { $_.env -eq $sharedEnvironmentName }  
	$primaryLocation = $deploySettings[0].primaryLocation
	
	$serverName = Format-ResourceName $serverDetails[0].serverName -EnvironmentName $sharedEnvironmentName -Conventions $conventions -LocationKey $primaryLocation
	$databaseName = Format-ResourceName $database.name -EnvironmentName $environmentName -Conventions $conventions -LocationKey $primaryLocation
	
	Write-Host ""
	Write-Host " - resourceGroupName: " $resourceGroupName
	Write-Host " - serverName: " $serverName
	Write-Host " - databaseName: " $databaseName
	Write-Host ""
	
	Write-Host "Checking to see if database exists"
	$databaseId = az sql db show --name $databaseName --resource-group $resourceGroupName --server $serverName --query id --output TSV
	Reset-UI
	
	if ($databaseId -eq $null) {
		az sql db create --name $databaseName `
				 --resource-group $resourceGroupName `
				 --server $serverName 
	}
	else {
		Write-Host "sql database already exists - skipping create"
	}
	
	Write-Host "Checking to see if tde enabled"
	$tde = az sql db tde show --database $databaseName `
				 --resource-group $resourceGroupName `
				 --server $serverName
				 
	Reset-UI
	
	if ($tde -eq $null) {
		az sql db tde set --database $databaseName `
					 --resource-group $resourceGroupName `
					 --server $serverName `
					 --status Enabled
	}
	else {
		Write-Host "sql database tde already enabled - skipping update"
	}
				 
	Manager-SqlDatabaseAccess -Database $database -Settings $settings -Conventions $conventions -EnvironmentName $environmentName
	
	return $true
}

function Add-ADApplications {
	Param(
		[Parameter(Mandatory=$true,HelpMessage="settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="Environment Name")]
		[string]$environmentName
	)
	
	Write-Host ""
	Write-Host "[Add-ADApplications]"
	
	$applicationList = $settings.ad.applications
	
	$applicationList | foreach {
		$application = $_
		
		Add-AdApplication -Application $application -Settings $settings -Conventions $conventions -EnvironmentName $environmentName
	}
	
	return $true
}

function Add-AdApplication {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="Application")]
		[psobject]$application,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName
	)
	
	Write-Host ""
	Write-Host "[Add-AdApplication]"
	
	$deploySettings = $application.deploy | where { $_.env -eq $environmentName }  
	$deployEnabled = $deploySettings[0].enabled
	
	$applicationName = Format-ResourceName $application.applicationName -EnvironmentName $environmentName -Conventions $conventions -LocationKey $locationKey
		
	if ($deployEnabled -eq $true)
	{
		$tenantId = az account show --query tenantId --output TSV
		$identitierUrl = Format-ResourceName $application.identifierUrl -EnvironmentName $environmentName -Conventions $conventions -LocationKey $locationKey
		
		$existingAppId = az ad app list --query "[?displayName=='$applicationName'].{a:objectId}" --output TSV
		
		if ($existingAppId  -ne $null)
		{
			Write-Host "AD Application already exists for display-name: $applicationName and objectId:$existingAppId "
			return $false
		}
		
		Write-Host ""
		Write-Host " - applicationName: " $applicationName
		Write-Host " - identitierUrl: " $identitierUrl
		Write-Host " - tenantId: " $tenantId
		
		$applicationIdKeyName = Format-ResourceName $application.keys.applicationIdKey -EnvironmentName $environmentName -Conventions $conventions -LocationKey $locationKey 
		$applicationSecretKeyName = Format-ResourceName $application.keys.applicationSecretKey -EnvironmentName $environmentName -Conventions $conventions -LocationKey $locationKey 
		$applicationNameKeyName = Format-ResourceName $application.keys.applicationNameKey -EnvironmentName $environmentName -Conventions $conventions -LocationKey $locationKey 
		$tenantIdKeyName = Format-ResourceName $application.keys.tenantIdKey -EnvironmentName $environmentName -Conventions $conventions -LocationKey $locationKey 
		
		Write-Host ""
		Write-Host " - applicationIdKeyName: " $applicationIdKeyName
		Write-Host " - applicationNameKeyName: " $applicationNameKeyName
		Write-Host " - tenantIdKeyName: " $tenantIdKeyName
		Write-Host ""
		
		# Create Credential
		$password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 50 | % {[char]$_})
		
		# Create AD Application
		$adApplicationId = az ad app create --display-name $applicationName --identifier-uris $identitierUrl --password $password  --query appId --output TSV

		# create service prinicpal
		az ad sp create --id $adApplicationId
		
		$envKeyVault = $settings.keyVaults.list | where { $_.type -eq $deploySettings[0].kvKey }
		$envKeyVaultName = Format-ResourceName $envKeyVault[0].name -Conventions $conventions -EnvironmentName $environmentName 
	
		# Update the environment key vault with settings
		az keyvault secret set --value $adApplicationId --name $applicationIdKeyName --vault-name $envKeyVaultName
		az keyvault secret set --value $applicationName --name $applicationNameKeyName --vault-name $envKeyVaultName
		az keyvault secret set --value $password --name $applicationSecretKeyName --vault-name $envKeyVaultName
		az keyvault secret set --value $tenantId --name $tenantIdKeyName --vault-name $envKeyVaultName
	}
	else {
		Write-Host "Deploy enabled is false for applicationName:$applicationName = skipping create"
	}
	
}

function Get-ADApplicationName {
	Param(	
		[Parameter(Mandatory=$true,HelpMessage="type")]
		[string]$type,
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName
	)
	
	Write-Host ""
	Write-Host "[Get-ADApplicationName]"
	
	$application = $settings.ad.applications | where { $_.type -eq $type }
	if ($application -ne $null) {
		$applicationName = Format-ResourceName $application[0].applicationName -EnvironmentName $environmentName -Conventions $conventions
	}
	else {
		Write-Host "Unable to location application type: $type"
	}
	
	return $applicationName
}

function Manager-SqlDatabaseAccess {

	Param(
		[Parameter(Mandatory=$true,HelpMessage="Database")]
		[psobject]$database,
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName
	)
	Write-Host ""
	Write-Host "[Manager-SqlDatabaseAccess]"
	
	# format the sql script with required params
	$deploySettings = $database.deploy | where { $_.env -eq $environmentName }
	$accessScriptFile = $deploySettings[0].accessScript
	Write-Host " - accessScriptFile:$accessScriptFile "
	$allowDeveloperGroup = $false
	
	$currentFolder = (Get-Location -PSProvider FileSystem).ProviderPath
	$scriptFilePath = $currentFolder + $accessScriptFile
	Write-Host " - scriptFilePath:$scriptFilePath "
	
	$scriptContents = ( Get-Content -Raw $scriptFilePath | Out-String)
	
	Write-Host " - serviceAccountType:" $database.serviceAccountType
	$serviceAccountName = Get-ADApplicationName -Type $database.serviceAccountType -Settings $settings -Conventions $conventions -EnvironmentName $environmentName 
	$scriptContents = $scriptContents -Replace '{ServiceAccount}', $serviceAccountName
	
	if ($deploySettings[0].allowDeveloperGroup -ne $null -and $deploySettings[0].allowDeveloperGroup -eq $true) {
		$developerGroupName = Get-ADGroupName -Type $database.developerGroupType -Settings $settings -Conventions $conventions -EnvironmentName $environmentName
		Write-Host " - developerGroupName:$developerGroupName "
		$scriptContents = $scriptContents -Replace '{DeveloperGroup}', $developerGroupName
	}
	
	Write-Host "ScriptContent generation complete"
	
	# Format the environment key formatting
	$resourceGroup = $settings.resourceGroups | where { $_.type -eq $database.rgKey }  
	$isSharedResourceGroup = $resourceGroup.isShared
	$sharedEnvironmentName = $environmentName
	
	if ($isSharedResourceGroup -ne $null -and $isSharedResourceGroup -eq $true) {
		$env = Get-EnvironmentByKey -Key $environmentName -Conventions $conventions	
		$sharedEnvironmentName = $env.sharedKey
		Write-Host "Overiding the environemt key to: $sharedEnvironmentName"
	}
	
	# End the environment key formatting
	$resourceGroupName = Get-ResourceGroupName -Type $database.rgKey -Settings $settings -Conventions $conventions -EnvironmentName $sharedEnvironmentName -LocationKey $database.location
	$serverDetails = $settings.databaseServers | where { $_.type -eq $database.server }
	
	if ($serverDetails -eq $null) {
		Write-Host "Unable to retrieve server details for type:" $database.server
		return $false
	}
	
	$deploySettings = $serverDetails[0].deploy | where { $_.env -eq $sharedEnvironmentName }  
	$primaryLocation = $deploySettings[0].primaryLocation
	
	$serverName = Format-ResourceName $serverDetails[0].serverName -EnvironmentName $sharedEnvironmentName -Conventions $conventions -LocationKey $primaryLocation
	$databaseName = Format-ResourceName $database.name -EnvironmentName $environmentName -Conventions $conventions -LocationKey $primaryLocation
	
	#################################
	$filePath = $currentFolder + '/setup/' + $databaseName + '.sql'
	$outputPath = $currentFolder + '/setup/output.txt'
	
	Write-Host " - filePath: $filePath"
	Write-Host " - outputPath: $outputPath"
	Write-Host ""
	
	Set-Content -Path $filePath -Value $scriptContents
	
	$devopsUserName = Read-Host "Please enter your azure user to continue db configuration"
    
	if ($devopsUserName -eq '')
	{
		Write-Host "Skipping db configuration..."
		return $false
	}
    $formattedServerName = $serverName + '.database.windows.net'
	Write-Host " - formattedServerName: $formattedServerName"
	
	Write-Host "Attempting to run setup script:$filePath on database: $databaseName"
		
	Write-Host "sqlcmd -S '$formattedServerName' -d '$databaseName' -G -U '$devopsUserName' -i '$filePath' -o '$outputPath'"
    
	return $true
}

function Load-Settings {
	Param( 
		[Parameter(Mandatory=$true,HelpMessage="settingsFile")]
		[psobject]$settingsFile
	)

	$settings = ( Get-Content -Raw $settingsFile | Out-String | ConvertFrom-Json )

	Reset-UI

	if ($settings -eq $null)
	{
		Write-Host "error loading the settings file: $settingsFile"
		Write-Host "quitting process"
	}	
	return $settings
}

function Load-EnvironmentSettings {

	$bootstrapSettingsFile = '..\bootstrap-settings.json'
	$sharedSettingsFile = '..\shared-settings.json'
	$environmentSettingsFile = '..\environment-settings.json'

	$bsettings = ( Get-Content -Raw $bootstrapSettingsFile | Out-String | ConvertFrom-Json )

	Reset-UI

	if ($bsettings -eq $null)
	{
		Write-Host "error loading the settings file: $bootstrapSettingsFile"
		Write-Host "quitting process"
	}

	$ssettings = ( Get-Content -Raw $sharedSettingsFile | Out-String | ConvertFrom-Json )

	Reset-UI

	if ($ssettings -eq $null)
	{
		Write-Host "error loading the settings file: $sharedSettingsFile"
		Write-Host "quitting process"
	}	
	
	$esettings = ( Get-Content -Raw $environmentSettingsFile | Out-String | ConvertFrom-Json )

	Reset-UI

	if ($esettings -eq $null)
	{
		Write-Host "error loading the settings file: $environmentSettingsFile"
		Write-Host "quitting process"
	}

	AppendSettings -CopyFrom $bsettings -CopyTo $ssettings
	AppendSettings -CopyFrom $ssettings -CopyTo $esettings

	return $esettings
}

$conventionsFile = '..\conventions.json'
$conventions = Load-Settings $conventionsFile

$environmentSettings = Load-EnvironmentSettings

Write-Host ""
Write-Host "------------------------------------"
Write-Host "Please confirm subscription details."
Write-Host "------------------------------------"
Write-Host ""

az account show

$confirmation = Read-Host "Are you Sure You Want To Proceed: Y(Yes): N(No)"

if ($confirmation -ne "Y")
{
	Write-Host "Stopping execution..."
	return $false
}

# Create Resource Groups plus roles
$outcome = Add-ResourceGroups -Settings $environmentSettings -Conventions $conventions -Environment $EnvironmentName
if ($outcome -eq $false)
{
	Write-Host "[Add-ResourceGroups]Quitting process"
	return $false
	
}
Reset-UI

# Create Key Vaults
$outcome = Add-KeyVaults -Settings $environmentSettings -Conventions $conventions -Environment $EnvironmentName

if ($outcome -eq $false)
{
	Write-Host "[Add-KeyVaults]Quitting process"
	return $false
}
Reset-UI


# Create AD applications
$outcome = Add-ADApplications -Settings $environmentSettings -Conventions $conventions -Environment $EnvironmentName
if ($outcome -eq $false)
{
	Write-Host "[Add-ADApplications]Quitting process"
	return $false
	
}
Reset-UI

# Create SQL databases
$outcome = Add-SqlDatabases -Settings $environmentSettings -Conventions $conventions -Environment $EnvironmentName
if ($outcome -eq $false)
{
	Write-Host "[Add-Databases]Quitting process"
	return $false
	
}
Reset-UI


Write-Host ""
Write-Host "All done"
