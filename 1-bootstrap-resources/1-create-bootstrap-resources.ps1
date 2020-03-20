param (
	[Parameter(Mandatory=$true)] 
	[ValidateSet("devtest","prod")]
	[string] $EnvironmentName
)

Import-Module AzureBootstrap

$settingsFile = '..\bootstrap-settings.json'
$settings = ( Get-Content -Raw $settingsFile | Out-String | ConvertFrom-Json )

Reset-UI

if ($settings -eq $null)
{
	Write-Host "error loading the settings file - quitting process"
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
$outcome = Add-ADGroups -Settings $settings -Conventions $conventions -Environment $EnvironmentName
if ($outcome -eq $false)
{
	Write-Host "[Add-ADGroups]Quitting process"
	return $false
	
}
Reset-UI
 
# Create Resource Groups plus roles
$outcome = Add-ResourceGroups -Settings $settings -Conventions $conventions -Environment $EnvironmentName
if ($outcome -eq $false)
{
	Write-Host "[Add-ResourceGroups]Quitting process"
	return $false
}
Reset-UI

# Create Log Analytics workspaces
$outcome = Add-LogAnalyticsWorkspaces -Settings $settings -Conventions $conventions -Environment $EnvironmentName

if ($outcome -eq $false)
{
	Write-Host "[Add-LogAnalyticsWorkspaces]Quitting process"
	return $false
}
Reset-UI

# Create Key Vaults
$outcome = Add-KeyVaults -Settings $settings -Conventions $conventions -Environment $EnvironmentName

if ($outcome -eq $false)
{
	Write-Host "[Add-KeyVaults]Quitting process"
	return $false
}
Reset-UI

Write-Host ""
Write-Host "All done"
