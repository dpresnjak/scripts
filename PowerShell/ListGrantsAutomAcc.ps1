$tenantId = "REDACTED"
$clientId = Get-AutomationVariable -Name "clientId"
$clientSecret = Get-AutomationVariable -Name "clientSecret"
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

# Microsoft Graph Command Line Tools
$app_name = "Microsoft Graph Command Line Tools"
$applicationId = Get-MgServicePrincipal -Filter "displayName eq '$app_name'" | Select-Object Id -ExpandProperty Id

# Get the list of grants for the application
$grants = Get-MgServicePrincipalOauth2PermissionGrant -ServicePrincipalId $applicationId

# Initialize an array to store the results
$output = $grants | ForEach-Object {
    $principalId = $_.principalId
    $scope = $_.scope

    # Get the principal details
    if ([string]::IsNullOrEmpty($principalId)) {
        return
    } else {
        $principal = Get-MgUser -UserId $principalId
    }

    # Extract attributes
    $principalName = $principal.displayName
    $principalEnabled = $principal.accountEnabled
    $userPrincipalName = $principal.userPrincipalName

    # Get the user's groups
    if ([string]::IsNullOrEmpty($principalId)) {
        return
    } else {
        $groups = Get-MgUserMemberOfAsGroup -UserId $principalId | Where-Object { $_.DisplayName -eq 'MCF_Disabled_Users' }
    }

    # Check if the output is empty
    if ($groups.Count -eq 0) {
        return
    } else {
        $status = "Disabled"
        # Create a custom object with the results
        [PSCustomObject]@{
            PrincipalID       = $principalId
            PrincipalName     = $principalName
            PrincipalEnabled  = $status
            UserPrincipalName = $userPrincipalName
            Scope             = $scope
        }
    }
}

# Manually construct the CSV content because the PSCustomObject prints out in one row in the CSV
$csvContent = "PrincipalID,PrincipalName,PrincipalEnabled,UserPrincipalName,Scope`n"
$output | ForEach-Object {
    $csvContent += "$($_.PrincipalID),$($_.PrincipalName),$($_.PrincipalEnabled),$($_.UserPrincipalName),$($_.Scope)`n"
}

# Convert CSV content to byte array
$bytes = [System.Text.Encoding]::UTF8.GetBytes($csvContent)

# Add a timestamp to the file name
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$subjectDate = Get-Date -Format "g"

# Email parameters
$Subject = "Graph CLI Active Grants - $subjectDate"
$From = "REDACTED"
$To = @("REDACTED", "REDACTED", "REDACTED", "REDACTED", "REDACTED")
$Body = @"
Graph CLI grants report on $subjectDate.

Sent via the AuditingScripts Automation Account - GetGraphCLIGrants runbook.
"@
$FileName = "GraphCLIActiveGrants_$timestamp.csv"

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