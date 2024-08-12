function checkAzPermissions {
   param(
      [parameter(Mandatory = $true)][string]$targetScope,
      [parameter(Mandatory = $true)][string]$subscriptionId,
      [parameter(Mandatory = $true)][string]$azUserAccountContext,
      [parameter(Mandatory = $false)][string]$entraIdGroupName
   )

   #
   Write-Output `r "[Function: checkAzPermissions]"

   # Convert the JSON string to a PowerShell object
   $azUserAccountContextObject = $azUserAccountContext | ConvertFrom-Json
   $tenantId = az account show --query 'tenantId' --output 'tsv'


   if ($targetScope -eq 'tenant') {
      Write-Output "> Checking Azure RBAC Permissions for [$($azUserAccountContextObject.userPrincipalName)] on Tenant [$tenantId]"

      if (!([string]::IsNullOrEmpty($entraIdGroupName))) {
         Write-Output "> Checking Azure RBAC Group Assignment for [$($azUserAccountContextObject.userPrincipalName)] in the [$entraIdGroupName] group"
         $iacRBACGroupAssignment = az ad group member list --group $entraIdGroupName --query [].id -o tsv

         if ($iacRBACGroupAssignment -notcontains $azUserAccountContextObject.id) {
            Write-Output ""
            Write-Warning "> [$($azUserAccountContextObject.userPrincipalName)] needs to be a member of the [$entraIdGroupName] group"
            Exit 1
         }

         if ($iacRBACGroupAssignment -contains $azUserAccountContextObject.id) {
            Write-Output ""
            Write-Output "> [$($azUserAccountContextObject.userPrincipalName)] is a member of the [$entraIdGroupName] group"
            return
         }
      }

      $azRoleAssignment = az role assignment list --scope "/"--assignee $azUserAccountContextObject.userPrincipalName --output json --query '[].{roleDefinitionName:roleDefinitionName, scope:scope}' | ConvertFrom-Json
      if (!($azRoleAssignment.roleDefinitionName -eq 'Owner')) {
         Write-Output ""
         Write-Warning "[$($azUserAccountContextObject.userPrincipalName)] needs to have Owner permissions on Tenant [$tenantId]"
         Write-Output "Please run the following AzCLI: az role assignment create --role Owner --assignee $($azUserAccountContextObject.id) --scope /"
         Exit 1
      }

      if ($azRoleAssignment.roleDefinitionName -eq 'Owner') {
         Write-Output ""
         Write-Output "> [$($azUserAccountContextObject.userPrincipalName)] has Owner permissions on Tenant [$tenantId]"
         return
      }
   }

   if ($targetScope -eq 'sub') {
      Write-Output "> Checking Azure RBAC Permissions for [$($azUserAccountContextObject.userPrincipalName)] on Subscription [$subscriptionId]"
      $azRoleAssignment = az role assignment list --subscription $subscriptionId --assignee $azUserAccountContextObject.userPrincipalName --output json --query '[].{roleDefinitionName:roleDefinitionName, scope:scope}' | ConvertFrom-Json
      if (!($azRoleAssignment.roleDefinitionName -eq 'Owner')) {
         Write-Output ""
         Write-Warning "> [$($azUserAccountContextObject.userPrincipalName)] needs to have Owner permissions on Subscription [$subscriptionId]"
         Write-Output "Please run the following AzCLI: az role assignment create --role Owner --assignee $($azUserAccountContextObject.id) --scope /subscriptions/$subscriptionId"
         Exit 1
      }

      if ($azRoleAssignment.roleDefinitionName -eq 'Owner') {
         Write-Output ""
         Write-Output "> [$($azUserAccountContextObject.userPrincipalName)] has Owner permissions on Subscription [$subscriptionId]"
         return
      }
   }
}