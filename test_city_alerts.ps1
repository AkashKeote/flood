# Test script to simulate email alerts on city change
$headers = @{
    'Content-Type' = 'application/json'
}

Write-Host "🧪 Testing email alerts for different cities..." -ForegroundColor Yellow
Write-Host ""

$cities = @("Mumbai", "Andheri East", "Bandra West", "Colaba", "Powai")

foreach ($city in $cities) {
    Write-Host "🏙️ Testing alert for: $city" -ForegroundColor Cyan
    
    $body = @{
        city = $city
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "https://smsfloddbackend.vercel.app/api/alerts/send-by-city" `
                                    -Method POST `
                                    -Headers $headers `
                                    -Body $body
        
        if ($response.success) {
            $riskLevel = $response.details.riskLevel
            $usersNotified = $response.details.usersNotified
            $emailsSent = $response.details.emailsSent
            
            Write-Host "✅ Alert sent successfully!" -ForegroundColor Green
            Write-Host "   Risk Level: $riskLevel" -ForegroundColor White
            Write-Host "   Users Notified: $usersNotified" -ForegroundColor White
            Write-Host "   Emails Sent: $emailsSent" -ForegroundColor White
        } else {
            Write-Host "❌ Alert failed" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Start-Sleep 2
}

Write-Host "🎯 Test complete! Check registered users' emails for alerts" -ForegroundColor Green
