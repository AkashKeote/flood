# Test Email Registration System
$headers = @{
    'Content-Type' = 'application/json'
}

# Test server status
Write-Host "🧪 Testing Flood Alert Email System" -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "1. Testing Server Status..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "http://127.0.0.1:5000" -Method GET
    Write-Host "✅ Server is running!" -ForegroundColor Green
    Write-Host "Message: $($response.message)" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "❌ Server not running: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test user registration
try {
    Write-Host "2. Testing User Registration..." -ForegroundColor Yellow
    $userData = @{
        name = "Test User"
        email = "test@example.com"  # Change this to your email to receive actual alerts
        region = "Andheri East"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "http://127.0.0.1:5000/register_user" -Method POST -Headers $headers -Body $userData
    Write-Host "✅ Registration successful!" -ForegroundColor Green
    Write-Host "Message: $($response.message)" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "❌ Registration failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test flood alert
try {
    Write-Host "3. Testing Flood Alert..." -ForegroundColor Yellow
    $alertData = @{
        email = "test@example.com"  # Change this to your email
        region = "Andheri East"
        risk_level = "high"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "http://127.0.0.1:5000/send_alert" -Method POST -Headers $headers -Body $alertData
    Write-Host "✅ Alert sent successfully!" -ForegroundColor Green
    Write-Host "Message: $($response.message)" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "❌ Alert failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "🎉 Email system tests completed!" -ForegroundColor Cyan
Write-Host "Check your email inbox for the welcome and alert messages." -ForegroundColor White
