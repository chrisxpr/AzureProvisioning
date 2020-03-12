# Bootstrap Resources

The bootstrap resources are such that they should only need to be create once and more than likely can survive a clean up that you may perform for shared or environment specific resources.

# Identity and Access Management 

By considering IAM as the first concern.  Security, auditing and compliance can be baked in to all provisioning and resource access through the application as it progresses the various environments on the way to production.  Minimising the work to be done later as the project progresses.

At this stage though we only need to perform devops activities so for arguments sake let's assume we only need the  following group:

   * DevOps

Later as we progress through the other resources we will consider access from developers, testers and applications.
(Note this assumes that applications will have managed identity backed in for resource access where possible)
This brings us to the bootstrap-settings.json file that will be the container for all the configuration that we define for both devtest and production environments.  This file will later be consumed by the powershell modules to provision resources based on the respective settings.
```
"ad": {
		"groups" : [
			{
				"type":"devops",
				"name":"{prefix}devops",
				"deploy" : [
					{
						"env" : "devtest",
						"enabled" : "true",
						"contributors" : "devops"
					},
					{
						"env" : "prod",
						"enabled" : "true",
						"contributors" : "devops"
					}
				]
			}
		]
	}
```
The placeholder {prefix} is defined in the conventions.json file and allows you to define conventions for your own project.  Below is an extract from the sample file:
```
{
	"prefix" : "ma", -- application prefix
	"longPrefix" : "myapp", -- alternative long application prefix
	"defaultKeyPattern": "{prefix}-{keyName}-{environment}",  -- convention for storing key vault keys
	"locations" : [ -- locations for resources to be deployed to
		{
			"key" : "syd",
			"name" : "Australia East",
			"cloudKey" : "australiaeast",
			"isPrimary" : "true"
		},
		{
			"key" : "mel",
			"name" : "Australia SouthEast",
			"cloudKey" : "australiasoutheast",
			"isPrimary" : "false"
		}
	],
	"environments" : [ -- environments to be used to deploy resources
		{
			"key" : "local",
			"name" : "local"
		},
		{
			"key" : "dev",
			"name" : "dev"
		},
		{
			"key" : "uat",
			"name" : "uat"
		},
		{
			"key" : "devtest",
			"name" : "devtest",
			"isShared" : "true"
		},
		{
			"type" : "prod",
			"name" : "prod"
		}
	]
}
```
# Resource Groups 

Resources need to be placed somewhere, and also resource groups need to be located and secured.  As this the bootstrap phase the first resource group to be created will be a 'shared' resource group.  Since we have our devops AD groups we can also restrict access to the resource group accordingly.  Below is the extract from bootstrap-settings.json for the initial resource group creation:
```
"resourceGroups": [
		{
			"type" : "devtest-shared",
			"name" : "{prefix}-devtest-shared",
			"location": "syd",
			"deploy" : [
				{
					"env" : "devtest",
					"enabled" : "true",
					"contributors" : "devops"
				}
			]
		},
		{
			"type" : "prod-shared",
			"name" : "{prefix}-prod-shared",
			"location": "syd",
			"deploy" : [
				{
					"env" : "prod",
					"enabled" : "true",
					"contributors" : "devops"
				}
			]
		}
	],
```
# Log Analytics Workspaces

This is not normally something that would spring to mind as the third thing to create when starting infrastructure planning for a new project.  But with a security and compliance hat on, it means that all resources provisioned that support auditing, can start of life more compliant from day one which is very important.
```
"logAnalytics" : [
		{
			"type": "devtest-audit",
			"workspaceName": "law-{prefix}-audit-{environment}-{locationKey}",
			"sku": "Standard",
			"rgKey" : "devtest-shared",
			"metrics" : "AllMetrics",
			"location": "syd",
			"deploy" : [
					{
						"env" : "devtest",
						"enabled" : "true",
						"contributors" : "devops"
					}
			]
		},
		{
			"type": "prod-audit",
			"workspaceName": "law-{prefix}-audit-{environment}-{locationKey}",
			"sku": "Standard",
			"rgKey" : "prod-shared",
			"metrics" : "AllMetrics",
			"location": "syd",
			"deploy" : [
					{
						"env" : "prod",
						"enabled" : "true",
						"contributors" : "devops"
					}
				]
		}
	],
```
# DevOps Key vault

The final resource to create as part of the bootstrap phase is a devops key vault.  As we create resources and create keys, certificates and secrets we find we need somewhere to put them.  Without a key vault in place these items may have to be stored in non-ideal storage locations.

With this approach we now have a key vault that can only be access based on AD group membership with all audit logs being pushed to log analytics.  In addition as we start to configure devops pipelines we have a secure mechanism of injecting config into those to be created pipelines.
```
"keyVaults" : {
	"list" : [
		{
			"type"  : "devops",
			"name"  : "{longPrefix}-devops",
			"rgKey" : "devtest-shared",
			"workspaceType" : "devtest-audit",
			"diagnosticName" : "kv-diag",
			"deploy" : [
				{
					"env" : "devtest",
					"enabled" : "true",
					"defaultRoleGroups" : "",
					"adminRoleGroups" : "devops"
				}
			]
		},
		{
			"type"  : "devopsprod",
			"name"  : "{longPrefix}-devops-prod",
			"rgKey" : "prod-shared",
			"workspaceType" : "prod-audit",
			"diagnosticName" : "kv-diag",
			"deploy" : [
				{
					"env" : "devtest",
					"enabled" : "false",
					"defaultRoleGroups" : "",
					"adminRoleGroups" : "devops"
				}
			]
		}
	]
}
```
And that’s it for the bootstrap resources not very exciting yet but gives a bit of structure in place to move forward and create the shared resources based on app requirements.

# Deploying the bootstrap resources

Assumptions:
az cli installed  --> link
The AzureProvision module is installed.  --> link

To run
* 1 Update the conventions.json file with your preferred prefixes and location etc
* 2 Open a powershell commmand prompt
* 3  run az login to login to the desired azure subscription
* 4 Run the file 1-create-bootstrap-resources.ps1  specifiying the environment name devtest or prod
* 5 Check the output for completion.
* 6 Navigate to the azure portal to check resource creation

And we are now done with the bootstrap resources.

The next section will cover deploying the shared resources for your project.

