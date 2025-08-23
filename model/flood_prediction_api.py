"""
Flood Prediction API Server
===========================
Flask API for serving flood predictions to Flutter app
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import pandas as pd
import numpy as np
import requests
from datetime import datetime
import os
import logging
from improved_flood_prediction_model import AdvancedFloodPredictor

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter app

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global model instance
predictor = None

def load_model():
    """Load the trained model"""
    global predictor
    try:
        predictor = AdvancedFloodPredictor()
        predictor.load_model("model_files")
        logger.info("✅ Model loaded successfully!")
        return True
    except Exception as e:
        logger.error(f"❌ Error loading model: {e}")
        return False

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'model_loaded': predictor is not None
    })

@app.route('/predict', methods=['POST'])
def predict_flood_risk():
    """
    Predict flood risk based on weather data
    
    Request body:
    {
        "weather_data": {
            "precipitation": 15.5,
            "humidity": 85,
            "wind_speed": 3.2,
            "temperature": 28.5
        },
        "area_data": {
            "ward_code": 1,
            "latitude": 19.0760,
            "longitude": 72.8777,
            "elevation": 10
        }
    }
    """
    try:
        if predictor is None:
            return jsonify({
                'error': 'Model not loaded',
                'message': 'Please ensure model is properly trained and loaded'
            }), 500
        
        data = request.get_json()
        
        # Extract weather data
        weather_data = data.get('weather_data', {})
        area_data = data.get('area_data', {})
        
        # Make prediction
        result = predictor.predict_flood_risk(weather_data, area_data)
        
        if result is None:
            return jsonify({
                'error': 'Prediction failed',
                'message': 'Unable to make prediction with provided data'
            }), 400
        
        # Add API metadata
        result['api_version'] = '1.0'
        result['model_version'] = 'advanced_ensemble'
        
        logger.info(f"Prediction made: {result['predicted_risk_level']} (confidence: {result['confidence']})")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error in prediction: {e}")
        return jsonify({
            'error': 'Internal server error',
            'message': str(e)
        }), 500

@app.route('/predict/live', methods=['GET'])
def predict_with_live_weather():
    """
    Predict flood risk using live weather data
    
    Query parameters:
    - lat: latitude (default: 19.0760 for Mumbai)
    - lon: longitude (default: 72.8777 for Mumbai)
    """
    try:
        if predictor is None:
            return jsonify({
                'error': 'Model not loaded',
                'message': 'Please ensure model is properly trained and loaded'
            }), 500
        
        # Get coordinates from query parameters
        lat = float(request.args.get('lat', 19.0760))
        lon = float(request.args.get('lon', 72.8777))
        
        # Fetch live weather data
        weather_data = predictor.get_live_weather_data(lat, lon)
        
        if weather_data is None:
            return jsonify({
                'error': 'Weather data unavailable',
                'message': 'Unable to fetch live weather data'
            }), 503
        
        # Create area data from coordinates
        area_data = {
            'latitude': lat,
            'longitude': lon
        }
        
        # Make prediction
        result = predictor.predict_flood_risk(weather_data, area_data)
        
        if result is None:
            return jsonify({
                'error': 'Prediction failed',
                'message': 'Unable to make prediction with live weather data'
            }), 400
        
        # Add API metadata
        result['api_version'] = '1.0'
        result['model_version'] = 'advanced_ensemble'
        result['data_source'] = 'live_weather'
        result['coordinates'] = {'lat': lat, 'lon': lon}
        
        logger.info(f"Live prediction made: {result['predicted_risk_level']} (confidence: {result['confidence']})")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error in live prediction: {e}")
        return jsonify({
            'error': 'Internal server error',
            'message': str(e)
        }), 500

@app.route('/areas/mumbai', methods=['GET'])
def get_mumbai_areas():
    """Get predefined Mumbai areas with their coordinates and characteristics"""
    mumbai_areas = [
        {
            'name': 'Colaba',
            'ward': 'A',
            'latitude': 18.9151,
            'longitude': 72.8141,
            'elevation': 6,
            'population': 185000,
            'built_up_percent': 90,
            'land_use': 'commercial_mixed'
        },
        {
            'name': 'Ballard Estate',
            'ward': 'A',
            'latitude': 18.9496,
            'longitude': 72.8414,
            'elevation': 17,
            'population': 185000,
            'built_up_percent': 90,
            'land_use': 'commercial_institutional'
        },
        {
            'name': 'Fort',
            'ward': 'A',
            'latitude': 18.9320,
            'longitude': 72.8347,
            'elevation': 12,
            'population': 185000,
            'built_up_percent': 95,
            'land_use': 'commercial'
        },
        {
            'name': 'Bandra',
            'ward': 'H/West',
            'latitude': 19.0596,
            'longitude': 72.8295,
            'elevation': 15,
            'population': 250000,
            'built_up_percent': 85,
            'land_use': 'residential_commercial'
        },
        {
            'name': 'Andheri',
            'ward': 'K/West',
            'latitude': 19.1136,
            'longitude': 72.8697,
            'elevation': 25,
            'population': 400000,
            'built_up_percent': 80,
            'land_use': 'residential_mixed'
        },
        {
            'name': 'Dadar',
            'ward': 'G/North',
            'latitude': 19.0176,
            'longitude': 72.8562,
            'elevation': 8,
            'population': 300000,
            'built_up_percent': 88,
            'land_use': 'residential_commercial'
        }
    ]
    
    return jsonify({
        'areas': mumbai_areas,
        'total_areas': len(mumbai_areas)
    })

@app.route('/predict/area/<area_name>', methods=['GET'])
def predict_for_specific_area(area_name):
    """Predict flood risk for a specific Mumbai area using live weather"""
    try:
        if predictor is None:
            return jsonify({
                'error': 'Model not loaded',
                'message': 'Please ensure model is properly trained and loaded'
            }), 500
        
        # Get Mumbai areas
        response = get_mumbai_areas()
        mumbai_areas = response.get_json()['areas']
        
        # Find the specified area
        area_info = None
        for area in mumbai_areas:
            if area['name'].lower() == area_name.lower():
                area_info = area
                break
        
        if area_info is None:
            return jsonify({
                'error': 'Area not found',
                'message': f'Area "{area_name}" not found in Mumbai areas',
                'available_areas': [area['name'] for area in mumbai_areas]
            }), 404
        
        # Fetch live weather data for this area
        weather_data = predictor.get_live_weather_data(
            area_info['latitude'], 
            area_info['longitude']
        )
        
        if weather_data is None:
            return jsonify({
                'error': 'Weather data unavailable',
                'message': f'Unable to fetch live weather data for {area_name}'
            }), 503
        
        # Create area data
        area_data = {
            'Ward Code': 1,  # Default encoding
            'latitude': area_info['latitude'],
            'longitude': area_info['longitude'],
            'elevation': area_info['elevation'],
            'Population': area_info['population'],
            'Built_up_percent': area_info['built_up_percent']
        }
        
        # Make prediction
        result = predictor.predict_flood_risk(weather_data, area_data)
        
        if result is None:
            return jsonify({
                'error': 'Prediction failed',
                'message': f'Unable to make prediction for {area_name}'
            }), 400
        
        # Add area information to result
        result['area_info'] = area_info
        result['api_version'] = '1.0'
        result['model_version'] = 'advanced_ensemble'
        result['data_source'] = 'live_weather'
        
        logger.info(f"Area prediction for {area_name}: {result['predicted_risk_level']} (confidence: {result['confidence']})")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error in area prediction: {e}")
        return jsonify({
            'error': 'Internal server error',
            'message': str(e)
        }), 500

@app.route('/model/info', methods=['GET'])
def model_info():
    """Get information about the loaded model"""
    try:
        if predictor is None:
            return jsonify({
                'error': 'Model not loaded',
                'message': 'Please ensure model is properly trained and loaded'
            }), 500
        
        info = {
            'model_type': 'Advanced Ensemble Classifier',
            'algorithms': ['Random Forest', 'XGBoost', 'LightGBM', 'Extra Trees'],
            'features_count': len(predictor.feature_names) if predictor.feature_names is not None else 0,
            'target_classes': list(predictor.target_encoder.classes_) if predictor.target_encoder else [],
            'api_version': '1.0',
            'model_version': 'advanced_ensemble',
            'last_loaded': datetime.now().isoformat()
        }
        
        return jsonify(info)
        
    except Exception as e:
        logger.error(f"Error getting model info: {e}")
        return jsonify({
            'error': 'Internal server error',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    print("🌊 Starting Flood Prediction API Server...")
    
    # Load model on startup
    if load_model():
        print("✅ Model loaded successfully!")
        print("🚀 Starting Flask server...")
        print("📝 Available endpoints:")
        print("   GET  /health - Health check")
        print("   POST /predict - Predict with custom data")
        print("   GET  /predict/live - Predict with live weather")
        print("   GET  /predict/area/<area_name> - Predict for specific area")
        print("   GET  /areas/mumbai - Get Mumbai areas")
        print("   GET  /model/info - Model information")
        print("\n🌐 Server will run on http://localhost:5000")
        
        app.run(host='0.0.0.0', port=5000, debug=True)
    else:
        print("❌ Failed to load model. Please train the model first.")
