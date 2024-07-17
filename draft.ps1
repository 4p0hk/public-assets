# Define input and output file paths
$inputFilePath = "C:\path\to\input.csv"
$outputFilePath = "C:\path\to\output.csv"
$logFilePath = "C:\path\to\log.csv"

# Connect to Microsoft Graph
$clientId = "YOUR_CLIENT_ID"
$tenantId = "YOUR_TENANT_ID"
$scopes = "Group.Read.All, User.Read.All"

Connect-MgGraph -ClientId $clientId -TenantId $tenantId -Scopes $scopes

# Read the input CSV file containing group names
$groupNames = Import-Csv -Path $inputFilePath

# Initialize arrays to store the output and log
$groupMemberships = @()
$groupSummaries = @()

# Output the count of groups to be enumerated
Write-Output "Total groups to enumerate: $($groupNames.Count)"

# Process each group
foreach ($group in $groupNames) {
    Write-Output "Processing group: $($group.Name)"
    
    # Get the group details
    $groupDetails = Get-MgGroup -Filter "displayName eq '$($group.Name)'"
    
    if ($groupDetails.Count -eq 0) {
        Write-Output "Group '$($group.Name)' not found."
        $groupSummaries += [pscustomobject]@{
            GroupName = $group.Name
            MemberCount = 0
        }
        continue
    }

    $groupId = $groupDetails.Id
    $members = Get-MgGroupMember -GroupId $groupId -All
    $memberCount = 0

    foreach ($member in $members) {
        try {
            $userDetails = Get-MgUser -UserId $member.Id -Property "mail"
            $groupMemberships += [pscustomobject]@{
                GroupName = $group.Name
                UserEmail = $userDetails.Mail
            }
            Write-Output "Processed user: $($userDetails.Mail) from group: $($group.Name)"
            $memberCount++
        } catch {
            Write-Output "Unable to retrieve details for user: $($member.Id)"
        }
    }

    $groupSummaries += [pscustomobject]@{
        GroupName = $group.Name
        MemberCount = $memberCount
    }

    Write-Output "Finished processing group: $($group.Name)"
}

# Output the result to CSV files
$groupMemberships | Export-Csv -Path $outputFilePath -NoTypeInformation
$groupSummaries | Export-Csv -Path $logFilePath -NoTypeInformation

Write-Output "Completed processing all groups. Output written to $outputFilePath and $logFilePath"

# Disconnect from Microsoft Graph
Disconnect-MgGraph