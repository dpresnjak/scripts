# Start the install script
Start-Transcript -Path "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\Lockscreen-install.log" -Force
$ErrorActionPreference = "Stop"

# Define the lock screen images for different resolutions
$LockscreenImages = @{
    "1920x1080" = "REDACTED"
    "2560x1440" = "REDACTED"
    "3840x2160" = "REDACTED"
    "1366x768"  = "REDACTED"
}

# Detect display resolution
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class ScreenResolution
{
    [DllImport("user32.dll")]
    public static extern IntPtr GetDC(IntPtr hWnd);

    [DllImport("gdi32.dll")]
    public static extern int GetDeviceCaps(IntPtr hdc, int nIndex);

    [DllImport("user32.dll")]
    public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

    public static int GetScreenResolutionWidth()
    {
        IntPtr hdc = GetDC(IntPtr.Zero);
        int width = GetDeviceCaps(hdc, 118); // HORZRES
        ReleaseDC(IntPtr.Zero, hdc);
        return width;
    }

    public static int GetScreenResolutionHeight()
    {
        IntPtr hdc = GetDC(IntPtr.Zero);
        int height = GetDeviceCaps(hdc, 117); // VERTRES
        ReleaseDC(IntPtr.Zero, hdc);
        return height;
    }
}
"@

$width = [ScreenResolution]::GetScreenResolutionWidth()
$height = [ScreenResolution]::GetScreenResolutionHeight()
$resolution = "${width}x${height}"

Write-Output "Detected Resolution: $resolution"

# Set variables for registry key path and names of registry values to be modified
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
$LockScreenPath = "LockScreenImagePath"
$LockScreenStatus = "LockScreenImageStatus"
$LockScreenUrl = "LockScreenImageUrl"
$StatusValue = "1"

# Check if the resolution has a corresponding lock screen image
if ($LockscreenImages.ContainsKey($resolution)) {
    $LockscreenIMG = $LockscreenImages[$resolution]
    $LockscreenLocalIMG = "C:\Windows\Web\Wallpaper\$LockscreenIMG"

    # Check whether registry key path exists, create it if it does not
    if (!(Test-Path $RegKeyPath)) {
        Write-Host "Creating registry path: $RegKeyPath."
        New-Item -Path $RegKeyPath -Force
    }

    Write-Host "Copy lockscreen '$LockscreenIMG' to '$LockscreenLocalIMG'"
    Copy-Item ".\Data\$LockscreenIMG" $LockscreenLocalIMG -Force

    Write-Host "Creating regkeys for lockscreen"
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenStatus -Value $StatusValue -PropertyType DWORD -Force
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenPath -Value $LockscreenLocalIMG -PropertyType STRING -Force
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenUrl -Value $LockscreenLocalIMG -PropertyType STRING -Force
} else {
    Write-Warning "No lock screen image defined for resolution $resolution. Using default resolution 1920x1080"
    $LockscreenIMG = $LockscreenImages["1920x1080"]
    $LockscreenLocalIMG = "C:\Windows\Web\Wallpaper\$LockscreenIMG"

    # Check whether registry key path exists, create it if it does not
    if (!(Test-Path $RegKeyPath)) {
        Write-Host "Creating registry path: $RegKeyPath."
        New-Item -Path $RegKeyPath -Force
    }

    Write-Host "Copy lockscreen '$LockscreenIMG' to '$LockscreenLocalIMG'"
    Copy-Item ".\Data\$LockscreenIMG" $LockscreenLocalIMG -Force

    Write-Host "Creating regkeys for lockscreen"
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenStatus -Value $StatusValue -PropertyType DWORD -Force
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenPath -Value $LockscreenLocalIMG -PropertyType STRING -Force
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenUrl -Value $LockscreenLocalIMG -PropertyType STRING -Force
}

Stop-Transcript