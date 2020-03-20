param (
	[Parameter(Mandatory=$true)] 
	[ValidateSet("devtest","prod")]
	[string] $EnvironmentName
)

Import-Module AzureBootstrap

function AppendBootstrapSettings (
	[Parameter(Mandatory=$true,HelpMessage="BootstrapSettings")]
	[psobject]$bootstrapSettings,
	[Parameter(Mandatory=$true,HelpMessage="SharedSettings")]
	[psobject]$sharedSettings
){

    foreach($Property in $bootstrapSettings | Get-Member -type NoteProperty, Property){
	
		if ($Property.Name -eq 'ad') {
			$bootstrapSettings.ad.groups | foreach {
				$sharedSettings.ad.groups += $_
			}
		}
		elseif ($Property.Name -eq 'resourceGroups') {
			$bootstrapSettings.resourceGroups | foreach {
				$sharedSettings.resourceGroups += $_
			}
		}
		elseif ($Property.Name -eq 'logAnalytics') {
			$bootstrapSettings.logAnalytics | foreach {
				if($sharedSettings.logAnalytics -eq $null){
					$logAnalytics=@() 
					$sharedSettings | Add-Member -MemberType NoteProperty -Value $logAnalytics -Name 'logAnalytics'
				}
				$sharedSettings.logAnalytics += $_
			}
		}
		elseif ($Property.Name -eq 'keyVaults') {
			$bootstrapSettings.keyVaults.list | foreach {
				if($sharedSettings.keyVaults -eq $null){
					$keyVaults=new-object psobject
					$sharedSettings | Add-Member -MemberType NoteProperty -Value $keyVaults -Name 'keyVaults'
					
					$list = @() 
					$sharedSettings.keyVaults | Add-Member -MemberType NoteProperty -Value $list -Name 'list'
				}
				
				$sharedSettings.keyVaults.list += $_
			}
		}
	}
}
		
function Add-DatabaseServers {
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
	
	$settings.databaseServers | foreach {
		$currentServer = $_
		$currentType = $currentServer.type
		$deploySettings = $currentServer.deploy | where { $_.env -eq $environmentName }  
		$deployEnabled = $false
		if ($deploySettings -ne $null) {
			$deployEnabled = $deploySettings[0].enabled
		}
		
		if ($deployEnabled -eq $true)
		{
			$adGroup = Add-SqlDatabaseServer -server $currentServer -Settings $settings -conventions $conventions -EnvironmentName $environmentName
		}
		else
		{
			Write-Host "Skipping database server creation for type:$currentType and deployEnabled:$deployEnabled"
		}
	}
	
	return $true
}

