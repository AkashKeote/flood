#!/bin/bash

echo "🚀 Flood Prediction System - Vercel Deployment Script"
echo "=================================================="

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo "⚠️  Vercel CLI not found. Installing..."
    npm install -g vercel
fi

# Check if we're in the right directory
if [ ! -f "vercel.json" ]; then
    echo "❌ vercel.json not found. Make sure you're in the project root directory."
    exit 1
fi

echo "✅ Project structure validated"

# Display project info
echo ""
echo "📊 Project Information:"
echo "   Frontend: Flutter Web (index.html)"
echo "   Backend: Python Flask APIs"
echo "   APIs: /api/index.py (main), /api/map.py (routing)"

# Check Python dependencies
echo ""
echo "🐍 Checking Python dependencies..."
if [ -f "requirements.txt" ]; then
    echo "   ✅ requirements.txt found"
    echo "   📦 Dependencies: $(cat requirements.txt | wc -l) packages"
else
    echo "   ❌ requirements.txt not found"
    exit 1
fi

# Deploy to Vercel
echo ""
echo "🚀 Starting Vercel deployment..."
echo "   This will deploy your app to Vercel's global network"
echo ""

# Run vercel deploy
vercel --prod

echo ""
echo "✅ Deployment completed!"
echo ""
echo "🔗 Your app should now be available at the URL shown above"
echo ""
echo "🧪 Test your deployment:"
echo "   1. Visit your app URL to see the Flutter frontend"
echo "   2. Test API: [YOUR_URL]/api/health"
echo "   3. Test prediction: POST to [YOUR_URL]/api/predict_flood"
echo "   4. Test map: [YOUR_URL]/api/map?region=andheri"
echo ""
echo "📚 For more help, see DEPLOYMENT_README.md"
