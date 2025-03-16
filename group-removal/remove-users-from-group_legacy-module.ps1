# Set the path to the CSV file and the log files (initializing here for error handling)
$csvPath = "C:\Users\4p0hk\Git\other\public-assets\group-removal\users.csv"
$logPath = "C:\Users\4p0hk\Git\other\public-assets\group-removal\logs\remove_users_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$errorLogPath = "C:\Users\4p0hk\Git\other\public-assets\group-removal\logs\remove_users_error_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Define the group name (change this to the name of your group)
$groupName = "SMS_EXCLUSION_DEV"

# Function to log errors in CSV format
function Log-Error {
    param (
        [string]$userPrincipalName,
        [string]$errorMessage,
        [string]$category
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = [PSCustomObject]@{
        LogType            = "Failure"
        Category           = $category
        UserPrincipalName  = $userPrincipalName
        Message            = "$timestamp - ERROR: $errorMessage"
    }
    $logEntry | Export-Csv -Path $logPath -Append -NoTypeInformation
    Write-Output $logEntry.Message
}

# Function to log success or info messages in CSV format
function Log-Message {
    param (
        [string]$userPrincipalName,
        [string]$message,
        [string]$category
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = [PSCustomObject]@{
        LogType            = "Success"
        Category           = $category
        UserPrincipalName  = $userPrincipalName
        Message            = "$timestamp - $message"
    }
    $logEntry | Export-Csv -Path $logPath -Append -NoTypeInformation
    Write-Output $logEntry.Message
}

# Function to log informational messages
function Log-Info {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = [PSCustomObject]@{
        LogType            = "Info"
        Category           = "Info"
        UserPrincipalName  = ""
        Message            = "$timestamp - $message"
    }
    $logEntry | Export-Csv -Path $logPath -Append -NoTypeInformation
    Write-Output $logEntry.Message
}

# Function to check if a module is available
function Check-Module {
    param (
        [string]$moduleName
    )
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        $errorMessage = "The required module '$moduleName' is not installed. Exiting script."
        Log-Error "" $errorMessage "Module Check"
        throw $errorMessage
    }
}

# Check if the AzureAD module is installed
Check-Module -moduleName "AzureAD"

# Check if the input CSV file exists
if (-not (Test-Path -Path $csvPath)) {
    $errorMessage = "Input CSV file '$csvPath' does not exist. Exiting script."
    Log-Error "" $errorMessage "File Check"
    throw $errorMessage
}

# Try to create the output log file (this will check for permissions and path validity)
try {
    # Create an empty log file with headers if it doesn't exist
    if (-not (Test-Path -Path $logPath)) {
        $headers = "LogType,Category,UserPrincipalName,Message"
        Add-Content -Path $logPath -Value $headers
    }
}
catch {
    $errorMessage = "Unable to create or write to the log file at '$logPath'. Exiting script."
    Log-Error "" $errorMessage "File Check"
    throw $errorMessage
}

# Import the AzureAD module
Import-Module AzureAD

# Authenticate to Azure AD
$login = Connect-AzureAD

# Retrieve the group ID based on the group name
$group = Get-AzureADGroup -SearchString $groupName
if ($group -eq $null) {
    $errorMessage = "Group '$groupName' not found in Azure AD. Exiting script."
    Log-Error "" $errorMessage "Group Not Found"
    throw $errorMessage
}
$groupId = $group.ObjectId
Log-Info "Found group '$groupName' with ObjectId: $groupId"

# Validate the CSV file format
try {
    # Read the first row of the CSV file
    $firstRow = Import-Csv -Path $csvPath | Select-Object -First 1

    # Check if the UserPrincipalName column exists
    if (-not $firstRow.PSObject.Properties.Name -contains 'UserPrincipalName') {
        $errorMessage = "CSV file format error: Missing 'UserPrincipalName' column. Exiting script."
        Log-Error "" $errorMessage "CSV Format Error"
        throw $errorMessage
    }

    Log-Info "CSV file format validated successfully."
}
catch {
    $errorMessage = "Error validating CSV file: $_"
    Log-Error "" $errorMessage "CSV Validation Error"
    throw $errorMessage
}

try {
    # Read users from the CSV file
    $users = Import-Csv -Path $csvPath

    # Total number of users
    $totalUsers = $users.Count
    Log-Info "Starting the process to remove $totalUsers users from the group."

    $counter = 0
    foreach ($user in $users) {
        $userPrincipalName = $user.UserPrincipalName

        # Log the UPN to check if it's being read correctly
        Log-Message $userPrincipalName "Processing user: $userPrincipalName" "Processing"

        if (-not $userPrincipalName) {
            Log-Error $userPrincipalName "UserPrincipalName is null or empty. Skipping this user." "Null/Empty UPN"
            continue
        }

        try {
            # Get the user object
            $azureAdUser = Get-AzureADUser -ObjectId $userPrincipalName

            if (-not $azureAdUser) {
                Log-Error $userPrincipalName "User '$userPrincipalName' not found in Azure AD." "User Not Found"
                continue
            }

            # Check if the user is a member of the group
            $isMember = Get-AzureADGroupMember -ObjectId $groupId -All $true | Where-Object { $_.ObjectId -eq $azureAdUser.ObjectId }
            if (-not $isMember) {
                Log-Error $userPrincipalName "User '$userPrincipalName' is not a member of the group." "Not a Member"
                continue
            }

            # Remove the user from the group
            Remove-AzureADGroupMember -ObjectId $groupId -MemberId $azureAdUser.ObjectId

            # Log success
            $counter++
            Log-Message $userPrincipalName "Successfully removed $userPrincipalName from the group. ($counter/$totalUsers)" "Removal"
        }
        catch {
            # Log error
            Log-Error $userPrincipalName "Failed to remove $userPrincipalName from the group. Error: $_" "Removal Error"
        }
    }

    Log-Info "Process completed. $counter out of $totalUsers users were successfully removed from the group."
}
catch {
    Log-Error "" "An unexpected error occurred. Error: $_" "Unexpected Error"
}