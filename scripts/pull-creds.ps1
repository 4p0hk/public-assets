# this poc simply shows some info about PasswordCredentials associated with a given Service Principal
# the test app doesnt seem to be set up correctly, querying a different app gives good info tho
# example - 17379266-41c1-476b-87e2-911bb29c7742 - this is the Wazuh app for SSO

Import-Module Microsoft.Graph.Applications

# This is the Object ID from Enterprise Applications
#$ServicePrincipalId = "17379266-41c1-476b-87e2-911bb29c7742" # Wazuh app works fine
#$ServicePrincipalId = "b78da758-1e73-4345-ad88-01af1f66e413" # secret-rotation-test app is totally fucked
$ServicePrincipalId = "2dd2e9cf-b6ea-4820-951c-50725fcd6a7e" # wazuhapplogtest

# This pulls SP details
$ServicePrincipal = Get-MgServicePrincipal -ServicePrincipalId $ServicePrincipalId

# Printing related passwords for the SP
Write-Host "Password Credentials:"
$ServicePrincipal.PasswordCredentials | Format-Table -AutoSize

# Printing related certificates for the SP
Write-Host "Key Credentials (Includes Certificates):"
$ServicePrincipal.KeyCredentials | Format-Table -AutoSize

# Additionally, if you want to print even more details like Redirect URIs, other settings:
Write-Host "Other Details:"
$ServicePrincipal | Select-Object -Property DisplayName, AppId, SignInAudience, Tags, ReplyUrls

