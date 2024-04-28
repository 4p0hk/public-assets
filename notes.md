# ADFS & VDI, Domain Identity

## Methods for machine identity
This article outlines the supported methods 
- [Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/devices/howto-device-identity-virtual-desktop-infrastructure)
- WF is likely using Hybrid Joined, so there is full support as long as the Identity infrastructure is "Federated" 
- Federated: using ADFS or another 3rd party IdP

The flow of device registration is shown here:
- [Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/devices/device-registration-how-it-works#microsoft-entra-hybrid-joined-in-federated-environments)

## Differences in Managed vs Federated domains
This article has a good explanation of the differences between "Managed" and "Federated" domain types
- [Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/devices/how-to-hybrid-join#managed-domains)

Essentially:
- Managed = Pw Hash Sync or Pass-through Authentication with SSO
- Federated = Some other third party IdP provider, or AD FS