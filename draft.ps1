# Define input and output file paths
$inputFilePath = "C:\path\to\input.csv"
$outputFilePath = "C:\path\to\output.csv"

# Connect to Microsoft Graph
$clientId = "YOUR_CLIENT_ID"
$tenantId = "YOUR_TENANT_ID"
$scopes = "Group.Read.All, User.Read.All"

Connect-MgGraph -ClientId $clientId -TenantId $tenantId -Scopes $scopes

# Read the input CSV file containing group names
$groupNames = Import-Csv -Path $inputFilePath

# Initialize an array to store the output
$groupMemberships = @()

# Output the count of groups to be enumerated
Write-Output "Total groups to enumerate: $($groupNames.Count)"

# Process each group
foreach ($group in $groupNames) {
    Write-Output "Processing group: $($group.Name)"
    
    # Get the group details
    $groupDetails = Get-MgGroup -Filter "displayName eq '$($group.Name)'"
    
    if ($groupDetails.Count -eq 0) {
        Write-Output "Group '$($group.Name)' not found."
        continue
    }

    $groupId = $groupDetails.Id
    $members = Get-MgGroupMember -GroupId $groupId -All

    foreach ($member in $members) {
        try {
            $userDetails = Get-MgUser -UserId $member.Id -Property "mail"
            $groupMemberships += [pscustomobject]@{
                GroupName = $group.Name
                UserEmail = $userDetails.Mail
            }
        } catch {
            Write-Output "Unable to retrieve details for user: $($member.Id)"
        }
    }

    Write-Output "Finished processing group: $($group.Name)"
}

# Output the result to a CSV file
$groupMemberships | Export-Csv -Path $outputFilePath -NoTypeInformation

Write-Output "Completed processing all groups. Output written to $outputFilePath"

# Disconnect from Microsoft Graph
Disconnect-MgGraph