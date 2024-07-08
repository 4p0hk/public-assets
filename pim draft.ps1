# Assuming you're getting the users with the command
$users = Find-MsIdUnprotectedUsersWithAdminRoles

# Process each user to convert DirectoryRoleAssignments to a string
$processedUsers = $users | ForEach-Object {
    # Convert DirectoryRoleAssignments to a comma-separated string
    $roles = $_.DirectoryRoleAssignments -join ', '
    
    # Create a new object with the converted property
    [PSCustomObject]@{
        UserPrincipalName = $_.UserPrincipalName
        DisplayName       = $_.DisplayName
        DirectoryRoleAssignments = $roles
        # Add other properties you need
    }
}

# Export the processed objects to CSV
$processedUsers | Export-Csv -Path 'path\to\your\output.csv' -NoTypeInformation
