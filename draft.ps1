union SigninLogs, AADNonInteractiveUserSignInLogs
| where tolower(UserPrincipalName) matches regex "sync_adis-(d)?(q)?pta.*"
| where Category == "SignInLogs"
| mv-apply NetworkLocationDetail = parse_json(NetworkLocationDetails) on (
    summarize
        untrustedNetworkTypeCount = countif(NetworkLocationDetail.networkType != "trustedNamedLocation"),
        namehereNetworkCount = countif(parse_json(tostring(NetworkLocationDetail.networkNames)) contains "namehere")
    | where untrustedNetworkTypeCount > 0 or namehereNetworkCount > 0
)
| extend Description = strcat('User account ', UserPrincipalName,
    ' tried to login from outside PTA server cloud account on ', AppDisplayName,
    ' application from ', Location, ' and IP address is ', IPAddress)
| project
    TimeGenerated, Description, AppDisplayName,
    Category, OperationName, NetworkLocationDetails, ClientAppUsed,
    Identity, IPAddress, IsInteractive,
    Location, ResultDescription, UserPrincipalName, UserDisplayName, UserType, ResultType