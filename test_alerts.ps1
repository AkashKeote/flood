# Test Email Alert System
$headers = @{ 'Content-Type' = 'application/json' }

Write-Host "📧 Testing Email Alert System" -ForegroundColor Cyan
Write-Host ""

# Test 1: Send direct alert to your email
try {
    Write-Host "1. Testing Direct Email Alert..." -ForegroundColor Yellow
    $directAlert = @{
        email = "akashkeotel7@gmail.com"
        city = "Juhu"
        alertType = "flood_warning"
        message = "High flood risk detected in Juhu area. Please take necessary precautions."
    } | ConvertTo-Json
    
    Write-Host "Sending alert to: akashkeotel7@gmail.com" -ForegroundColor Gray
    Write-Host "City: Juhu" -ForegroundColor Gray
    Write-Host ""
    
    $response = Invoke-RestMethod -Uri "https://smsfloddbackend.vercel.app/api/alerts/direct" -Method POST -Headers $headers -Body $directAlert
    Write-Host "✅ Email Alert Sent Successfully!" -ForegroundColor Green
    Write-Host "Check your email inbox!" -ForegroundColor White
    Write-Host ($response | ConvertTo-Json -Depth 2) -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "❌ Direct Alert Failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Error Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test 2: Send alert by city (to all users in that city)
try {
    Write-Host "2. Testing City-Wide Alert..." -ForegroundColor Yellow
    $cityAlert = @{
        city = "Juhu"
        alertType = "flood_risk_change"
        message = "Flood risk level has changed for Juhu area. Stay updated."
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "https://smsfloddbackend.vercel.app/api/alerts/send-by-city" -Method POST -Headers $headers -Body $cityAlert
    Write-Host "✅ City Alert Sent!" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json -Depth 2) -ForegroundColor Gray
} catch {
    Write-Host "❌ City Alert Failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Error Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "📱 Next: Add alert functionality to Flutter app!" -ForegroundColor Cyan
