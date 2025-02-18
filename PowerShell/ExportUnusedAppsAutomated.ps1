# Login function; Used for initial login and refresh token
function LoginToGraph {
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
    Connect-MgGraph -AccessToken $secureToken #-NoWelcome
}

$startTime = Get-Date

# Logging in
LoginToGraph

# Getting all non-Microsoft Enterprise Applications (Filtering by tag which identifies Enterprise Apps as in the Azure portal)
$applications = Get-MgServicePrincipal -All -Filter "tags/any(t: t eq 'WindowsAzureActiveDirectoryIntegratedApp')"  -Top 2 | Select-Object AppId,DisplayName | Sort-Object DisplayName

$hasSignIns = @()
$noSignIns = @()
$checkIfNull = @()

foreach ($app in $applications) {
    $elapsedTime = (Get-Date) - $startTime

    if ($elapsedTime.TotalMinutes -ge 30) {
        # Refreshing login
        LoginToGraph

        # Reset the start time
        $startTime = Get-Date
    }

    $appId = $app.AppId
    $appName = $app.DisplayName

    $checkIfNull = Get-MgAuditLogSignIn -Filter "AppId eq '$appId'" -Top "5"

    if (($checkIfNull.count -gt 0)) {
            $hasSignIns += $checkIfNull
        }
    else {
        $noSignIns += [PSCustomObject]@{ ApplicationId = $appId; ApplicationName = $appName }
    }
}

$signIns = $hasSignIns | ForEach-Object {
    [PSCustomObject]@{
        Id                = $_.Id
        AppDisplayName    = $_.AppDisplayName
        AppId             = $_.AppId
        CorrelationId     = $_.CorrelationId
        CreatedDateTime   = $_.CreatedDateTime
        IPAddress         = $_.IPAddress
    }
}

##########

# Add a timestamp to the file name
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFileNameSignInLogs = "EntAppSignInData_$timestamp.csv"
$outputFileNameNoSignIns = "NoSignInLogsFor30Days_$timestamp.csv"

# Manually construct the CSV content because the PSCustomObject prints out in one row in the CSV
## Enterprise Applications with sign in logs
$csvContentSignIns = "Id,AppDisplayName,AppId,CorrelationId,CreatedDateTime,IPAddress`n"
$signIns | ForEach-Object {
    $csvContentSignIns += "$($_.Id),$($_.AppDisplayName),$($_.AppId),$($_.CorrelationId),$($_.CreatedDateTime),$($_.IPAddress)`n"
}

## Enterprise Applications with no sign in logs for the last 30 days
$csvContentNoSignIns = "ApplicationId,ApplicationName`n"
$noSignIns | ForEach-Object {
    $csvContentNoSignIns += "$($_.ApplicationId),$($_.ApplicationName)`n"
}

# Convert CSV content to byte array
$bytesSignIns = [System.Text.Encoding]::UTF8.GetBytes($csvContentSignIns)
$bytesNoSignIns = [System.Text.Encoding]::UTF8.GetBytes($csvContentNoSignIns)

# Email parameters
$subjectDate = Get-Date -Format "g"

$Subject = "Enterprise Applications audit report - $subjectDate"
$From = "REDACTED"
$To = @("REDACTED", "REDACTED")
$Body = @"
Enterprise Applications audit report on $subjectDate.

This report generates two CSV attachments, one exporting all non-Microsoft Enterprise Applications that have sign-ins in the last 30 days, and those that do not.

Sent via the EnterpriseAppsAudit Automation Runbook.
"@

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
            name          = $outputFileNameSignInLogs
            ContentBytes  = [System.Convert]::ToBase64String($bytesSignIns)
            contentType   = "text/csv"
        },
        @{
            "@odata.type" = "#microsoft.graph.fileAttachment"
            name          = $outputFileNameNoSignIns
            ContentBytes  = [System.Convert]::ToBase64String($bytesNoSignIns)
            contentType   = "text/csv"
        })
    }
}

# Send the email
Send-MgUserMail -UserId $From -BodyParameter $email