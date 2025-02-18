#%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -WindowStyle Hidden -command .\uninstall.ps1

$PackageName = "Lockscreen"

$Path = "C:\Windows\Web\Wallpaper"
$FilesToCheck = @(
    "REDACTED",
    "REDACTED",
    "REDACTED",
    "REDACTED"
)

Start-Transcript -Path "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\$PackageName-uninstall.log" -Force
$ErrorActionPreference = "Stop"

# Set variables for registry key path and names of registry values to be modified
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
$LockScreenPath = "LockScreenImagePath"
$LockScreenStatus = "LockScreenImageStatus"
$LockScreenUrl = "LockScreenImageUrl"

# Check if any of the specified files exist and delete them
foreach ($File in $FilesToCheck) {
    $FullPath = Join-Path -Path $Path -ChildPath $File
    if (Test-Path -Path $FullPath) {
        Remove-Item -Path $FullPath -ErrorAction SilentlyContinue
        Write-Output "Deleted $File"
    } else {
        Write-Output "$File not found"
    }
}

# Check whether registry key path exists
if(!(Test-Path $RegKeyPath)){
    Write-Warning "The path ""$RegKeyPath"" does not exists. Therefore no wallpaper or lockscreen is set by this package."
}
else {
    Write-Host "Deleting regkeys for lockscreen"
    Remove-ItemProperty -Path $RegKeyPath -Name $LockScreenStatus -Force
    Remove-ItemProperty -Path $RegKeyPath -Name $LockScreenPath -Force
    Remove-ItemProperty -Path $RegKeyPath -Name $LockScreenUrl -Force
}

Stop-Transcript