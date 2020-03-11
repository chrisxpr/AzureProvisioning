# AzureProvisioning
When you start to think about a new project, building out the infrastructure is a bit of an iterative and sometimes tedious process.  Possibly that follows a few loops, trial and error then stabilises into a pattern and way forward.  

This project aims to provide some direction on how to build out your infrastructure in a repeatable way, that not only supports code deployment and configuration, but security and compliance from the outset.  Right at the very beginning there are decisions to be made but not all need to be addressed immediately.  Therefore it is wise to break things down a little.  I like to think about infrastructure deployment in three stages:

	• Bootstrap Resources
		○ Think IAM and logical grouping of resources
	• Shared Resources
		○ Think DNS, Email, Storage, caching, service buses, database servers, container registries
	• Environment Resources
		○ Think resources specific to an environment, app services, functions, containers, gateways and configuration

This project will progress through deploying each of the three stages listed above in a consistent and repeatable manner through the use of rich suite of azure cli commands. 
