# Import MsGraph modules and connect to MsGraph
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Applications
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Application.Read.All Application.ReadWrite.All Directory.Read.All Directory.ReadWrite.All"

$app = Get-MgApplication -Filter "DisplayName eq 'secret-rotation-testapp'"

Write-Output "application name: " $app.DisplayName
Write-Output "application id: " $app.Id

Remove-MgApplicationPassword -ApplicationId $app.Id -KeyId $passwordCredential.KeyId
