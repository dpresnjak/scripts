Start-Transcript -Path "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\TeamsClassicUninstall.log" -Force

# All outdated MS Teams versions found through Defender Vulnerability Management
$versions = @(
    "1.2.0.10168",
    "1.4.0.32771",
    "1.5.0.11163",
    "1.5.0.21668",
    "1.5.0.27363",
    "1.5.0.30767",
    "1.5.0.33362",
    "1.5.0.4689",
    "1.5.0.8070",
    "1.6.0.11166",
    "1.6.0.12455",
    "1.6.0.1381",
    "1.6.0.16472",
    "1.6.0.22378",
    "1.6.0.24078",
    "1.6.0.27573",
    "1.6.0.33567",
    "1.6.0.35961",
    "1.6.0.4472",
    "1.6.0.6754",
    "1.7.0.10152",
    "1.7.0.13456",
    "1.7.0.15969",
    "1.7.0.1864",
    "1.7.0.26062",
    "1.7.0.27757",
    "1.7.0.27855",
    "1.7.0.3653",
    "1.7.0.6058",
    "1.7.0.7956",
    "1.8.0.1362"
)

# Creating an empty array to store application descriptions
$applications = @()

# Checking if the application with the above versions exist and storing it
foreach ($version in $versions) {
    Write-Output "Checking if Teams application $version exists."
    $applications += Get-WmiObject -Class Win32_Product | Where-Object {$_.Version -eq "$version"}
}

# Writing out which applications will get uninstalled
Write-Output "The following outdated applications will get uninstalled:"
Write-Output $applications

# Fetching IdentifyingNumber for the uninstall command
$identifiers = $applications | Select-Object -Expand IdentifyingNumber

foreach ( $identifier in $identifiers ){
    # Fetching application name
    $appName = Get-WmiObject -Class Win32_Product | Where-Object { $_.IdentifyingNumber -eq "$identifier" } | Select-Object -Expand Name
    Write-Output "Uninstalling $appName with $identifier IdentifyingNumber."

    # Running uninstall
    msiexec /x "$identifier" /qn
}

Stop-Transcript