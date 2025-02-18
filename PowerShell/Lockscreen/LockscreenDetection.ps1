Start-Transcript -Path "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\Lockscreen-detection.log" -Force

# Define the file path and file names to check
$Path = "C:\Windows\Web\Wallpaper"
$FilesToCheck = @(
    "REDACTED",
    "REDACTED",
    "REDACTED",
    "REDACTED"
)

# Check if any of the specified files exist
$FileFound = $false
foreach ($File in $FilesToCheck) {
    if (Test-Path -Path (Join-Path -Path $Path -ChildPath $File)) {
        Write-Output "File found: $File"
        $FileFound = $true
    }
}

# Output the result instead of exiting
if ($FileFound) {
    Write-Output "Detection Successful"
} else {
    Write-Output "Detection Failed, no file found"
    exit 1
}

Stop-Transcript