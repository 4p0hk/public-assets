Install-Module AzureAD
Install-module AzureADPreview

$clientId = 'XX' # sharepoint add-in Client ID <---- user sets this
Connect-AzureAD 

$endDate = (Get-Date).AddYears(1)
$app = Get-AzureADServicePrincipal -Filter "AppId eq '$clientId'"
$objectId = $app.ObjectId

$base64secret = New-AzureADServicePrincipalPasswordCredential -ObjectId $objectId -EndDate $endDate
New-AzureADServicePrincipalKeyCredential -ObjectId $objectId -EndDate $endDate -Type Symmetric -Usage Verify -Value $base64secret.Value
New-AzureADServicePrincipalKeyCredential -ObjectId $objectId -EndDate $endDate -Type Symmetric -Usage Sign -Value $base64secret.Value

[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($base64secret.Value))
$base64secret.EndDate # Print the end date.