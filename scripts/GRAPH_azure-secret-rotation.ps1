<#
# MsGraph Cmdlets:
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host?view=powershell-7.4
https://learn.microsoft.com/en-us/sharepoint/dev/sp-add-ins/replace-an-expiring-client-secret-in-a-sharepoint-add-in
https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.applications/remove-mgserviceprincipalpassword?view=graph-powershell-1.0

# Test App/Client from my Dev Tenant:
app: b78da758-1e73-4345-ad88-01af1f66e413
secret: 82b1341a-4c92-4856-8193-6a0302d7ce86


# Module install commands
Install-Module -Name PowerShellGet -Force -AllowClobber # ps native package management for adding more modules
Install-Module -Name Microsoft.Graph.Authentication # graph api module
Install-Module -Name Microsoft.Graph.Applications # graph api module

#>

Write-Host "Starting Prerequisite check.."
# Check for presence of prereqs on local machine, quit if they are missing
$RequiredModules = @("PowerShellGet", "Microsoft.Graph.Authentication", "Microsoft.Graph.Applications")
ForEach( $Module in $RequiredModules ) 
{
    If ( !(Get-Module -ListAvailable -Name $Module) ) {
        # print an error for each missing module
        Write-Host "$Module is missing, run an elevated shell and install it"
        $PrereqMissing = 1
    }
}
if ($PrereqMissing -eq 1) {
    Write-Host "One or more moduels were missing, script will now terminate"
    Exit 1
} else {
    Write-Host "Prerequisite check completed. Importing modules.."
}
# Import MsGraph modules and connect to MsGraph
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Applications
# Start connection, with minimal scope. Using Interactive Auth
Connect-MgGraph -Scopes "Application.ReadWrite.All Directory.ReadWrite.All" # tighten the scope/improve

$AppObjectID = "f2032bd7-8bd5-4aa7-8a86-8c519e7dc862"
$KeyIDParams = @{
	KeyId = "c92baac5-c486-4f58-8854-c0824eaa222b"
}



#$NewPassword = Add-MgServicePrincipalPassword -ServicePrincipalId $AppObjectID -PasswordCredential $PasswordCredential

<#
# Get the inputs from user
$AppObjectID = Read-Host "Enter the Application Object ID to be rotated [from Enterprise Applications]"
$AppClientSecretID = Read-Host "Enter the Secret ID to be rotated [from App Registrations]"
$servicePrincipal = Get-MgServicePrincipal -Filter "AppId eq '$AppClientSecretID'"
#>



<#
# Get/Set App ID and expiration
$endDate = (Get-Date).AddYears(1) # Set end date to 12 months from now
$app = Get-MgServicePrincipal -Filter "AppId eq '$AppObjectID'" # prep the app client ID before setting
$objectId = $app.ObjectId # set the client ID

$base64secret = Add-MgServicePrincipalPassword -ObjectId $AppObjectID -EndDate $endDate
Add-MgServicePrincipalKey -ObjectId $AppObjectID -EndDate $endDate -Type Symmetric -Usage Verify -Value $base64secret.Value
Add-MgServicePrincipalKey -ObjectId $AppObjectID -EndDate $endDate -Type Symmetric -Usage Sign -Value $base64secret.Value

[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($base64secret.Value))
$base64secret.EndDate # Print the end date.
#>
