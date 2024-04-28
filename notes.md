# ADFS & VDI, Domain Identity

## Methods for machine identity
This article outlines the supported methods 
- [Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/devices/howto-device-identity-virtual-desktop-infrastructure)
- WF is likely using Hybrid Joined, so there is full support as long as the Identity infrastructure is "Federated" 
- Federated: using ADFS or another 3rd party IdP

The flow of device registration is shown here:
- [Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/devices/device-registration-how-it-works#microsoft-entra-hybrid-joined-in-federated-environments)

Notes in this article seem to provide a method for using a non ADFS provider
- [Blog](https://www.oryszczyn.com/azure-active-directory-hybrid-join-and-persistent-vdi/)

## Differences in Managed vs Federated domains
This article has a good explanation of the differences between "Managed" and "Federated" domain types
- [Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/devices/how-to-hybrid-join#managed-domains)

Essentially:
- Managed = Pw Hash Sync or Pass-through Authentication with SSO
- Federated = Some other third party IdP provider, or AD FS

## Troubleshooting issues with auto login / join
Essentially, you need a clean image that is not Azure joined

- if it's joined, run the following command before snapshotting the image
> dsregcmd.exe /leave

- for the new VDIs, the following should run on startup
> dsregcmd.exe /join


