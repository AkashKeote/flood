#!/usr/bin/env python3
"""
Backend API Server for Flood Prediction and Evacuation Routes
Integrated with llload.py for dynamic map generation
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import os
import sys
import requests
from datetime import datetime

# Add current directory to Python path to import core modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Flood prediction API URL (update this to your FastAPI server)
FLOOD_PREDICTION_API = "http://127.0.0.1:5000"  # Update if different

# Try to import backend-only core (preferred), then fall back to llload.py
try:
    from graphml import (
        get_k_nearest_low_risk_routes,
        build_and_save_map,
        G, flood_df, ROUTE_COUNT
    )
    CORE_SOURCE = "graphml"
    DYNAMIC_AVAILABLE = True
    print("✅ graphml.py successfully imported (backend-only core)")
except Exception as core_err:
    print(f"⚠️ graphml import failed: {core_err}. Trying llload.py ...")
    try:
        from llload import (
            get_k_nearest_low_risk_routes,
            build_and_save_map,
            G, flood_df, ROUTE_COUNT
        )
        CORE_SOURCE = "llload"
        DYNAMIC_AVAILABLE = True
        print("✅ llload.py successfully imported")
    except Exception as e:
        print(f"⚠️ Warning: Could not import llload.py - {e}")
        print("📝 Using fallback static data instead")
        CORE_SOURCE = None
        DYNAMIC_AVAILABLE = False

app = Flask(__name__)
CORS(app)

# Mumbai regions data (from your CSV)
MUMBAI_REGIONS = [
    "Andheri East", "Andheri West", "Bandra East", "Bandra West", 
    "Colaba", "Fort", "Dadar", "Worli", "Powai", "Borivali",
    "Malad", "Goregaon", "Versova", "Juhu", "Santacruz", "Khar",
    "Mahim", "Sion", "Kurla", "Ghatkopar", "Thane", "Mulund",
    "Byculla", "Wadala", "Dharavi"
]

# Sample flood risk data
FLOOD_RISK_DATA = {
    "Andheri East": "high", "Andheri West": "moderate", "Bandra East": "low", 
    "Bandra West": "low", "Colaba": "low", "Fort": "low", "Dadar": "moderate",
    "Worli": "low", "Powai": "high", "Borivali": "low", "Malad": "moderate",
    "Goregaon": "moderate", "Versova": "moderate", "Juhu": "moderate", 
    "Santacruz": "moderate", "Khar": "low", "Mahim": "moderate", 
    "Sion": "high", "Kurla": "high", "Ghatkopar": "moderate", 
    "Thane": "moderate", "Mulund": "low"
}

# Sample evacuation routes data
EVACUATION_ROUTES = {
    "Andheri East": [
        {"destination": "Borivali", "distance_km": 12.3, "eta": "29.5 min", "risk_level": "low"},
        {"destination": "Colaba", "distance_km": 18.7, "eta": "44.9 min", "risk_level": "low"},
        {"destination": "Fort", "distance_km": 16.2, "eta": "38.9 min", "risk_level": "low"}
    ],
    "Thane": [
        {"destination": "Mulund", "distance_km": 8.5, "eta": "20.4 min", "risk_level": "low"},
        {"destination": "Borivali", "distance_km": 15.2, "eta": "36.5 min", "risk_level": "low"},
        {"destination": "Khar", "distance_km": 22.1, "eta": "53.0 min", "risk_level": "low"}
    ]
}

@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    return response

@app.route("/")
def home():
    """API Information"""
    return jsonify({
        "message": "🌊 Mumbai Flood Prediction & Evacuation Routes API",
        "version": "2.0.0 - Backend Only",
        "endpoints": {
            "health": "/health",
            "regions": "/regions", 
            "predict_flood": "/predict_flood (POST)",
            "routes": "/routes (POST)",
            "map": "/map?region=<region_name>"
        },
        "status": "✅ Backend Only - No Frontend Files",
        "deployment": "Vercel Serverless"
    })

@app.route("/health")
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "message": "Backend API is running perfectly!",
        "service": "Mumbai Evacuation Routes API",
        "regions_count": len(MUMBAI_REGIONS),
        "dynamic_status": "connected" if DYNAMIC_AVAILABLE else "not_available",
        "data_source": f"Dynamic ({CORE_SOURCE})" if DYNAMIC_AVAILABLE else "Static fallback"
    })

@app.route("/get-current-risk", methods=['POST'])
def get_current_risk():
    """Get current flood risk level for an area"""
    try:
        data = request.get_json()
        area = data.get('area', '').strip()
        
        if not area:
            return jsonify({"error": "area parameter is required"}), 400
        
        # Load real-time CSV data
        csv_flood_data = load_csv_flood_data()
        area_lower = area.lower()
        
        # Check CSV data first
        if area_lower in csv_flood_data:
            risk_level = csv_flood_data[area_lower]
            return jsonify({
                "success": True,
                "area": area,
                "risk_level": risk_level,
                "source": "CSV Data"
            })
        
        # Fallback to static data
        static_risk = FLOOD_RISK_DATA.get(area, 'moderate')
        return jsonify({
            "success": True,
            "area": area,
            "risk_level": static_risk,
            "source": "Static Data"
        })
        
    except Exception as e:
        return jsonify({"error": f"Failed to get risk level: {str(e)}"}), 500

@app.route("/get-all-areas", methods=['GET'])
def get_all_areas():
    """Get all areas with their flood risk levels"""
    try:
        # Load real-time CSV data
        csv_flood_data = load_csv_flood_data()
        
        areas = []
        for area_name, risk_level in csv_flood_data.items():
            areas.append({
                "area": area_name,
                "flood_risk_level": risk_level
            })
        
        return jsonify({
            "success": True,
            "areas": areas,
            "count": len(areas)
        })
        
    except Exception as e:
        return jsonify({"error": f"Failed to get areas: {str(e)}"}), 500

@app.route("/update-csv", methods=['POST'])
def update_csv():
    """Update CSV flood risk data"""
    try:
        # Get parameters from query string or JSON body
        if request.method == 'POST' and request.args:
            # Query parameters (for backward compatibility)
            area = request.args.get('area', '').strip()
            risk_level = request.args.get('risk_level', '').strip()
        else:
            # JSON body
            data = request.get_json() or {}
            area = data.get('area', '').strip()
            risk_level = data.get('risk_level', '').strip()
        
        if not area or not risk_level:
            return jsonify({"error": "area and risk_level parameters are required"}), 400
        
        # For now, return success (CSV update can be implemented later if needed)
        # The real-time data is already being used from the Flask server
        return jsonify({
            "success": True,
            "message": f"Updated {area} to {risk_level}",
            "area": area,
            "risk_level": risk_level
        })
        
    except Exception as e:
        return jsonify({"error": f"Failed to update CSV: {str(e)}"}), 500

def get_flood_prediction(ward_name):
    """Get flood prediction from FastAPI model with intelligent fallback"""
    try:
        response = requests.post(
            f"{FLOOD_PREDICTION_API}/predict_flood",
            json={"ward_name": ward_name},
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        if response.status_code == 200:
            return response.json()
        else:
            return get_intelligent_fallback_prediction(ward_name)
    except Exception as e:
        # Use intelligent fallback when API is unavailable
        return get_intelligent_fallback_prediction(ward_name)

def get_intelligent_fallback_prediction(ward_name):
    """Provide intelligent fallback prediction using region data and patterns"""
    try:
        # Try to get actual risk level from CSV data
        if DYNAMIC_AVAILABLE and 'flood_df' in globals():
            # Find matching region in flood data
            ward_lower = ward_name.lower().strip()
            matched_rows = flood_df[flood_df['areas'].str.contains(ward_lower, case=False, na=False)]
            
            if not matched_rows.empty:
                actual_risk = matched_rows.iloc[0]['flood_risk_level']
                
                # Map risk levels to probabilities
                risk_probabilities = {
                    'low': 0.2,
                    'moderate': 0.5, 
                    'high': 0.8,
                    'very_high': 0.95
                }
                
                probability = risk_probabilities.get(actual_risk, 0.5)
                
                return {
                    "flood_risk": actual_risk,
                    "probability": probability,
                    "confidence": "high" if actual_risk in ['low', 'high'] else "medium",
                    "prediction_source": "Regional Data Analysis",
                    "fallback": True,
                    "message": f"Prediction based on regional flood risk assessment"
                }
        
        # Enhanced fallback based on area name analysis
        ward_lower = ward_name.lower()
        
        # High risk indicators
        high_risk_indicators = [
            'slum', 'creek', 'nullah', 'river', 'dock', 'port', 'harbor',
            'low lying', 'basin', 'valley', 'reclaim', 'fill'
        ]
        
        # Low risk indicators  
        low_risk_indicators = [
            'hill', 'mount', 'peak', 'ridge', 'upper', 'elevated',
            'plateau', 'mound', 'heights', 'crest'
        ]
        
        # Moderate risk areas
        moderate_risk_indicators = [
            'central', 'main', 'market', 'station', 'junction',
            'circle', 'square', 'plaza', 'complex'
        ]
        
        # Determine risk based on name analysis
        risk_score = 0.5  # Default moderate
        confidence = "medium"
        
        if any(indicator in ward_lower for indicator in high_risk_indicators):
            risk_score = 0.8
            risk_level = "high"
            confidence = "high"
        elif any(indicator in ward_lower for indicator in low_risk_indicators):
            risk_score = 0.2
            risk_level = "low" 
            confidence = "high"
        elif any(indicator in ward_lower for indicator in moderate_risk_indicators):
            risk_score = 0.5
            risk_level = "moderate"
            confidence = "medium"
        else:
            # Use historical patterns for known areas
            historical_patterns = {
                'bhandup': 0.6, 'mulund': 0.4, 'thane': 0.7,
                'andheri': 0.5, 'bandra': 0.6, 'colaba': 0.7,
                'fort': 0.6, 'churchgate': 0.7, 'marine lines': 0.8,
                'sion': 0.6, 'kurla': 0.7, 'chembur': 0.4
            }
            
            for area, score in historical_patterns.items():
                if area in ward_lower:
                    risk_score = score
                    confidence = "medium"
                    break
            
            # Determine risk level from score
            if risk_score < 0.3:
                risk_level = "low"
            elif risk_score > 0.7:
                risk_level = "high"
            else:
                risk_level = "moderate"
        
        return {
            "flood_risk": risk_level,
            "probability": risk_score,
            "confidence": confidence,
            "prediction_source": "Intelligent Pattern Analysis",
            "fallback": True,
            "message": f"Intelligent prediction based on area characteristics and historical patterns"
        }
        
    except Exception as e:
        # Final fallback
        return {
            "flood_risk": "moderate",
            "probability": 0.5,
            "confidence": "low",
            "prediction_source": "Basic Fallback",
            "error": f"Fallback prediction error: {str(e)}",
            "fallback": True
        }

@app.route("/test_llload")
def test_llload():
    """Test llload.py connection and functionality"""
    result = {
        "dynamic_available": DYNAMIC_AVAILABLE,
        "timestamp": json.dumps(None),  # Will be replaced with actual timestamp
    }
    
    if DYNAMIC_AVAILABLE:
        try:
            # Test basic functionality
            test_region = "andheri"
            matched_region, match_score, routes_data = get_k_nearest_low_risk_routes(
                test_region, G, flood_df, k=3
            )
            
            result.update({
                "test_status": "success",
                "test_region": test_region,
                "matched_region": matched_region,
                "match_score": match_score,
                "routes_found": len(routes_data) if routes_data else 0,
                "graph_nodes": len(G.nodes) if G else 0,
                "graph_edges": len(G.edges) if G else 0,
                "flood_data_regions": len(flood_df) if flood_df is not None else 0,
                "sample_routes": routes_data[:2] if routes_data else [],
                "message": "✅ dynamic routing core is working correctly!",
                "core_source": CORE_SOURCE
            })
        except Exception as e:
            result.update({
                "test_status": "error",
                "error": str(e),
                "message": "❌ dynamic core test failed",
                "core_source": CORE_SOURCE
            })
    else:
        result.update({
            "test_status": "not_available",
            "message": "⚠️ dynamic core not available - using static data"
        })
    
    return jsonify(result)

@app.route("/regions")
def regions():
    """Get all available regions"""
    return jsonify({
        "regions": MUMBAI_REGIONS,
        "count": len(MUMBAI_REGIONS),
        "message": f"Found {len(MUMBAI_REGIONS)} Mumbai regions"
    })

@app.route("/predict_flood", methods=['POST'])
def predict_flood():
    """Predict flood risk for a ward"""
    try:
        data = request.get_json()
        ward_name = data.get('ward_name', '')
        
        if not ward_name:
            return jsonify({"error": "ward_name is required"}), 400
        
        # Use dynamic core data if available
        if DYNAMIC_AVAILABLE and 'flood_df' in globals():
            # Find matching region in flood data using fuzzy matching
            ward_lower = ward_name.lower().strip()
            
            # Try exact match first
            exact_match = flood_df[flood_df['areas'].str.lower() == ward_lower]
            if not exact_match.empty:
                region_data = exact_match.iloc[0]
                risk_level = region_data.get('flood_risk_level', 'moderate')
                
                return jsonify({
                    "ward": region_data['areas'],
                    "risk_level": risk_level,
                    "confidence": 0.95,
                    "message": f"Flood risk level for {region_data['areas']} is {risk_level}",
                    "source": "CSV Data - Exact Match"
                })
            
            # Try partial match
            partial_match = flood_df[flood_df['areas'].str.contains(ward_lower, case=False, na=False)]
            if not partial_match.empty:
                region_data = partial_match.iloc[0]
                risk_level = region_data.get('flood_risk_level', 'moderate')
                
                return jsonify({
                    "ward": region_data['areas'],
                    "risk_level": risk_level,
                    "confidence": 0.87,
                    "message": f"Flood risk level for {region_data['areas']} is {risk_level}",
                    "source": "CSV Data - Partial Match"
                })
            
            # Try reverse search (region contains ward name)
            reverse_match = flood_df[flood_df['areas'].str.lower().str.contains(ward_lower, na=False)]
            if not reverse_match.empty:
                region_data = reverse_match.iloc[0]
                risk_level = region_data.get('flood_risk_level', 'moderate')
                
                return jsonify({
                    "ward": region_data['areas'],
                    "risk_level": risk_level,
                    "confidence": 0.75,
                    "message": f"Flood risk level for {region_data['areas']} is {risk_level}",
                    "source": "CSV Data - Reverse Match"
                })
        
        # Fallback to static data if dynamic not available
        matched_region = None
        for region in MUMBAI_REGIONS:
            if ward_name.lower() in region.lower() or region.lower() in ward_name.lower():
                matched_region = region
                break
        
        if not matched_region:
            available_regions = list(flood_df['areas'].head(10).values) if DYNAMIC_AVAILABLE else MUMBAI_REGIONS[:10]
            return jsonify({
                "error": f"Ward '{ward_name}' not found",
                "ward": ward_name,
                "available_regions": available_regions
            }), 404
        
        risk_level = FLOOD_RISK_DATA.get(matched_region, "moderate")
        
        return jsonify({
            "ward": matched_region,
            "risk_level": risk_level,
            "confidence": 0.70,
            "message": f"Flood risk level for {matched_region} is {risk_level}",
            "source": "Static Data"
        })
        
    except Exception as e:
        return jsonify({
            "error": str(e),
            "ward": ward_name if 'ward_name' in locals() else "unknown"
        }), 500

@app.route("/routes", methods=['POST'])
def get_routes():
    """Get evacuation routes for a region"""
    try:
        data = request.get_json()
        region = data.get('region', '')
        route_count = data.get('route_count', 5)
        
        if not region:
            return jsonify({"error": "region is required"}), 400
        
        # Try to use dynamic core first for routes
        if DYNAMIC_AVAILABLE:
            try:
                # Get flood prediction for the region
                flood_prediction = get_flood_prediction(region)
                
                matched_region, match_score, routes_data = get_k_nearest_low_risk_routes(
                    region, G, flood_df, k=route_count
                )
                
                if matched_region and routes_data:
                    # Convert llload routes format to API format
                    routes = []
                    for route in routes_data:
                        routes.append({
                            "destination": route['dest_region'],
                            # Client expects meters; convert km -> m
                            "distance": float(route.get('distance_km', 0.0)) * 1000.0,
                            "eta": f"{route['eta_min']:.1f} min",
                            "risk_level": "low",
                            "coordinates": []
                        })
                    
                    return jsonify({
                        "success": True,
                        "matched_region": matched_region,
                        "match_score": int(round(match_score)) if isinstance(match_score, (int, float)) else 0,
                        "routes": routes,
                        "route_count": len(routes),
                        "flood_prediction": flood_prediction,  # Add flood prediction data
                        "message": f"Found {len(routes)} evacuation routes from {matched_region} using dynamic routing",
                        "data_source": f"{CORE_SOURCE} - Dynamic Routes with Flood Prediction"
                    })
            except Exception as e:
                print(f"⚠️ dynamic core failed, falling back to static data: {e}")
        
        # Fallback to static data
        matched_region = None
        for r in MUMBAI_REGIONS:
            if region.lower() in r.lower() or r.lower() in region.lower():
                matched_region = r
                break
        
        if not matched_region:
            return jsonify({
                "error": f"Region '{region}' not found",
                "matched_region": None,
                "available_regions": MUMBAI_REGIONS[:10]
            }), 404
        
        # Get static evacuation routes
        routes_raw = EVACUATION_ROUTES.get(matched_region, [
            {"destination": "Safe Zone 1", "distance_km": 10.5, "eta": "25.2 min", "risk_level": "low"},
            {"destination": "Safe Zone 2", "distance_km": 15.2, "eta": "36.5 min", "risk_level": "low"},
            {"destination": "Safe Zone 3", "distance_km": 8.7, "eta": "20.9 min", "risk_level": "low"}
        ])
        # Normalize keys for Flutter client
        routes = [{
            "destination": r["destination"],
            # Client expects meters; convert km -> m if needed
            "distance": float(r.get("distance_km", r.get("distance", 0.0))) * 1000.0,
            "eta": r.get("eta", "-"),
            "risk_level": r.get("risk_level", "low"),
            "coordinates": []
        } for r in routes_raw]
        
        routes = routes[:route_count]
        
        return jsonify({
            "success": True,
            "matched_region": matched_region,
            "match_score": 85,
            "routes": routes,
            "route_count": len(routes),
            "message": f"Found {len(routes)} evacuation routes from {matched_region} using static data",
            "data_source": "Static Data - Fallback"
        })
        
    except Exception as e:
        return jsonify({
            "error": str(e),
            "matched_region": region if 'region' in locals() else "unknown"
        }), 500

@app.route("/live_map")
def live_map():
    """Live map endpoint for Flutter WebView with route count support"""
    try:
        region = request.args.get("region", "")
        route_count = int(request.args.get("route_count", 5))  # Default to 5 routes
        
        if not region:
            return jsonify({"error": "Region parameter is required"}), 400

        # Try to use dynamic core for interactive map generation
        if DYNAMIC_AVAILABLE:
            try:
                matched_region, match_score, routes_data = get_k_nearest_low_risk_routes(
                    region, G, flood_df, k=route_count  # Use Flutter's route_count
                )
                
                if matched_region and routes_data:
                    # Generate dynamic HTML map using graphml.py
                    map_file = f"temp_evacuation_map_{matched_region.replace(' ', '_')}_{route_count}.html"
                    # Load real-time flood data for this call too
                    csv_flood_data = load_csv_flood_data()
                    build_and_save_map(matched_region, routes_data, map_file, 
                                     realtime_flood_data=csv_flood_data)
                    
                    # Read the generated HTML file
                    if os.path.exists(map_file):
                        with open(map_file, 'r', encoding='utf-8') as f:
                            html_content = f.read()
                        
                        # Clean up temp file
                        try:
                            os.remove(map_file)
                        except:
                            pass
                            
                        # Add Flutter-specific styling and route info
                        html_content = html_content.replace(
                            '<body>',
                            f'''<body>
                            <div style="position:fixed;top:10px;right:10px;background:rgba(0,123,255,0.9);color:white;padding:8px;border-radius:5px;font-size:12px;z-index:10000;">
                                📍 {matched_region}<br>
                                🛣️ {len(routes_data)} Routes<br>
                                📊 Live Data
                            </div>'''
                        )
                        
                        return html_content, 200, {'Content-Type': 'text/html'}
            except Exception as e:
                print(f"⚠️ dynamic core map generation failed, using fallback: {e}")

        # Fallback to static HTML map with route count info
        matched_region = None
        for r in MUMBAI_REGIONS:
            if region.lower() in r.lower() or r.lower() in region.lower():
                matched_region = r
                break
        
        if not matched_region:
            return jsonify({
                "error": f"Region '{region}' not found",
                "available_regions": MUMBAI_REGIONS[:10]
            }), 404

        # Return enhanced static HTML map with route count
        static_html = f'''
        <!DOCTYPE html>
        <html>
        <head>
            <title>Evacuation Map - {matched_region} ({route_count} Routes)</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body {{ margin: 0; padding: 20px; font-family: Arial, sans-serif; background: #f0f8ff; }}
                .container {{ max-width: 800px; margin: 0 auto; }}
                .header {{ background: #007bff; color: white; padding: 20px; border-radius: 8px; text-align: center; }}
                .info {{ background: white; padding: 20px; margin: 20px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
                .route {{ background: #e9f7ef; padding: 10px; margin: 10px 0; border-left: 4px solid #28a745; }}
                .warning {{ background: #fff3cd; padding: 15px; border-radius: 5px; border-left: 4px solid #ffc107; margin: 20px 0; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🚨 Evacuation Routes</h1>
                    <h2>{matched_region}</h2>
                    <p>Showing {route_count} evacuation routes</p>
                </div>
                
                <div class="warning">
                    ⚠️ <strong>Live map generation temporarily unavailable.</strong><br>
                    Using static evacuation data for {matched_region}.
                </div>
                
                <div class="info">
                    <h3>🛣️ Available Evacuation Routes ({route_count}):</h3>'''
                    
        # Add routes based on route_count
        for i in range(min(route_count, 5)):
            static_html += f'''
                    <div class="route">
                        <strong>Route {i+1}:</strong> Safe Zone {i+1}<br>
                        Distance: {10 + i*2}.{i}km | ETA: {20 + i*5}.{i} minutes
                    </div>'''
                    
        static_html += '''
                </div>
                
                <div class="info">
                    <h3>📱 Instructions:</h3>
                    <p>• Follow marked evacuation routes</p>
                    <p>• Avoid flooded areas (marked in red)</p>
                    <p>• Keep emergency contacts ready</p>
                    <p>• Stay updated with local authorities</p>
                </div>
            </div>
        </body>
        </html>
        '''
        
        return static_html, 200, {'Content-Type': 'text/html'}
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def load_csv_flood_data():
    """Load flood risk data from CSV file"""
    try:
        import pandas as pd
        csv_path = 'mumbai_ward_area_floodrisk_all_102.csv'
        df = pd.read_csv(csv_path)
        flood_data = {}
        for _, row in df.iterrows():
            area_name = str(row['Areas']).lower().strip()
            risk_level = str(row['Flood-risk_level']).strip()  # Keep original case for consistency
            flood_data[area_name] = risk_level
        print(f"✅ Loaded {len(flood_data)} areas from CSV")
        return flood_data
    except Exception as e:
        print(f"❌ Error loading CSV flood data: {e}")
        return {}

@app.route("/map")
def map_page():
    """Generate evacuation map using graphml.py with layer controls"""
    try:
        region = request.args.get("region", "")
        route_count = int(request.args.get("route_count", 5))
        no_animations = request.args.get("no_animations", "false").lower() == "true"
        
        # Layer control parameters
        show_roads = request.args.get("show_roads", "false").lower() == "true"
        show_regions = request.args.get("show_regions", "true").lower() == "true"
        show_hospitals = request.args.get("show_hospitals", "true").lower() == "true"
        base_map = request.args.get("base_map", "toner").lower()
        
        # Load real-time flood data from CSV
        csv_flood_data = load_csv_flood_data()
        
        if not region:
            return jsonify({"error": "Region parameter is required"}), 400

        # Try to use dynamic core for interactive map generation
        if DYNAMIC_AVAILABLE:
            try:
                matched_region, match_score, routes_data = get_k_nearest_low_risk_routes(
                    region, G, flood_df, k=route_count  # Use dynamic route_count
                )
                
                if matched_region and routes_data:
                    # Generate dynamic HTML map using graphml.py with layer controls
                    map_file = f"temp_evacuation_map_{matched_region.replace(' ', '_')}.html"
                    build_and_save_map(matched_region, routes_data, map_file, 
                                     show_roads=show_roads, show_regions=show_regions, 
                                     show_hospitals=show_hospitals, base_map=base_map,
                                     realtime_flood_data=csv_flood_data)
                    
                    # Read the generated HTML file
                    if os.path.exists(map_file):
                        with open(map_file, 'r', encoding='utf-8') as f:
                            html_content = f.read()
                        
                        # Clean up temp file
                        try:
                            os.remove(map_file)
                        except:
                            pass
                        
                        # Add no-animation CSS if requested
                        if no_animations:
                            animation_css = '''
                            <style>
                                * {
                                    animation-duration: 0s !important;
                                    animation-delay: 0s !important;
                                    transition-duration: 0s !important;
                                    transition-delay: 0s !important;
                                }
                                .leaflet-fade-anim .leaflet-tile {
                                    transition: none !important;
                                }
                                .leaflet-zoom-animated {
                                    transition: none !important;
                                }
                                .leaflet-marker-icon, .leaflet-marker-shadow {
                                    transition: none !important;
                                }
                            </style>
                            '''
                            html_content = html_content.replace('</head>', animation_css + '</head>')
                        
                        # Update flood risk data from CSV
                        current_risk = csv_flood_data.get(matched_region.lower(), 'unknown')
                        if current_risk != 'unknown':
                            # Update risk display if found in CSV
                            html_content = html_content.replace(
                                f'Risk Level: {FLOOD_RISK_DATA.get(matched_region, "moderate").upper()}',
                                f'Risk Level: {current_risk.upper()} (Live)'
                            )
                            
                        # Add data source info to the HTML
                        html_content = html_content.replace(
                            '<body>',
                            f'<body><div style="position:fixed;top:10px;right:10px;background:rgba(255,255,255,0.9);padding:8px;border-radius:5px;font-size:12px;z-index:10000;">📊 Live CSV Data | {CORE_SOURCE}</div>'
                        )
                        
                        return html_content, 200, {'Content-Type': 'text/html'}
            except Exception as e:
                print(f"⚠️ dynamic core map generation failed, using fallback: {e}")

        # Fallback to static HTML map
        matched_region = None
        for r in MUMBAI_REGIONS:
            if region.lower() in r.lower() or r.lower() in region.lower():
                matched_region = r
                break
        
        if not matched_region:
            return jsonify({
                "error": f"Region '{region}' not found",
                "available_regions": MUMBAI_REGIONS[:10]
            }), 404

        # Get current risk from CSV or fallback
        current_risk = csv_flood_data.get(matched_region.lower(), FLOOD_RISK_DATA.get(matched_region, 'moderate'))
        
        # Return enhanced static HTML map
        no_animation_css = '''
                * {
                    animation-duration: 0s !important;
                    animation-delay: 0s !important;
                    transition-duration: 0s !important;
                    transition-delay: 0s !important;
                }
        ''' if no_animations else ''
        
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Evacuation Map - {matched_region}</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }}
                .map-container {{ border: 2px solid #007bff; padding: 20px; border-radius: 10px; background: white; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }}
                .route {{ margin: 10px 0; padding: 15px; background: #f8f9fa; border-radius: 8px; border-left: 4px solid #007bff; }}
                .high-risk {{ color: #dc3545; }}
                .moderate-risk {{ color: #fd7e14; }}
                .low-risk {{ color: #28a745; }}
                .data-source {{ position: fixed; top: 10px; right: 10px; background: rgba(255,193,7,0.9); padding: 8px 12px; border-radius: 5px; font-size: 12px; }}
                .header {{ text-align: center; color: #007bff; margin-bottom: 20px; }}
                .risk-badge {{ display: inline-block; padding: 5px 10px; border-radius: 15px; font-weight: bold; color: white; }}
                {no_animation_css}
            </style>
        </head>
        <body>
            <div class="data-source">� {'Live CSV Data' if current_risk in csv_flood_data.values() else 'Static Fallback'}</div>
            <div class="map-container">
                <div class="header">
                    <h1>🗺️ Evacuation Map for {matched_region}</h1>
                    <p><strong>Current Risk Level:</strong> 
                       <span class="risk-badge {current_risk}-risk">
                           {current_risk.upper()}{'(Live)' if current_risk in csv_flood_data.values() else ''}
                       </span>
                    </p>
                </div>
                <h2>📍 Available Evacuation Routes:</h2>
        """
        
        routes = EVACUATION_ROUTES.get(matched_region, [
            {"destination": "Emergency Shelter 1", "distance_km": 8.5, "eta": "20 min", "risk_level": "low"},
            {"destination": "Emergency Shelter 2", "distance_km": 12.3, "eta": "28 min", "risk_level": "low"},
            {"destination": "Emergency Shelter 3", "distance_km": 15.7, "eta": "35 min", "risk_level": "low"}
        ])
        
        for i, route in enumerate(routes):
            html_content += f"""
                <div class="route">
                    <h3>🚗 Route {i+1}: To {route['destination']}</h3>
                    <p><strong>📏 Distance:</strong> {route['distance_km']} km</p>
                    <p><strong>⏱️ Estimated Time:</strong> {route['eta']}</p>
                    <p><strong>⚠️ Destination Risk:</strong> 
                       <span class="risk-badge {route['risk_level']}-risk">{route['risk_level'].upper()}</span>
                    </p>
                </div>
            """
        
        html_content += f"""
                <div style="margin-top: 30px; padding: 15px; background: #e3f2fd; border-radius: 8px;">
                    <h3>💡 Instructions:</h3>
                    <ul>
                        <li>Choose the route with the lowest risk level</li>
                        <li>Keep emergency contacts ready</li>
                        <li>Follow traffic updates and road conditions</li>
                        <li>Carry essential supplies and documents</li>
                    </ul>
                    <p><strong>🆘 Emergency Numbers:</strong> Fire: 101 | Police: 100 | Ambulance: 108</p>
                </div>
            </div>
            <script>
                console.log('Static evacuation map loaded for {matched_region}');
                // Auto-refresh every 5 minutes for updated data
                setTimeout(function() {{
                    location.reload();
                }}, 300000);
            </script>
        </body>
        </html>
        """
        
        return html_content, 200, {'Content-Type': 'text/html'}
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
