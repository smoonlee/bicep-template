<#

#>

param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The subscription ID for the deployment.")]
    [ValidateSet('tenant', 'mg', 'group','sub')]
    [string]$targetScope = 'sub',

    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "The subscription ID for the deployment.")]
    [string]$subscriptionId,

    [Parameter(Mandatory = $true, Position = 2, HelpMessage = "The location where the deployment will occur.")]
    [ValidateSet(
        "eastus", "eastus2", "westus", "westus2",
        "northcentralus", "southcentralus", "centralus",
        "canadacentral", "canadaeast", "brazilsouth",
        "northeurope", "westeurope", "uksouth", "ukwest",
        "francecentral", "francesouth", "germanywestcentral",
        "germanynorth", "switzerlandnorth", "switzerlandwest",
        "norwayeast", "norwaywest", "eastasia", "southeastasia",
        "japaneast", "japanwest", "australiaeast",
        "australiasoutheast", "centralindia", "southindia",
        "westindia", "koreacentral", "koreasouth", "uaenorth",
        "uaecentral", "southafricanorth", "southafricawest"
    )][string]$location,
    [Parameter(Mandatory = $true, Position = 3, HelpMessage = "The environment type for the deployment. Valid values are 'prod', 'acc', 'test', 'dev'.")]
    [ValidateSet('prod', 'acc', 'test', 'dev')][string]$environmentType = 'dev',

    [Parameter(Mandatory = $false, Position = 4, HelpMessage = "The customer name")][string]$customerName,
    [Parameter(Mandatory = $false, Position = 5, HelpMessage = "The Project Name")][string]$projectName,

    [switch]$deploy
)

$scriptVersion = '1.0'
Write-Output "Azure Bicep Deployment Wrapper [$scriptVersion]"

# Bicep Variables
$deployGuid = (New-Guid).Guid

# Import PowerShell Function Scripts
Write-Output "> Importing PowerShell Function Script"
Get-ChildItem -Path $PSScriptRoot\pwshModules -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# Check for Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Azure CLI is not installed. Please install Azure CLI before running this script."
    exit
}

# Check Azure Bicep Version
$azBicepVersion = az bicep version --only-show-errors
Write-Output `r "> Azure Bicep Version: $($azBicepVersion)"

# Log into Azure
Write-Output "> Logging into Azure for $subscriptionId"
az config set core.login_experience_v2=off --only-show-errors
$azUserAccountId = az ad signed-in-user show --query 'id' -o tsv

Write-Output "> Setting subscription to $subscriptionId"
az account set --subscription $subscriptionId

# Functions
# NOTE: $iacEntraIdGroup is required for tenant level deployments, Please add user BEFORE deploying.
# NOTE: $iacEntraIdSubscriptionGroup is required for subscription level deployments, Please add user BEFORE deploying.
$entraIdTenantGroupId = '48fc6f15-758b-4528-9bf1-f4cf69bab83f' #sec-bicep-iac-deployment-rw
$entraIdSubscriptionGroupId = '5c8ce689-ec1d-4566-af24-1623ce59676d' # sec-builtwithcaffeine-azure-prod-owner | Members
Invoke-AzUserPermissionCheck -targetScope $targetScope -entraIdTenantGroupId $entraIdTenantGroupId -entraIdSubscriptionGroupId $entraIdSubscriptionGroupId -azUserAccountId $azUserAccountId

#checkAzPermissions -targetScope $targetScope -subscriptionId $subscriptionId -azUserAccountContext $azUserAccount -entraIdGroupName $iacEntraIdGroup
#checkRegionCapacity

Write-Output `r "Pre Flight Variable Validation"
Write-Output "Deployment Guid......: $deployGuid"
Write-Output "Location.............: $location"
Write-Output "Location Short Code..: $($locationShortCodes.$location)"
Write-Output "Environment..........: $environmentType"
Write-Output "Customer Name........: $customerName"
Write-Output "Project Name.........: $projectName"

if ($deploy) {
    $deployStartTime = Get-Date -Format 'HH:mm:ss'

    # Deploy Bicep Template
    $azDeployGuidLink = "`e]8;;https://portal.azure.com/#view/HubsExtension/DeploymentDetailsBlade/~/overview/id/%2Fsubscriptions%2F$subscriptionId%2Fproviders%2FMicrosoft.Resources%2Fdeployments%2Fiac-bicep-$deployGuid`e\iac-bicep-$deployGuid`e]8;;`e\"
    Write-Output `r "> Deployment [$azDeployGuidLink] Started at $deployStartTime"

    az deployment $targetScope create `
        --name iac-bicep-$deployGuid `
        --location $location `
        --template-file ./main.bicep `
        --parameters `
        deployGuid=$deployGuid `
        deployedBy=$azUserAccountId `
        subscriptionId=$subscriptionId `
        location=$location `
        locationShortCode=$($locationShortCodes.$location) `
        environmentType=$environmentType `
        customerName=$customerName `
        projectName=$projectName `
        --confirm-with-what-if `
        --output none

    $deployEndTime = Get-Date -Format 'HH:mm:ss'
    $timeDifference = New-TimeSpan -Start $deployStartTime -End $deployEndTime ; $deploymentDuration = "{0:hh\:mm\:ss}" -f $timeDifference
    Write-Output "> Deployment [iac-bicep-$deployGuid] Started at $deployEndTime - Deployment Duration: $deploymentDuration"
}