function Add-SqlDatabaseServer {

	Param(
		[Parameter(Mandatory=$true,HelpMessage="Server")]
		[psobject]$server,
		[Parameter(Mandatory=$true,HelpMessage="Settings")]
		[psobject]$settings,
		[Parameter(Mandatory=$true,HelpMessage="Conventions")]
		[psobject]$conventions,
		[Parameter(Mandatory=$true,HelpMessage="EnvironmentName")]
		[string]$environmentName
	)
	
	Write-Host ""
	Write-Host "[Add-DatabaseServer]"
	Write-Host ""
	
	$deploySettings = $currentServer.deploy | where { $_.env -eq $environmentName }  
	$kvKey = $deploySettings[0].kvKey
	Write-Host " - kvKey is:$kvKey"
	
	$devOpsKeyVault = $bootstrapSettings.keyVaults.list | where { $_.type -eq $deploySettings[0].kvKey }
	$devOpsKeyVaultName = Format-ResourceName $devOpsKeyVault[0].name -EnvironmentName $environmentName -Conventions $conventions
	Write-Host " - devOpsKeyVaultName is:$devOpsKeyVaultName"
	
	$locationList = $deploySettings[0].locations.split(',')
	
	$locationList | foreach {
		$locationKey = $_
		
		$location = Get-LocationByKey -Key $locationKey -Conventions $conventions
		$locationName = $location.Name
		
		$resourceGroupName = Get-ResourceGroupName -Type $server.rgKey -Settings $settings -Conventions $conventions -EnvironmentName $environmentName -LocationKey $deploySettings[0].location
		$serverName = Format-ResourceName $server.serverName -EnvironmentName $environmentName -Conventions $conventions -LocationKey $locationKey

		# Show randomized variables
		Write-Host ""
		Write-host "db creation for serverName:" $serverName
		Write-Host ""
		Write-host " - environmentName is" $environmentName 
		Write-host " - Resource group name is" $resourceGroupName 
		Write-host " - devOpsKeyVaultName is" $devOpsKeyVaultName 
		
		$databaseId = az sql server show --name $serverName --resource-group $resourceGroupName --query id --output TSV
		Reset-UI
		
		if ($databaseId -eq $null) {
			# Set variables for your server and database
			$adminLogin = "Admin$(Get-Random)"
			$password = (New-Guid).Guid
			
			Write-host "adminLogin is" $adminLogin 
			Write-host "password is" $password

			$sqlAdminLoginSecretKeyName = $server.sqlAdminLoginSecretKeyName -Replace "{LocationKey}", $locationKey
			$sqlAdminPasswordSecretKeyName = $server.sqlAdminPasswordSecretKeyName -Replace "{LocationKey}", $locationKey

			Write-host "sqlAdminLoginSecretKeyName is" $sqlAdminLoginSecretKeyName 
			Write-host "sqlAdminPasswordSecretKeyName is" $sqlAdminPasswordSecretKeyName
			
			az keyvault secret set --name $sqlAdminLoginSecretKeyName --value $adminLogin --vault-name $devOpsKeyVaultName
			az keyvault secret set --name $sqlAdminPasswordSecretKeyName --value $password --vault-name $devOpsKeyVaultName
			
			## Create a server with a system wide unique server name
			Write-host "Creating database server..."
			
			az sql server create --admin-password $password `
								 --admin-user $adminLogin `
								 --name $serverName `
								 --resource-group $resourceGroupName `
								 --location $locationName `
								 --assign-identity
		}
		else
		{
			Write-host "skipping db server create already exists with name:$serverName"
		}

		if ($deploySettings[0].adminRoleGroup -ne '')
		{
			$adminRoleGroup = $deploySettings[0].adminRoleGroup
			Write-Host ""
			Write-host "Configuring ad admin for the server to group: $adminRoleGroup" 
		
			$adGroupName = Get-ADGroupName -Type $deploySettings[0].adminRoleGroup -Settings $settings -Conventions $conventions -Environment $environmentName
			$groupId = az ad group show --group $adGroupName --query objectId --output tsv

			$adminList = az sql server ad-admin list --resource-group $resourceGroupName `
									  --server $serverName
			
			$adminGroup | where { $_.objectId -eq $groupId } 						  
									  
			az sql server ad-admin list --resource-group $resourceGroupName `
									  --server $serverName
									  
			if ($adminGroup -ne $null) {
				Write-Host "Skipping assignment as group already is already assigned admin to the server"
			}
			else {
				az sql server ad-admin create --display-name $adGroupName `
									  --object-id $groupId `
									  --resource-group $resourceGroupName `
									  --server $serverName
			}
		}

		# Create a server firewall rule that allows access from the specified IP range
		if ($deploySettings[0].ipAccessType -ne $null)
		{
			$ipRangeEnabled = $false
			
			$ipAccessDefinition = $conventions.ipAccess | where { $_.type -eq $deploySettings[0].ipAccessType }
			
			if ($ipAccessDefinition -ne $null) {
				# The ip address range that you want to allow to access your server 
				$startIp = $ipAccessDefinition[0].ipRangeStart
				$endIp = $ipAccessDefinition[0].ipRangeEnd
				$ipRangeEnabled = $ipAccessDefinition[0].ipRangeEnabled
			}
			
			if ($ipRangeEnabled -eq $true) {
				$ruleName = $server.defaultFWRuleName
				Write-Host ""
				Write-host "Configuring firewall rule: $ruleName for server: $serverName..."
				Write-host " - startIp is" $startIp 
				Write-host " - endIp is" $endIp 
				
				$ruleId = az sql server firewall-rule show --name $server.defaultFWRuleName --resource-group $resourceGroupName --server $serverName --query id --output TSV
				
				if ($ruleId -eq $null) {
					az sql server firewall-rule create --end-ip-address $endIp `
											   --name $ruleName `
											   --resource-group $resourceGroupName `
											   --server $serverName `
											   --start-ip-address $startIp
				}
				else {
					az sql server firewall-rule update --end-ip-address $endIp `
											   --name $ruleName `
											   --resource-group $resourceGroupName `
											   --server $serverName `
											   --start-ip-address $startIp
				}
			}
			
		}
	}
}


$bootstrapSettingsFile = '..\bootstrap-settings.json'
$bootStrapSettings = ( Get-Content -Raw $bootstrapSettingsFile | Out-String | ConvertFrom-Json )

Reset-UI

if ($bootStrapSettings -eq $null)
{
	Write-Host "error loading the bootstrap settings file - quitting process"
	return $false
}

$sharedSettingsFile = '..\shared-settings.json'
$sharedSettings = ( Get-Content -Raw $sharedSettingsFile | Out-String | ConvertFrom-Json )

Reset-UI

if ($sharedSettings -eq $null)
{
	Write-Host "error loading the shared settings file - quitting process"
	return $false
}

$conventionsFile = '..\conventions.json'
$conventions = ( Get-Content -Raw $conventionsFile | Out-String | ConvertFrom-Json )

Reset-UI

if ($conventions -eq $null)
{
	Write-Host "error loading the conventions file - quitting process"
	return $false
}

AppendBootstrapSettings -BootstrapSettings $bootstrapSettings -SharedSettings $sharedSettings

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

# Create AD groups
$outcome = Add-ADGroups -Settings $sharedSettings -Conventions $conventions -Environment $EnvironmentName
if ($outcome -eq $false)
{
	Write-Host "[Add-ADGroups]Quitting process"
	return $false
	
}
Reset-UI
 
# Create Resource Groups plus roles
$outcome = Add-ResourceGroups -Settings $sharedSettings -Conventions $conventions -Environment $EnvironmentName
if ($outcome -eq $false)
{
	Write-Host "[Add-ResourceGroups]Quitting process"
	return $false
	
}
Reset-UI

# Create Database Servers workspaces
$outcome = Add-DatabaseServers -Settings $sharedSettings -Conventions $conventions -Environment $EnvironmentName

if ($outcome -eq $false)
{
	Write-Host "[Add-DatabaseServers]Quitting process"
	return $false
}
Reset-UI

Write-Host ""
Write-Host "All done"
