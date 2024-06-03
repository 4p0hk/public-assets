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

# Initialize an array to hold the user IDs
$userIDsToOutput = @()

# Loop through each line in the registration details CSV
foreach ($user in $registrationDetails) {
    # Split the methodsRegistered column into an array of methods
    $methods = $user.methodsRegistered -split "\|"
    $methods = $methods.Trim() # Remove leading and trailing spaces from each method
    
    # Check if there is at least one allowed method
    $hasAllowedMethod = $methods | Where-Object { $_ -in $allowedMethods }

    # If there are no allowed methods, add the user ID to the results
    if ($hasAllowedMethod.Count -eq 0) {
        $userID = ($userIDs | Where-Object { $_.emailAddress -eq $user.emailAddress }).userID
        if ($userID) {
            $userIDsToOutput += $userID
        }
    }
}

# Export the user IDs to a new CSV file
$userIDsToOutput | Export-Csv -Path $outputPath -NoTypeInformation -Force

Write-Host "Script completed. Check the output at $outputPath"
