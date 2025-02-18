$tenantId = "REDACTED"
$clientId = "REDACTED"
$clientSecret = "REDACTED"
$resource = "https://graph.microsoft.com"

$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "$resource/.default"
}

$response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -ContentType "application/x-www-form-urlencoded" -Body $body
$token = $response.access_token

# Convert the access token to a SecureString
$secureToken = ConvertTo-SecureString -String $token -AsPlainText -Force

# Connect to Microsoft Graph using the SecureString token
Connect-MgGraph -AccessToken $secureToken -NoWelcome

# Define the GUID for the Microsoft 365 E5 license (replace with actual SKU ID)
$e5LicenseGuid = "REDACTED"  # Replace with your actual E5 license SKU ID

# Number of days for filtering inactive users
$daysInactive = 90

# Get today's date and calculate the threshold date (daysInactive ago)
$thresholdDate = (Get-Date).AddDays(-$daysInactive)

# Retrieve all users with their DisplayName, UserPrincipalName, SignInActivity, AccountEnabled, AssignedLicenses, UserType, and CreatedDateTime
$allUsers = Get-MgUser -Property "DisplayName,UserPrincipalName,SignInActivity,AccountEnabled,AssignedLicenses,UserType,CreatedDateTime" -All

# Filter out users who haven't signed in for the past $daysInactive days
$inactiveUsers = $allUsers | Where-Object {
    if ($_.SignInActivity -ne $null -and $_.SignInActivity.LastSignInDateTime -ne $null) {
        $_.SignInActivity.LastSignInDateTime -lt $thresholdDate
    }
}

# Add columns to indicate whether the user has the Microsoft 365 E5 license, the user type, the account creation date, 
# all assigned licenses, and whether the created date is before the last activity
$inactiveUsersWithE5Info = $inactiveUsers | ForEach-Object {
    $hasE5License = $_.AssignedLicenses.SkuId -contains $e5LicenseGuid
    $allLicenses = ($_.AssignedLicenses | ForEach-Object { $_.SkuPartNumber }) -join ", "
    $createdBeforeLastActivity = $null
    if ($_.CreatedDateTime -ne $null -and $_.SignInActivity.LastSignInDateTime -ne $null) {
        $createdBeforeLastActivity = $_.CreatedDateTime -lt $_.SignInActivity.LastSignInDateTime
    }

    [PSCustomObject]@{
        DisplayName                = $_.DisplayName
        UserPrincipalName          = $_.UserPrincipalName
        LastSignInDateTime         = $_.SignInActivity.LastSignInDateTime
        AccountEnabled             = $_.AccountEnabled
        HasE5License               = $hasE5License  # True if the user has the E5 license, False otherwise
        UserType                   = $_.UserType    # "Member" or "Guest"
        CreatedAt                  = $_.CreatedDateTime # Date the user account was created
        CreatedBeforeLastActivity  = $createdBeforeLastActivity # True if CreatedAt is before LastSignInDateTime, False otherwise
        AllLicenses                = $allLicenses   # List of all licenses assigned to the user
    }
}

# Add a timestamp to the file name
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFileName = "Inactive_Users_$($daysInactive)_Days_With_E5_Info_$timestamp.csv"

# Inform user that the export is complete
Write-Host "Export of inactive users (no activity for $daysInactive days) with E5 license, user type, created date, license details, and creation date comparison is complete. File saved as $outputFileName"

# Manually construct the CSV content because the PSCustomObject prints out in one row in the CSV
$csvContent = "DisplayName,UserPrincipalName,LastSignInDateTime,AccountEnabled,HasE5License,UserType,CreatedAt,CreatedBeforeLastActivity,AllLicenses`n"
$inactiveUsersWithE5Info | ForEach-Object {
    $csvContent += "$($_.DisplayName),$($_.UserPrincipalName),$($_.LastSignInDateTime),$($_.AccountEnabled),$($_.HasE5License),$($_.UserType),$($_.CreatedAt),$($_.CreatedBeforeLastActivity),$($_.AllLicenses)`n"
}

# Convert CSV content to byte array
$bytes = [System.Text.Encoding]::UTF8.GetBytes($csvContent)

# Email parameters
$Subject = "Dormant users export"
$From = "REDACTED"
$To = @("REDACTED")
$Body = "Please find the attached CSV file."
$FileName = "Inactive_Users_$($daysInactive)_Days_With_E5_Info_$timestamp.csv"

$email = @{
    message = @{
        Subject = $Subject
        body = @{
            contentType = "Text"
            content     = $Body
        }
        toRecipients = $To | ForEach-Object { @{emailAddress = @{address = $_}} }
        attachments = @(@{
            "@odata.type" = "#microsoft.graph.fileAttachment"
            name          = $FileName
            ContentBytes  = [System.Convert]::ToBase64String($bytes)
            contentType   = "text/csv"
        })
    }
}

# Send the email
Send-MgUserMail -UserId $From -BodyParameter $email