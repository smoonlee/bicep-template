<#

#>

param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The subscription ID for the deployment.")]
    [ValidateSet('tenant','sub')]
    [string]$targetScope,

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
Get-ChildItem -Path $PSScriptRoot\scripts -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# Check for Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Azure CLI is not installed. Please install Azure CLI before running this script."
    exit
}

# Check Azure Bicep Version
$azBicepVersion = az bicep version
Write-Output "> Azure Bicep Version: $($azBicepVersion)"

# Log into Azure
Write-Output "> Logging into Azure for $subscriptionId"
az config set core.login_experience_v2=off
#az login --use-device-code --output none
$azUserAccount = az ad signed-in-user show | ConvertFrom-Json | ConvertTo-Json

Write-Output "> Setting subscription to $subscriptionId"
az account set --subscription $subscriptionId

# Functions
$iacEntraIdGroup = ''
checkAzPermissions -targetScope $targetScope -subscriptionId $subscriptionId -azUserAccountContext $azUserAccount -entraIdGroupName $iacEntraIdGroup
checkRegionCapacity

Write-Output `r "Pre Flight Variable Validation"
Write-Output "Deployment Guid......: $deployGuid"
Write-Output "Location.............: $location"
Write-Output "Location Short Code..: $($locationShortCodes.$location)"
Write-Output "Environment..........: $environmentType"
Write-Output "Customer Name........: $customerName"
Write-Output "Project Name.........: $projectName"

if ($deploy) {
    $deployStartTime = Get-Date -Format 'HH:mm:ss'
    Write-Output `r "> Deployment [iac-bicep-$deployGuid] Started at $deployStartTime"

    az deployment $targetScope create `
        --name iac-bicep-$deployGuid `
        --location $location `
        --template-file ./main.bicep `
        --parameters `
        deployGuid=$deployGuid `
        deployedBy=$($azUserAccount.user.name) `
        subscriptionId=$subscriptionId `
        location=$location `
        locationShortCode=$($locationShortCodes.$location) `
        environmentType=$environmentType `
        customerName=$customerName `
        projectName=$projectName `
        --confirm-with-what-if `
        --output none

    $deployEndTime = Get-Date -Format 'HH:mm:ss'
    $timeDifference = New-TimeSpan -Start $deployStartTime -End $deployEndTime ;  $deploymentDuration = "{0:hh\:mm\:ss}"-f $timeDifference
    Write-Output "> Deployment [iac-bicep-$deployGuid] Started at $deployEndTime - Deployment Duration: $deploymentDuration"
}