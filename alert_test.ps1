$headers = @{ 'Content-Type' = 'application/json' }

Write-Host "Testing Email Alerts" -ForegroundColor Cyan

$directAlert = @{
    email = "akashkeotel7@gmail.com"
    city = "Juhu" 
    alertType = "flood_warning"
    message = "High flood risk in Juhu area. Please stay safe!"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "https://smsfloddbackend.vercel.app/api/alerts/direct" -Method POST -Headers $headers -Body $directAlert
    Write-Host "SUCCESS: Email alert sent!" -ForegroundColor Green
    Write-Host "Check your email: akashkeotel7@gmail.com" -ForegroundColor White
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
    }
}
