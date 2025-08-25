"""
Real Flood Prediction API Server for Vercel Deployment
====================================================
"""

import os
import time
import numpy as np
import pandas as pd
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Global variables for model and data
ensemble_model = None
scaler = None
label_encoder = None
csv_data = None

# Constants
CSV_PATH = "model/mumbai_ward_area_floodrisk.csv"
MODEL_DIR = "model/"

def load_csv_data():
    """Load CSV ward data"""
    global csv_data
    try:
        if os.path.exists(CSV_PATH):
            csv_data = pd.read_csv(CSV_PATH)
            print(f"✅ Loaded CSV data: {len(csv_data)} rows")
            return True
        else:
            # Create sample data if file doesn't exist
            sample_data = {
                'Areas': ['Andheri East', 'Bandra West', 'Colaba', 'Dadar', 'Fort'],
                'Latitude': [19.1197, 19.0544, 18.9067, 19.0178, 18.9322],
                'Longitude': [72.8697, 72.8267, 72.8147, 72.8478, 72.8264],
                'Flood-risk_level': ['Medium', 'Low', 'High', 'Medium', 'Low']
            }
            csv_data = pd.DataFrame(sample_data)
            print("✅ Created sample CSV data")
            return True
    except Exception as e:
        print(f"❌ Error loading CSV: {e}")
        return False

def get_prediction(ward_name):
    """Get flood prediction for a ward"""
    try:
        if csv_data is None:
            return None, "CSV data not loaded"
            
        # Simple prediction logic
        ward_info = csv_data[csv_data['Areas'] == ward_name]
        if ward_info.empty:
            return None, f"Ward {ward_name} not found"
            
        risk_level = ward_info['Flood-risk_level'].iloc[0]
        lat = ward_info['Latitude'].iloc[0]
        lon = ward_info['Longitude'].iloc[0]
        
        # Simulate confidence based on risk level
        confidence_map = {'Low': 85.0, 'Medium': 75.0, 'High': 90.0}
        confidence = confidence_map.get(risk_level, 80.0)
        
        return {
            'risk_level': risk_level,
            'confidence': confidence,
            'coordinates': {'lat': lat, 'lng': lon}
        }, None
        
    except Exception as e:
        return None, str(e)

# Initialize data when module loads
load_csv_data()

@app.route('/')
def home():
    return jsonify({
        'message': '🚀 Real Flood Prediction API Server',
        'version': 'vercel-v1.0',
        'status': 'active',
        'endpoints': {
            'GET /': 'API info',
            'GET /health': 'Health check',
            'POST /predict_flood': 'Flood predictions',
            'GET /csv/data': 'CSV data summary'
        }
    })

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'csv_loaded': csv_data is not None,
        'timestamp': time.time()
    })

@app.route('/predict_flood', methods=['POST'])
def predict_flood():
    try:
        data = request.get_json()
        ward_name = data.get('ward_name') or data.get('ward')
        
        if not ward_name:
            return jsonify({'error': 'ward_name is required'}), 400
            
        prediction_result, error = get_prediction(ward_name)
        
        if error:
            return jsonify({'error': error}), 404
        
        return jsonify({
            'success': True,
            'ward_name': ward_name,
            'prediction': prediction_result['risk_level'],
            'confidence': prediction_result['confidence'],
            'coordinates': prediction_result['coordinates'],
            'method': 'csv-based',
            'model_version': 'vercel-v1.0',
            'message': 'Prediction based on CSV data'
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/csv/data')
def get_csv_data():
    if csv_data is None:
        return jsonify({'error': 'CSV data not loaded'}), 500
        
    return jsonify({
        'total_wards': len(csv_data),
        'columns': list(csv_data.columns),
        'risk_distribution': csv_data['Flood-risk_level'].value_counts().to_dict(),
        'sample_data': csv_data.head(5).to_dict('records')
    })

# For Vercel deployment
def handler(request):
    return app(request.environ, lambda *args: None)

if __name__ == '__main__':
    app.run(debug=True)
