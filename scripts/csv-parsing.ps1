# Import required modules
Import-Module Microsoft.Graph.Identity.SignIns
Import-Module Microsoft.Graph.Users

# Define accepted MFA methods
$acceptedMethods = @("MicrosoftAuthenticator", "Fido2", "WindowsHelloForBusiness")

# Read the input CSV file containing UPNs
$inputCsv = "path\to\input.csv"
$outputCsv = "path\to\non_compliant_users.csv"
$userUpns = Import-Csv -Path $inputCsv

# Initialize an array to store non-compliant users
$nonCompliantUsers = @()

# Function to get the MFA methods for a user
function Get-MfaMethods($userUpn) {
    try {
        $user = Get-MgUser -UserId $userUpn
        $mfaMethods = Get-MgUserAuthenticationMethod -UserId $user.Id
        return $mfaMethods
    } catch {
        Write-Host "Failed to retrieve MFA methods for $userUpn"
        return $null
    }
}

# Process each user in the input CSV
foreach ($user in $userUpns) {
    $upn = $user.UPN
    Write-Host "Processing user: $upn"

    $mfaMethods = Get-MfaMethods -userUpn $upn
    if ($mfaMethods -eq $null) {
        Write-Host "No MFA methods found for $upn"
        $nonCompliantUsers += [pscustomobject]@{
            UPN = $upn
            Reason = "No MFA methods found"
        }
    } else {
        $isCompliant = $false
        foreach ($method in $mfaMethods) {
            if ($acceptedMethods -contains $method.MethodType) {
                $isCompliant = $true
                break
            }
        }

        if (-not $isCompliant) {
            Write-Host "$upn is non-compliant"
            $nonCompliantUsers += [pscustomobject]@{
                UPN = $upn
                Reason = "No accepted MFA methods"
            }
        } else {
            Write-Host "$upn is compliant"
        }
    }
}

# Export non-compliant users to an output CSV file
$nonCompliantUsers | Export-Csv -Path $outputCsv -NoTypeInformation
Write-Host "Non-compliant users have been exported to $outputCsv"
