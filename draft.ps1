# Import the Microsoft.Graph module
Import-Module Microsoft.Graph

# Function to get MS Graph Access Token using Device Code flow
function Get-MSGraphTokenDeviceCode {
    Write-Host "Please authenticate using the provided device code..."
    $tokenResponse = Get-MgGraphAuthenticationToken -DeviceCode -Scopes "User.Read.All"
    return $tokenResponse
}

# Function to get user details
function Get-UserJobTitle {
    param (
        [string]$upn
    )

    try {
        $user = Get-MgUser -UserId $upn -ErrorAction Stop
        return @{
            userPrincipalName = $user.UserPrincipalName
            jobTitle = $user.JobTitle
        }
    } catch {
        Write-Error "Failed to get details for user $upn: $_"
        return @{
            userPrincipalName = $upn
            jobTitle = "Error fetching details"
        }
    }
}

# Input and Output CSV file paths
$inputCSV = "input.csv"
$outputCSV = "output.csv"

# Check if input CSV exists
if (-Not (Test-Path -Path $inputCSV)) {
    Write-Error "Input CSV file not found!"
    exit
}

# Read the input CSV
$userUPNs = Import-Csv -Path $inputCSV

# Authenticate and get token
Get-MSGraphTokenDeviceCode

# Initialize an array to hold the results
$results = @()

# Loop through each userPrincipalName and fetch job title
foreach ($user in $userUPNs) {
    $upn = $user.userPrincipalName
    $userDetails = Get-UserJobTitle -upn $upn
    $results += New-Object PSObject -Property $userDetails
}

# Export the results to a new CSV file
$results | Export-Csv -Path $outputCSV -NoTypeInformation

Write-Host "User details exported to $outputCSV"
