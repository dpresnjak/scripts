# $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps" -Method GET
# $apps = $response.value

# Write-Host $apps
#$scriptid = Get-Content "ids.txt"

# foreach ($id in $scriptid) {
#     $script = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$id" -Method GET
#     $scriptContent = $script.scriptContent
#     $scriptName = $script.displayName

#     $decodedContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($scriptContent))
#     $decodedContent | Out-File -FilePath ".\newscript-$scriptName.ps1"
# }

# Replace 'your-app-id' with the actual ID of the app you want to download the scripts for
$appId = "REDACTED"

# Define the path where you want to save the .intunewin file
$path = ".\"

# Ensure the directory exists
if (-Not (Test-Path -Path $path)) {
    New-Item -ItemType Directory -Path $path -Force
}

# Authenticate with Microsoft Graph
Connect-MgGraph -Scopes "DeviceManagementApps.Read.All"

# Fetch the app details
$app = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$appId" -Method GET

# Fetch the content versions
$contentVersions = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$appId/microsoft.graph.win32LobApp/contentVersions" -Method GET

# Get the latest content version ID
$contentVersionId = $contentVersions.value[-1].id

# Fetch the files in the latest content version
$files = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$appId/microsoft.graph.win32LobApp/contentVersions/$contentVersionId/files" -Method GET

# Download each file
foreach ($file in $files.value) {
    $fileName = $file.name
    $downloadUrl = $file.azureStorageUri

    # Download the file
    Invoke-WebRequest -Uri $downloadUrl -OutFile "$path\$fileName"
}

Write-Host "Files downloaded successfully to $path"

