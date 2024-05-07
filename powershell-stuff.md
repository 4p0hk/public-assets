# Ensure you've installed the Azure PowerShell module
Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Gather the essential identifiers and secret from the user
$tenantId = Read-Host -Prompt "Enter your Tenant ID"
$applicationId = Read-Host -Prompt "Enter your Application ID"
$applicationSecret = Read-Host -Prompt "Enter your Application Secret"
$secretName = Read-Host -Prompt "Enter the Secret Name"
$vaultName = Read-Host -Prompt "Enter the Key Vault Name"

# Forge a credential object with the application secret
$secureSecret = ConvertTo-SecureString $applicationSecret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($applicationId, $secureSecret)

# Connect to Azure with the demonic credentials
Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $tenantId

# Summon the secret from the depths of the Azure Key Vault
$secret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $secretName

# Reveal the whispered truths hidden within the secret
Write-Host "The secret is: $($secret.SecretValueText)"
