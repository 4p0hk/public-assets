# Define the paths to the input CSV files
$registrationDetailsPath = "C:\path\to\your\registrationDetails.csv"
$userIDsPath = "C:\path\to\your\userIDs.csv"
$outputPath = "C:\path\to\your\output.csv"

# Read the CSV files into variables
$registrationDetails = Import-Csv -Path $registrationDetailsPath
$userIDs = Import-Csv -Path $userIDsPath

# Define the allowed registration methods
$allowedMethods = @(
    "Windows Hello For Business",
    "Microsoft Passwordless phone sign-in",
    "Software OATH token",
    "Microsoft Authenticator app (push notification)"
)

# Initialize an array to hold the results
$results = @()

# Loop through each line in the registration details CSV
foreach ($user in $registrationDetails) {
    # Check if the user's registration methods contain only allowed methods
    $methods = $user.methodsRegistered -split ";"
    $unwantedMethods = $methods | Where-Object { $_ -notin $allowedMethods }

    # If there are unwanted methods, add the user ID to the results
    if ($unwantedMethods.Count -gt 0) {
        $userID = ($userIDs | Where-Object { $_.emailAddress -eq $user.emailAddress }).userID
        $results += [PSCustomObject]@{
            UserID = $userID
            EmailAddress = $user.emailAddress
            UnwantedMethods = ($unwantedMethods -join "; ")
        }
    }
}

# Export the results to a new CSV file
$results | Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "Script completed. Check the output at $outputPath"
