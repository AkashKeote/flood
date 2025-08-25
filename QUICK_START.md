# 🚀 Quick Start Guide - Vercel Deployment

## Step 1: Prepare Your Project

Your project is now ready for Vercel deployment! Here's what we've set up:

```
✅ vercel.json - Deployment configuration
✅ requirements.txt - Python dependencies  
✅ package.json - Node.js configuration
✅ API endpoints - Python Flask backends
✅ Frontend - Flutter web build
✅ Test scripts - Deployment verification
```

## Step 2: Deploy to Vercel

### Option A: One-Click Deploy (Easiest)

1. **Push to GitHub:**
   ```bash
   git init
   git add .
   git commit -m "Ready for Vercel deployment"
   git remote add origin https://github.com/yourusername/flood-prediction.git
   git push -u origin main
   ```

2. **Deploy via Vercel:**
   - Go to [vercel.com](https://vercel.com)
   - Click "New Project" 
   - Import your GitHub repo
   - Click "Deploy" ✨

### Option B: Command Line Deploy

1. **Install Vercel CLI:**
   ```bash
   npm install -g vercel
   ```

2. **Deploy:**
   ```bash
   # Login to Vercel
   vercel login
   
   # Deploy your app
   vercel --prod
   ```

3. **Or use our script:**
   ```bash
   # On Windows
   deploy.bat
   
   # On Mac/Linux  
   ./deploy.sh
   ```

## Step 3: Test Your Deployment

After deployment, you'll get a URL like `https://flood-prediction-abc123.vercel.app`

**Test it:**
```bash
python test_deployment.py https://your-app.vercel.app
```

**Manual testing:**
- 🌐 Visit your URL to see the Flutter app
- 🔍 Check `/api/health` for API status
- 📍 Try `/api/map?region=andheri` for evacuation map
- 🤖 POST to `/api/predict_flood` with `{"ward_name": "Andheri East"}`

## 🎯 What You Get

- **Frontend**: Full Flutter web app at your domain root
- **Prediction API**: POST `/api/predict_flood` for flood risk assessment
- **Map API**: GET `/api/map?region=<name>` for evacuation routes
- **Health Check**: GET `/api/health` for system status

## 🔧 Configuration Details

### Supported Wards
The system includes data for 20+ Mumbai wards including:
- Andheri East/West
- Bandra West  
- Colaba
- Fort
- Worli
- And more...

### API Response Format
```json
{
  "success": true,
  "ward_name": "Andheri East",
  "prediction": "Medium",
  "confidence": 75.0,
  "coordinates": {"lat": 19.1197, "lng": 72.8697}
}
```

## 🚨 Troubleshooting

**Deployment fails?**
- Check that all files are in the root directory
- Verify `vercel.json` configuration
- Ensure `requirements.txt` has correct dependencies

**API not working?**
- Check Vercel function logs
- Verify Python version compatibility
- Test API endpoints individually

**Frontend not loading?**
- Check `index.html` base href is set to `/`
- Verify static assets are in correct locations
- Test with browser dev tools

## 📞 Need Help?

1. Check `DEPLOYMENT_README.md` for detailed instructions
2. Review Vercel deployment logs  
3. Test with `test_deployment.py` script
4. Verify all configuration files are present

---

**Ready to deploy? Run `deploy.bat` (Windows) or `./deploy.sh` (Mac/Linux) to get started! 🚀**
