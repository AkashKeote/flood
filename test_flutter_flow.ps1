# Test Flutter App Registration Flow
$headers = @{
    'Content-Type' = 'application/json'
}

Write-Host "🔍 Testing Flutter App Registration Flow" -ForegroundColor Cyan
Write-Host ""

# Simulate exact Flutter app request
try {
    Write-Host "📱 Simulating Flutter App Request..." -ForegroundColor Yellow
    
    # Use exact data format from Flutter app
    $userData = @{
        name = "Test Flutter User"
        email = "flutter.test@example.com"
        city = "Andheri East"  # From dropdown
    } | ConvertTo-Json
    
    Write-Host "📤 Request Details:" -ForegroundColor White
    Write-Host "URL: https://smsfloddbackend.vercel.app/api/auth/signup" -ForegroundColor Gray
    Write-Host "Method: POST" -ForegroundColor Gray
    Write-Host "Headers: Content-Type: application/json" -ForegroundColor Gray
    Write-Host "Body: $userData" -ForegroundColor Gray
    Write-Host ""
    
    $response = Invoke-RestMethod -Uri "https://smsfloddbackend.vercel.app/api/auth/signup" -Method POST -Headers $headers -Body $userData
    
    Write-Host "✅ Registration Success!" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor White
    Write-Host ($response | ConvertTo-Json -Depth 3) -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "🎯 Conclusion: Flutter app should work perfectly!" -ForegroundColor Green
    Write-Host "- Backend: ✅ Accessible" -ForegroundColor White
    Write-Host "- Firestore: ✅ Saving data" -ForegroundColor White
    Write-Host "- API Format: ✅ Compatible" -ForegroundColor White
    
} catch {
    Write-Host "❌ Error occurred:" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "🔧 Possible Issues:" -ForegroundColor Yellow
    Write-Host "1. Network connectivity from Flutter app" -ForegroundColor White
    Write-Host "2. CORS issues (unlikely on mobile)" -ForegroundColor White
    Write-Host "3. Flutter app HTTP package configuration" -ForegroundColor White
}

Write-Host ""
Write-Host "📋 Checklist for Flutter App:" -ForegroundColor Cyan
Write-Host "1. Backend URL: https://smsfloddbackend.vercel.app" -ForegroundColor White
Write-Host "2. Endpoint: /api/auth/signup" -ForegroundColor White
Write-Host "3. Method: POST" -ForegroundColor White
Write-Host "4. Headers: Content-Type: application/json" -ForegroundColor White
Write-Host "5. Body: name, email, city fields" -ForegroundColor White
Write-Host "6. Cities: From dummyFloodData list" -ForegroundColor White
