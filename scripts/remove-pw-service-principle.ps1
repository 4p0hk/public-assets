# this POC removes a specific keyId

Import-Module Microsoft.Graph.Applications

$params = @{
	keyId = "c47df78d-41bb-47fa-a492-60f5bb4c0789" # got from pull-creds.ps1, doesnt seem to be the same as GUI
}
Remove-MgServicePrincipalPassword -ServicePrincipalId b78da758-1e73-4345-ad88-01af1f66e413 -BodyParameter $params