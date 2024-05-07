<#
MsGraph Cmdlets:

https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host?view=powershell-7.4
https://learn.microsoft.com/en-us/sharepoint/dev/sp-add-ins/replace-an-expiring-client-secret-in-a-sharepoint-add-in
https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.applications/remove-mgserviceprincipalpassword?view=graph-powershell-1.0
#>

# Install prereqs
Install-Module -Name PowerShellGet -Force -AllowClobber # ps native package management for adding more modules
Install-Module -Name Microsoft.Graph.Authentication # graph api module
Install-Module -Name Microsoft.Graph.Applications # graph api module

# Import MsGraph modules and connect to MsGraph
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Applications

# Start connection, with minimal scope
Connect-MgGraph Application.Read.All;Application.ReadWrite.All;Directory.Read.All;Directory.ReadWrite.All;Authentication

# Get the inputs from user
$AppClientID = Read-Host "Enter the Application Client ID to be rotated"
$KeyID = Read-Host "Enter the Secret ID to be rotated"

# Remove the expired Client Secret (example c92baac5-c486-4f58-8854-c0824eaa222b)
Remove-MgServicePrincipalPassword -ServicePrincipalId $servicePrincipalId -BodyParameter $KeyID

# Get/Set App ID and expiration
$endDate = (Get-Date).AddYears(1) # Set end date to 12 months from now
$app = Get-MgServicePrincipal -Filter "AppId eq '$AppClientID'" # prep the app client ID before setting
$objectId = $app.ObjectId # set the client ID

$base64secret = Add-MgServicePrincipalPassword -ObjectId $objectId -EndDate $endDate
Add-MgServicePrincipalKey -ObjectId $objectId -EndDate $endDate -Type Symmetric -Usage Verify -Value $base64secret.Value
Add-MgServicePrincipalKey -ObjectId $objectId -EndDate $endDate -Type Symmetric -Usage Sign -Value $base64secret.Value

[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($base64secret.Value))
$base64secret.EndDate # Print the end date.