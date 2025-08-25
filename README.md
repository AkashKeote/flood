# Mumbai Flood Prediction System 🌊

An intelligent flood prediction system for Mumbai wards using machine learning, real-time weather data, and Flutter mobile app integration.

## 🎯 Features

### Machine Learning Model
- **Optimized ensemble model** using Random Forest + XGBoost
- **Trained on Mumbai 2023 monsoon data** with comprehensive rainfall patterns
- **Ward-specific predictions** for 103 Mumbai areas
- **Cross-validation and hyperparameter tuning** to prevent overfitting/underfitting
- **Handles API-CSV data differences** with intelligent feature engineering

### Real-time Integration
- **OpenWeather API integration** for live weather data
- **Flask REST API** for seamless mobile app communication
- **Mumbai ward coordinates** with risk level mapping
- **Fallback predictor** for offline functionality

### Flutter Mobile App
- **Mumbai ward selection** with intuitive UI
- **Real-time flood risk predictions** with confidence scores
- **Weather data visualization** (temperature, humidity, rainfall)
- **Enhanced mapping** with proper road networks
- **POI categories** (hospitals, police stations, etc.)
- **Risk-colored visualization** for easy understanding

## 🚀 Quick Setup

### 1. Automated Setup
Run the setup script to install everything automatically:

```bash
python setup.py
```

### 2. Manual Setup

#### Backend Setup
```bash
# Install Python dependencies
pip install pandas numpy scikit-learn xgboost flask flask-cors requests matplotlib seaborn

# Train the model (optional)
cd model
python flood_prediction_model.py

# Start the API server
cd ../api
python flood_api_server.py
```

#### Flutter Setup
```bash
# Install Flutter dependencies
flutter pub get

# Run the app
flutter run
```

## 🌐 API Endpoints

### Flood Prediction
```http
POST /predict_flood
Content-Type: application/json

{
    "ward": "Andheri East"
}
```

### List Mumbai Wards
```http
GET /wards
```

### Health Check
```http
GET /health
```

## 🚨 Usage Examples

### 1. Start the System
```bash
# Terminal 1: Start API server
python api/flood_api_server.py

# Terminal 2: Start Flutter app  
flutter run
```

### 2. Make Predictions
1. Open the Flutter app
2. Select a Mumbai ward from the grid
3. Tap "Predict Flood Risk"
4. View results with confidence scores
5. Check weather data and analysis

## 📊 Available Datasets & Attributes

| Attribute                                      | Link                                                |
|------------------------------------------------|-----------------------------------------------------|
| Dataset                                        | [Dataset](./Dataset)                                |
| Elevation                                      | [Elevation](./Elevation)                            |
| River discharge in the last 24 hours            | [River discharge in the last 24 hours](./River%20discharge%20in%20the%20last%2024%20hours) |
| Runoff equivalent and Soil Wetness Index        | [Runoff equivalent and Soil Wetness Index](./Runoff%20equivalent%20and%20Soil%20Wetness%20Index) |
| Distance to water bodies                        | [Distance to water bodies](./distance%20to%20water%20bodies) |
| Drainage                                       | [Drainage](./drainage)                              |
| Landuse class                                  | [Landuse class](./landuse%20class)                  |
| Population                                     | [Population](./population)                          |
| Rainfall                                       | [Rainfall](./rainfall)                              |
| Road density                                   | [Road density](./road%20density)                    |

---

**Happy flood predicting! 🌊🏙️**

Stay safe and help keep Mumbai resilient against flooding with intelligent predictions.
