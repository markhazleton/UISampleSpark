# Docker Hub README Update Script
# Save this as update-dockerhub-readme.ps1

$dockerUsername = 'markhazleton'
$repoName = 'uisamplespark'
$readmePath = 'DOCKER_README.md'

# Read the README content
$readmeContent = Get-Content $readmePath -Raw

# You'll need your Docker Hub token
# Get it from: https://hub.docker.com/settings/security
Write-Host 'Docker Hub API token required'
Write-Host 'Get it from: https://hub.docker.com/settings/security'
$token = Read-Host -AsSecureString 'Enter Docker Hub token'
$tokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token))

# Update the README via API
$uri = "https://hub.docker.com/v2/repositories/$dockerUsername/$repoName/"
$headers = @{
    'Authorization' = "Bearer $tokenPlain"
    'Content-Type' = 'application/json'
}
$body = @{
    full_description = $readmeContent
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $uri -Method Patch -Headers $headers -Body $body
    Write-Host '✓ Docker Hub README updated successfully!' -ForegroundColor Green
} catch {
    Write-Host '✗ Failed to update README:' $_.Exception.Message -ForegroundColor Red
}
