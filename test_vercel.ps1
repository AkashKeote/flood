# Test Vercel Backend Connection
$headers = @{
    'Content-Type' = 'application/json'
}

Write-Host "🧪 Testing Vercel Backend Connection" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check backend status
try {
    Write-Host "1. Testing Backend Status..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "https://smsfloddbackend.vercel.app/" -Method GET
    Write-Host "✅ Backend is running!" -ForegroundColor Green
    Write-Host "Environment: $($response.environment)" -ForegroundColor White
    Write-Host "Database: $($response.database)" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "❌ Backend not accessible: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Test user signup
try {
    Write-Host "2. Testing User Signup..." -ForegroundColor Yellow
    $userData = @{
        name = "Test User"
        email = "test@example.com"
        city = "Andheri East"  # Using Mumbai area from cityService
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "https://smsfloddbackend.vercel.app/api/auth/signup" -Method POST -Headers $headers -Body $userData
    Write-Host "✅ Signup successful!" -ForegroundColor Green
    Write-Host "User ID: $($response.user.id)" -ForegroundColor White
    Write-Host "Message: $($response.message)" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "❌ Signup failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        $errorObj = $_.ErrorDetails.Message | ConvertFrom-Json
        Write-Host "Details: $($errorObj.error)" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "🎉 Backend connection tests completed!" -ForegroundColor Cyan
Write-Host "Flutter app is now connected to: https://smsfloddbackend.vercel.app/" -ForegroundColor White
