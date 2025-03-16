# Azure AD Group User Removal Script

## Features:
- **Automated User Removal:** Removes users from a specified Azure AD group based on a list provided in a CSV file.
- **Module Validation:** Checks for the presence of the required `AzureAD` module before execution.
- **Input File Verification:** Ensures the input CSV file exists before processing; logs and exits if not found.
- **Output File Creation:** Verifies and creates the output log file with appropriate headers, ensuring it can be written to.
- **CSV Format Validation:** Validates the format of the CSV file, ensuring the `UserPrincipalName` column is present.
- **Dynamic Group ID Retrieval:** Automatically retrieves the ObjectId of the target group based on the group name provided.
- **Detailed Logging:**
  - Logs actions in CSV format with columns for `LogType`, `Category`, `UserPrincipalName`, and `Message`.
  - **Categories:** Includes specific categories such as "Processing", "User Not Found", "Not a Member", "Removal", "Info", etc.
  - Logs both successes and failures, as well as informational messages.
  
## Error Handling:
- **File Not Found:** Logs an error and exits if the input CSV file is missing or if the output log file cannot be created.
- **Module Missing:** Logs an error and exits if the required `AzureAD` module is not installed.
- **CSV Format Issues:** Logs an error and exits if the CSV format is incorrect (e.g., missing required columns).
- **User Not Found:** Logs a specific error if a user listed in the CSV does not exist in Azure AD.
- **Membership Check:** Logs an error if a user is found in Azure AD but is not a member of the target group.
- **Removal Failures:** Logs detailed errors if there is an issue removing a user from the group.

This script is robust, with comprehensive logging and error-handling features designed to ensure smooth execution and easy troubleshooting.
