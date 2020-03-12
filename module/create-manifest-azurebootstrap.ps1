$manifest = @{
    Path              = '.\AzureBootstrap\AzureBootstrap.psd1'
    RootModule        = 'AzureBootstrap.psm1' 
    Author            = 'Christian Farinella'
}
New-ModuleManifest @manifest
