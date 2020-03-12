$targetRoot = "C:\Program Files\WindowsPowerShell\Modules"
$targetFolder = "AzureBootstrap"
$targetPath = $targetRoot + "\" + $targetFolder

$sourcePath = $pwd.Path + "\AzureBootstrap\*"
Write-Host "Source Path: $sourcePath"
Write-Host "Target Path: $targetPath"

if ((Test-Path $targetPath -PathType Container) -eq $false){
	New-Item -Path $targetRoot -Name $targetFolder -ItemType "directory"
}

Copy-Item $sourcePath -Destination $targetPath -Recurse
Write-Host "Source Files copied to targetPath"

Get-Module -ListAvailable
