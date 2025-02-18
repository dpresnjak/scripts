Start-Transcript -Path "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\TeamsClassicValidation.log" -Force

# All outdated MS Teams versions found through Defender Vulnerability Management
#$versions = @("48.144.23141","14.38.33130")

$versions = @("48.144.231412","14.38.331302")

# Creating an empty array to store application descriptions
$applications = @()

# Checking if the application with the above versions exist and storing it
foreach ($version in $versions) {
    Write-Output "Checking if Teams application $version exists."
    $applications += Get-WmiObject -Class Win32_Product | Where-Object {$_.Version -eq "$version"}
}

# Writing out which applications will get uninstalled
if ($applications.count -gt 0){
    Write-Output "The following outdated applications are present:"
    Write-Output $applications
    exit 1
}
else {
    Write-Output "There are no outdated Teams installations on this device."
    exit 0
}

Stop-Transcript