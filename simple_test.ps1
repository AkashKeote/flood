# Simple Test for Flutter Registration
Write-Host "Testing Flutter Registration Flow" -ForegroundColor Cyan

$headers = @{ 'Content-Type' = 'application/json' }
$userData = @{
    name = "Test Flutter User"
    email = "flutter.test@example.com" 
    city = "Andheri East"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "https://smsfloddbackend.vercel.app/api/auth/signup" -Method POST -Headers $headers -Body $userData
    Write-Host "SUCCESS: Registration worked!" -ForegroundColor Green
    Write-Host "User ID: $($response.user.id)" -ForegroundColor White
    Write-Host "Message: $($response.message)" -ForegroundColor White
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

Write-Host "Flutter app should work with this configuration!" -ForegroundColor Green
