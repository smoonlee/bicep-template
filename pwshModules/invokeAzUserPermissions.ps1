function Invoke-AzUserPermissionCheck {

    param (
        [string] $targetScope,
        [string] $entraIdTenantGroupId,
        [string] $entraIdSubscriptionGroupId,
        [string] $azUserAccountId

    )
    Write-Output `r "[Function: invokeAzUserPermissionCheck]"
    $azUserAccountFriendlyName = az ad signed-in-user show --query 'userPrincipalName' -o tsv

    # Check Entra Id Group for Tenant Scope
    if ($targetScope -eq 'tenant') {
        $entraIdGroupFriendlyName = az ad group show --group $entraIdTenantGroupId --query 'displayName' -o tsv
        Write-Output "> Checking Entra Id Role Assignment at Scope '/' for Tenant Group [$entraIdGroupFriendlyName]"

        $entraIdGroupRoleAssignment = (az role assignment list --scope '/' | ConvertFrom-Json | Where-Object { $_.principalId -eq $entraIdTenantGroupId }).roleDefinitionName

        # Check Tenant Level Role Assignment, For Entra Id Security Group for RBAC 'Owner'
        if (!(az role assignment list --scope '/' | ConvertFrom-Json | Where-Object { $_.principalId -eq $entraIdTenantGroupId -and $_.roleDefinitionName -eq 'Owner' })) {
            Write-Warning "> Entra Id Group [$entraIdGroupFriendlyName] not found, Please add user to the group before deploying."
            Write-Warning "> Please Ensure you have the correct permissions to add the user to the group [Owner] or [User Access Administrator]."
            Write-Output `r "az role assignment create  --scope '/' --role 'Owner' --assignee $entraIdTenantGroupId"

            break
        }

        # Check the User Account Id is in the Entra Id Group
        if (az role assignment list --scope '/' | ConvertFrom-Json | Where-Object principalId -like $entraIdTenantGroupId ) {
            Write-Output "> Entra Id Group [$entraIdGroupFriendlyName] Assignment Found with [$entraIdGroupRoleAssignment], Checking User Group Permissions"

            # Check the Entra Id Group for the azUserAccountId
            $entraIdTenantGroupMembers = az ad group member list --group $entraIdTenantGroupId --query '[].id' -o tsv

            if ($entraIdTenantGroupMembers -notcontains $azUserAccountId) {
                Write-Warning "> User [$azUserAccountFriendlyName] not Found in Entra Id Group [$entraIdGroupFriendlyName], Please add user to the group before deploying."
                Write-Warning "> Please Ensure you have the correct permissions to add the user to the group [Global Administrator] or [Groups Administrator]."
                Write-Output `r "az ad group member add --group $entraIdTenantGroupId --member-id $azUserAccountId"

                break
            }

            Write-Output "> User [$azUserAccountFriendlyName] Found in Entra Id Group [$entraIdGroupFriendlyName]."
        }
    }

    # Check User Role Assignment for Subscription Scope
    if ($targetScope -eq 'sub') {
        Write-Output "> Checking User [$azUserAccountFriendlyName] RBAC Assignment for '/subscriptions/$subscriptionId'"

        if ($entraIdSubscriptionGroupId) {
            $entraIdSubscriptionGroupFriendlyName = az ad group show --group $entraIdSubscriptionGroupId --query 'displayName' -o tsv
            Write-Output "> Checking User Assignment for Subscription Group [$entraIdSubscriptionGroupFriendlyName]"

            # Check the Entra Id Group for the azUserAccountId
            $entraIdGroupMembers = az ad group member list --group $entraIdSubscriptionGroupId --query '[].id' -o tsv
            $azUserAccountFriendlyName = az ad signed-in-user show --query 'userPrincipalName' -o tsv

            if ($entraIdGroupMembers -notcontains $azUserAccountId) {
                Write-Warning "> User [$azUserAccountFriendlyName] not Found in Entra Id Group [$entraIdSubscriptionGroupFriendlyName], Please add user to the group before deploying."
                Write-Warning "> Please Ensure you have the correct permissions to add the user to the group [Global Administrator] or [Groups Administrator]."
                Write-Output `r "az ad group member add --group $entraIdSubscriptionGroupId --member-id $azUserAccountId"

                break
            }

            Write-Output "> User [$azUserAccountFriendlyName] found in Entra Id Group [$entraIdSubscriptionGroupFriendlyName]."
        }

        if (!($entraIdSubscriptionGroupId)) {
            $azSubRoleAssignments = az role assignment list --scope "/subscriptions/$subscriptionId" | ConvertFrom-Json | Where-Object { $_.principalId -eq $azUserAccountId }
            if ($azSubRoleAssignments.principalId -notcontains $azUserAccountId) {
                Write-Warning "> User [$azUserAccountFriendlyName] not found at Subscription Scope, Please add user to the Subscription."
                Write-Warning "> Please Ensure you have the correct permissions to add the user to the group [Owner] or [User Access Administrator]."
                Write-Output `r "az role assignment create  --scope '/subscriptions/$subscriptionId' --assignee $azUserAccountId --role 'Owner'"

                break
            }

            $azUserRoleAssignment = (az role assignment list --scope "/subscriptions/$subscriptionId" | ConvertFrom-Json | Where-Object { $_.principalId -eq $azUserAccountId }).roleDefinitionName
            Write-Output "> User [$azUserAccountFriendlyName] found in Subscription Group with RBAC [$azUserRoleAssignment]. "
        }

    }
}
