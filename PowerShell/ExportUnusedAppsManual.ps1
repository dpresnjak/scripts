# Getting all non-Microsoft Enterprise Applications (Filtering by tag which identifies Enterprise Apps as in the Azure portal)
$applications = Get-Content "Temp.txt"

$hasSignIns = @()
$noSignIns = @()
$checkIfNull = @()

foreach ($app in $applications) {
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

$signInsCSV = $hasSignIns | ForEach-Object {
    [PSCustomObject]@{
        Id                = $_.Id
        AppDisplayName    = $_.AppDisplayName
        AppId             = $_.AppId
        CorrelationId     = $_.CorrelationId
        CreatedDateTime   = $_.CreatedDateTime
        IPAddress         = $_.IPAddress
    }
}

Write-Output (($hasSignIns | Group-Object -Property AppDisplayName).Count)

$signInsCSV | Export-Csv -Path ".\EntAppSignInLogs.csv" -NoTypeInformation
$noSignIns | Export-Csv -Path ".\EntAppNoSignInFor30Days.csv" -NoTypeInformation