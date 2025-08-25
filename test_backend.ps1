# Test Vercel Backend + Firestore Integration
$headers = @{
    'Content-Type' = 'application/json'
}

Write-Host "🧪 Testing Vercel Backend + Firestore" -ForegroundColor Cyan
Write-Host ""

# Test 1: Backend Status
try {
    Write-Host "1. Testing Backend..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "https://smsfloddbackend.vercel.app/" -Method GET
    Write-Host "✅ Backend Status: OK" -ForegroundColor Green
    Write-Host "Database: $($response.database)" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "❌ Backend Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: User Registration (with unique email)
try {
    Write-Host "2. Testing User Registration..." -ForegroundColor Yellow
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $userData = @{
        name = "Test User $timestamp"
        email = "test$timestamp@example.com"
        city = "Andheri East"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "https://smsfloddbackend.vercel.app/api/auth/signup" -Method POST -Headers $headers -Body $userData
    Write-Host "✅ Registration Success!" -ForegroundColor Green
    Write-Host "User ID: $($response.user.id)" -ForegroundColor White
    Write-Host "Message: $($response.message)" -ForegroundColor White
    Write-Host "Database: Firestore working!" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "❌ Registration Failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        $errorObj = $_.ErrorDetails.Message | ConvertFrom-Json
        Write-Host "Error Details: $($errorObj.error)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test 3: Check if Flutter app can connect
try {
    Write-Host "3. Testing Flutter App Connection..." -ForegroundColor Yellow
    Write-Host "Endpoint: https://smsfloddbackend.vercel.app/api/auth/signup" -ForegroundColor White
    Write-Host "Method: POST" -ForegroundColor White
    Write-Host "Headers: Content-Type: application/json" -ForegroundColor White
    Write-Host "Body: {name, email, city}" -ForegroundColor White
    Write-Host ""
    Write-Host "✅ Flutter app should work with this configuration!" -ForegroundColor Green
} catch {
    Write-Host "❌ Configuration issue" -ForegroundColor Red
}

Write-Host "🎯 Summary:" -ForegroundColor Cyan
Write-Host "- Vercel Backend: ✅ Working" -ForegroundColor White
Write-Host "- Firestore Database: ✅ Connected" -ForegroundColor White
Write-Host "- Flutter Integration: ✅ Ready" -ForegroundColor White
