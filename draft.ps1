$scopes = "Directory.Read.All", `
          "AuditLog.Read.All", `
          "SecurityEvents.Read.All", `
          "IdentityRiskEvent.Read.All", `
          "User.Read.All", `
          "Group.Read.All", `
          "Device.Read.All", `
          "RoleManagement.Read.Directory", `
          "Reports.Read.All", `
          "Policy.Read.All", `
          "Organization.Read.All", `
          "DeviceManagementRBAC.Read.All", `
          "DeviceManagementConfiguration.Read.All", `
          "DeviceManagementManagedDevices.Read.All", `
          "DeviceManagementServiceConfig.Read.All", `
          "Directory.AccessAsUser.All" # This is a broad permission that can be used for accessing a lot of directory data as a user.
