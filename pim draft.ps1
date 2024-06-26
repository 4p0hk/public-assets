# Import the AzureAD module
Import-Module AzureAD

# Connect to Azure AD
Connect-AzureAD

# Define input and output file paths
$inputFile = ".\pimusers.csv"
$outputFile = ".\pimuserswitheligibility.csv"

# Read the input CSV file
$userList = Import-Csv -Path $inputFile

# Initialize an array to store the results
$results = @()

# Iterate through each user in the input CSV
foreach ($user in $userList) {
    $userUPN = $user.UPN

    # Get the user object
    $userObject = Get-AzureADUser -Filter "UserPrincipalName eq '$userUPN'"

    if ($userObject -ne $null) {
        # Get the user's eligible PIM roles
        $eligibleRoles = Get-AzureADMSPrivilegedRoleAssignment -Filter "principalId eq '$($userObject.ObjectId)' and roleAssignmentState eq 'Eligible'"

        # Add the roles to the results
        foreach ($role in $eligibleRoles) {
            $results += [PSCustomObject]@{
                UPN = $userUPN
                RoleId = $role.RoleId
                RoleDefinitionName = $role.RoleDefinitionName
            }
        }
    }
    else {
        # If the user is not found, add a record with no roles
        $results += [PSCustomObject]@{
            UPN = $userUPN
            RoleId = "N/A"
            RoleDefinitionName = "User not found"
        }
    }
}

# Export the results to a CSV file
$results | Export-Csv -Path $outputFile -NoTypeInformation

Write-Host "Eligible PIM roles have been exported to $outputFile"
