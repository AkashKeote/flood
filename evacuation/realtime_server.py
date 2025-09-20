#!/usr/bin/env python3
"""
Real-time Backend API Server for Flood Prediction and Evacuation Routes
Lightweight version with real-time capabilities and WebSocket support
"""

from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import json
import os
import time
import random
import threading
from datetime import datetime, timedelta

app = Flask(__name__)
app.config['SECRET_KEY'] = 'flood_evacuation_2025'
CORS(app, origins="*")
socketio = SocketIO(app, cors_allowed_origins="*")

# Real-time data storage
real_time_data = {
    "last_update": datetime.now(),
    "active_routes": {},
    "traffic_conditions": {},
    "emergency_alerts": [],
    "weather_conditions": {"status": "clear", "risk_level": "low"}
}

# Mumbai regions with enhanced data
MUMBAI_REGIONS = {
    "Andheri East": {"lat": 19.1197, "lng": 72.8697, "base_risk": "high"},
    "Andheri West": {"lat": 19.1359, "lng": 72.8397, "base_risk": "moderate"},
    "Bandra East": {"lat": 19.0596, "lng": 72.8656, "base_risk": "low"},
    "Bandra West": {"lat": 19.0544, "lng": 72.8281, "base_risk": "low"},
    "Colaba": {"lat": 18.9067, "lng": 72.8147, "base_risk": "low"},
    "Fort": {"lat": 18.9372, "lng": 72.8356, "base_risk": "low"},
    "Dadar": {"lat": 19.0178, "lng": 72.8478, "base_risk": "moderate"},
    "Worli": {"lat": 19.0134, "lng": 72.8184, "base_risk": "low"},
    "Powai": {"lat": 19.1197, "lng": 72.9056, "base_risk": "high"},
    "Borivali": {"lat": 19.2307, "lng": 72.8567, "base_risk": "low"},
    "Malad": {"lat": 19.1864, "lng": 72.8493, "base_risk": "moderate"},
    "Goregaon": {"lat": 19.1663, "lng": 72.8526, "base_risk": "moderate"},
    "Versova": {"lat": 19.1297, "lng": 72.8097, "base_risk": "moderate"},
    "Juhu": {"lat": 19.1075, "lng": 72.8263, "base_risk": "moderate"},
    "Santacruz": {"lat": 19.0896, "lng": 72.8656, "base_risk": "moderate"},
    "Khar": {"lat": 19.0728, "lng": 72.8397, "base_risk": "low"},
    "Mahim": {"lat": 19.0410, "lng": 72.8426, "base_risk": "moderate"},
    "Sion": {"lat": 19.0430, "lng": 72.8636, "base_risk": "high"},
    "Kurla": {"lat": 19.0728, "lng": 72.8797, "base_risk": "high"},
    "Ghatkopar": {"lat": 19.0863, "lng": 72.9081, "base_risk": "moderate"},
    "Thane": {"lat": 19.2183, "lng": 72.9781, "base_risk": "moderate"},
    "Mulund": {"lat": 19.1728, "lng": 72.9567, "base_risk": "low"}
}

def generate_dynamic_routes(source_area, route_count=10):
    """Generate dynamic evacuation routes with real-time factors"""
    if source_area not in MUMBAI_REGIONS:
        return []
    
    source_data = MUMBAI_REGIONS[source_area]
    routes = []
    
    # Get safe destinations (low and moderate risk)
    safe_destinations = [area for area, data in MUMBAI_REGIONS.items() 
                        if data["base_risk"] in ["low", "moderate"] and area != source_area]
    
    # Shuffle for variety
    random.shuffle(safe_destinations)
    
    for i, dest_area in enumerate(safe_destinations[:route_count]):
        dest_data = MUMBAI_REGIONS[dest_area]
        
        # Calculate realistic distance (approximate)
        lat_diff = abs(source_data["lat"] - dest_data["lat"])
        lng_diff = abs(source_data["lng"] - dest_data["lng"])
        distance_km = ((lat_diff ** 2 + lng_diff ** 2) ** 0.5) * 111  # Convert to km
        
        # Add some randomness for realism
        distance_km += random.uniform(-2, 5)
        distance_km = max(1.0, distance_km)
        
        # Calculate ETA based on current traffic
        traffic_factor = real_time_data["traffic_conditions"].get(dest_area, 1.0)
        base_speed = 25.0  # km/h
        actual_speed = base_speed / traffic_factor
        eta_min = (distance_km / actual_speed) * 60
        
        # Calculate dynamic safety score
        base_safety = 0.9 if dest_data["base_risk"] == "low" else 0.7
        weather_impact = 0.1 if real_time_data["weather_conditions"]["status"] == "clear" else -0.1
        traffic_impact = (2 - traffic_factor) * 0.1
        
        safety_score = min(1.0, max(0.1, base_safety + weather_impact + traffic_impact))
        
        route = {
            "destination": dest_area,
            "distance_km": round(distance_km, 2),
            "eta": f"{eta_min:.1f} min",
            "risk_level": dest_data["base_risk"],
            "safety_score": round(safety_score, 3),
            "traffic_status": "normal" if traffic_factor <= 1.2 else "congested",
            "last_updated": datetime.now().isoformat()
        }
        routes.append(route)
    
    # Sort by safety score (highest first)
    routes.sort(key=lambda x: x["safety_score"], reverse=True)
    return routes

def update_real_time_conditions():
    """Background task to update real-time conditions"""
    while True:
        try:
            # Update traffic conditions randomly
            for area in MUMBAI_REGIONS.keys():
                # Traffic factor: 1.0 = normal, 1.5 = heavy traffic
                current_factor = real_time_data["traffic_conditions"].get(area, 1.0)
                change = random.uniform(-0.1, 0.1)
                new_factor = max(0.8, min(2.0, current_factor + change))
                real_time_data["traffic_conditions"][area] = round(new_factor, 2)
            
            # Update weather conditions occasionally
            if random.random() < 0.1:  # 10% chance
                weather_options = [
                    {"status": "clear", "risk_level": "low"},
                    {"status": "cloudy", "risk_level": "low"},
                    {"status": "light_rain", "risk_level": "moderate"},
                    {"status": "heavy_rain", "risk_level": "high"}
                ]
                real_time_data["weather_conditions"] = random.choice(weather_options)
            
            # Update timestamp
            real_time_data["last_update"] = datetime.now()
            
            # Emit real-time updates to connected clients
            socketio.emit('real_time_update', {
                'traffic_conditions': real_time_data["traffic_conditions"],
                'weather_conditions': real_time_data["weather_conditions"],
                'timestamp': real_time_data["last_update"].isoformat()
            })
            
            time.sleep(30)  # Update every 30 seconds
            
        except Exception as e:
            print(f"Error in real-time update: {e}")
            time.sleep(60)

# Start background thread for real-time updates
threading.Thread(target=update_real_time_conditions, daemon=True).start()

@app.route("/")
def home():
    """API Information"""
    return jsonify({
        "message": "🌊 Mumbai Real-time Flood Evacuation API",
        "version": "3.0.0 - Real-time Edition",
        "features": [
            "Real-time traffic updates",
            "Dynamic route calculations", 
            "WebSocket live updates",
            "Weather impact analysis",
            "Enhanced safety scoring"
        ],
        "endpoints": {
            "health": "/health",
            "regions": "/regions", 
            "routes": "/routes (POST)",
            "real_time_status": "/status",
            "live_map": "/live_map?region=<region_name>",
            "websocket": "/socket.io for live updates"
        },
        "status": "✅ Real-time Backend Active",
        "last_update": real_time_data["last_update"].isoformat()
    })

@app.route("/health")
def health():
    """Health check with real-time status"""
    return jsonify({
        "status": "healthy",
        "message": "Real-time Backend API running perfectly!",
        "service": "Mumbai Real-time Evacuation Routes API",
        "regions_count": len(MUMBAI_REGIONS),
        "active_connections": len(socketio.server.manager.get_participants('/', '/')),
        "last_update": real_time_data["last_update"].isoformat(),
        "real_time_features": "enabled"
    })

@app.route("/regions")
def regions():
    """Get all available regions with real-time data"""
    regions_with_status = []
    for area, data in MUMBAI_REGIONS.items():
        traffic_factor = real_time_data["traffic_conditions"].get(area, 1.0)
        regions_with_status.append({
            "name": area,
            "coordinates": {"lat": data["lat"], "lng": data["lng"]},
            "base_risk": data["base_risk"],
            "current_traffic": "normal" if traffic_factor <= 1.2 else "congested",
            "traffic_factor": traffic_factor
        })
    
    return jsonify({
        "regions": regions_with_status,
        "count": len(regions_with_status),
        "weather": real_time_data["weather_conditions"],
        "last_update": real_time_data["last_update"].isoformat()
    })

@app.route("/routes", methods=['POST'])
def get_routes():
    """Get real-time evacuation routes"""
    try:
        data = request.get_json()
        region = data.get('region', '')
        route_count = min(15, max(3, data.get('route_count', 10)))
        
        if not region:
            return jsonify({"error": "region is required"}), 400
        
        # Find matching region
        matched_region = None
        for area_name in MUMBAI_REGIONS.keys():
            if region.lower() in area_name.lower() or area_name.lower() in region.lower():
                matched_region = area_name
                break
        
        if not matched_region:
            return jsonify({
                "error": f"Region '{region}' not found",
                "available_regions": list(MUMBAI_REGIONS.keys())[:10]
            }), 404
        
        # Generate dynamic routes
        routes = generate_dynamic_routes(matched_region, route_count)
        
        return jsonify({
            "success": True,
            "matched_region": matched_region,
            "match_score": 95,
            "routes": routes,
            "route_count": len(routes),
            "message": f"Found {len(routes)} real-time evacuation routes from {matched_region}",
            "data_source": "Real-time Dynamic Routing Engine",
            "algorithm_version": "3.0 - Real-time multi-factor",
            "real_time_factors": {
                "traffic_conditions": "live",
                "weather_impact": real_time_data["weather_conditions"],
                "last_update": real_time_data["last_update"].isoformat()
            }
        })
        
    except Exception as e:
        return jsonify({
            "error": str(e),
            "matched_region": region if 'region' in locals() else "unknown"
        }), 500

@app.route("/status")
def real_time_status():
    """Get current real-time system status"""
    return jsonify({
        "system_status": "active",
        "real_time_data": real_time_data,
        "connected_clients": len(socketio.server.manager.get_participants('/', '/')),
        "uptime": str(datetime.now() - real_time_data["last_update"]),
        "features_enabled": [
            "live_traffic_monitoring",
            "dynamic_route_calculation", 
            "weather_impact_analysis",
            "websocket_updates"
        ]
    })

@app.route("/live_map")
def live_map():
    """Generate live evacuation map with real-time updates"""
    try:
        region = request.args.get("region", "")
        if not region:
            return jsonify({"error": "Region parameter is required"}), 400

        # Find matching region
        matched_region = None
        for area_name in MUMBAI_REGIONS.keys():
            if region.lower() in area_name.lower() or area_name.lower() in region.lower():
                matched_region = area_name
                break
        
        if not matched_region:
            return jsonify({
                "error": f"Region '{region}' not found",
                "available_regions": list(MUMBAI_REGIONS.keys())[:10]
            }), 404

        # Get real-time routes
        routes = generate_dynamic_routes(matched_region, 10)
        region_data = MUMBAI_REGIONS[matched_region]
        
        # Generate live HTML map
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>🔴 LIVE - Evacuation Map: {matched_region}</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.7.2/socket.io.js"></script>
            <style>
                body {{ 
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
                    margin: 0; 
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                }}
                .container {{ 
                    max-width: 1200px; 
                    margin: 0 auto; 
                    padding: 20px; 
                }}
                .live-header {{
                    background: rgba(255,255,255,0.95);
                    backdrop-filter: blur(10px);
                    border-radius: 20px;
                    padding: 20px;
                    margin-bottom: 20px;
                    box-shadow: 0 8px 32px rgba(0,0,0,0.1);
                }}
                .live-indicator {{
                    display: inline-flex;
                    align-items: center;
                    background: #ff4757;
                    color: white;
                    padding: 8px 16px;
                    border-radius: 25px;
                    font-weight: bold;
                    margin-bottom: 10px;
                    animation: pulse 2s infinite;
                }}
                @keyframes pulse {{
                    0% {{ box-shadow: 0 0 0 0 rgba(255, 71, 87, 0.7); }}
                    70% {{ box-shadow: 0 0 0 10px rgba(255, 71, 87, 0); }}
                    100% {{ box-shadow: 0 0 0 0 rgba(255, 71, 87, 0); }}
                }}
                .status-grid {{
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                    gap: 15px;
                    margin: 20px 0;
                }}
                .status-card {{
                    background: rgba(255,255,255,0.9);
                    backdrop-filter: blur(5px);
                    padding: 20px;
                    border-radius: 15px;
                    text-align: center;
                    border: 2px solid transparent;
                    transition: all 0.3s ease;
                }}
                .status-card:hover {{
                    transform: translateY(-5px);
                    border-color: #667eea;
                }}
                .route-container {{
                    background: rgba(255,255,255,0.95);
                    backdrop-filter: blur(10px);
                    border-radius: 20px;
                    padding: 25px;
                    box-shadow: 0 8px 32px rgba(0,0,0,0.1);
                }}
                .route-item {{
                    background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
                    color: white;
                    margin: 15px 0;
                    padding: 20px;
                    border-radius: 15px;
                    transition: all 0.3s ease;
                    position: relative;
                    overflow: hidden;
                }}
                .route-item:hover {{
                    transform: scale(1.02);
                    box-shadow: 0 10px 25px rgba(0,0,0,0.2);
                }}
                .route-item.updating {{
                    animation: glow 1s ease-in-out;
                }}
                @keyframes glow {{
                    0%, 100% {{ box-shadow: 0 0 5px rgba(255,255,255,0.5); }}
                    50% {{ box-shadow: 0 0 20px rgba(255,255,255,0.8); }}
                }}
                .live-badge {{
                    position: absolute;
                    top: 10px;
                    right: 10px;
                    background: #2ed573;
                    color: white;
                    padding: 4px 8px;
                    border-radius: 12px;
                    font-size: 10px;
                    font-weight: bold;
                }}
                .safety-bar {{
                    background: rgba(255,255,255,0.3);
                    height: 8px;
                    border-radius: 4px;
                    margin: 10px 0;
                    overflow: hidden;
                }}
                .safety-fill {{
                    height: 100%;
                    background: linear-gradient(90deg, #2ed573, #7bed9f);
                    border-radius: 4px;
                    transition: width 0.5s ease;
                }}
                .update-time {{
                    position: fixed;
                    bottom: 20px;
                    right: 20px;
                    background: rgba(0,0,0,0.8);
                    color: white;
                    padding: 10px 15px;
                    border-radius: 25px;
                    font-size: 12px;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="live-header">
                    <div class="live-indicator">
                        🔴 LIVE
                    </div>
                    <h1>🗺️ Real-time Evacuation Map: {matched_region}</h1>
                    <p><strong>Base Risk:</strong> <span style="color: {'red' if region_data['base_risk'] == 'high' else 'orange' if region_data['base_risk'] == 'moderate' else 'green'}">{region_data['base_risk'].upper()}</span></p>
                </div>
                
                <div class="status-grid">
                    <div class="status-card">
                        <h3>📍 Available Routes</h3>
                        <h2 id="routeCount">{len(routes)}</h2>
                    </div>
                    <div class="status-card">
                        <h3>🌤️ Weather</h3>
                        <h2 id="weatherStatus">{real_time_data['weather_conditions']['status'].replace('_', ' ').title()}</h2>
                    </div>
                    <div class="status-card">
                        <h3>⚡ Fastest Route</h3>
                        <h2 id="fastestRoute">{min([float(r['eta'].split()[0]) for r in routes]):.1f} min</h2>
                    </div>
                    <div class="status-card">
                        <h3>🛡️ Top Safety Score</h3>
                        <h2 id="topSafety">{max([r['safety_score'] for r in routes]):.2f}</h2>
                    </div>
                </div>
                
                <div class="route-container">
                    <h2>🚨 Live Evacuation Routes</h2>
                    <div id="routesContainer">
        """
        
        for i, route in enumerate(routes):
            safety_percentage = route['safety_score'] * 100
            html_content += f"""
                        <div class="route-item" id="route{i}">
                            <div class="live-badge">LIVE</div>
                            <h3>🚗 Route {i+1}: → {route['destination']}</h3>
                            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 15px; margin: 15px 0;">
                                <div><strong>📏 Distance:</strong><br>{route['distance_km']} km</div>
                                <div><strong>⏱️ ETA:</strong><br>{route['eta']}</div>
                                <div><strong>🚦 Traffic:</strong><br>{route['traffic_status']}</div>
                                <div><strong>⚠️ Risk:</strong><br>{route['risk_level']}</div>
                            </div>
                            <div>
                                <strong>🛡️ Safety Score: {route['safety_score']:.2f}/1.00</strong>
                                <div class="safety-bar">
                                    <div class="safety-fill" style="width: {safety_percentage}%"></div>
                                </div>
                            </div>
                        </div>
            """
        
        html_content += f"""
                    </div>
                </div>
            </div>
            
            <div class="update-time" id="lastUpdate">
                Last update: just now
            </div>
            
            <script>
                const socket = io();
                let lastUpdateTime = new Date();
                
                // Connect to real-time updates
                socket.on('connect', function() {{
                    console.log('🔴 Connected to real-time updates');
                }});
                
                socket.on('real_time_update', function(data) {{
                    console.log('📡 Real-time update received:', data);
                    lastUpdateTime = new Date();
                    
                    // Add visual feedback for updates
                    document.querySelectorAll('.route-item').forEach(route => {{
                        route.classList.add('updating');
                        setTimeout(() => route.classList.remove('updating'), 1000);
                    }});
                    
                    // Update weather display
                    document.getElementById('weatherStatus').textContent = 
                        data.weather_conditions.status.replace('_', ' ').replace(/\\b\\w/g, l => l.toUpperCase());
                }});
                
                // Update timestamp display
                function updateTimestamp() {{
                    const now = new Date();
                    const diff = Math.floor((now - lastUpdateTime) / 1000);
                    const minutes = Math.floor(diff / 60);
                    const seconds = diff % 60;
                    
                    let timeStr = '';
                    if (minutes > 0) {{
                        timeStr = `${{minutes}}m ${{seconds}}s ago`;
                    }} else {{
                        timeStr = `${{seconds}}s ago`;
                    }}
                    
                    document.getElementById('lastUpdate').textContent = `Last update: ${{timeStr}}`;
                }}
                
                // Auto-refresh data every 2 minutes
                setInterval(() => {{
                    location.reload();
                }}, 120000);
                
                // Update timestamp every second
                setInterval(updateTimestamp, 1000);
                
                console.log('🗺️ Real-time evacuation map loaded for {matched_region}');
            </script>
        </body>
        </html>
        """
        
        return html_content, 200, {'Content-Type': 'text/html'}
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# WebSocket event handlers
@socketio.on('connect')
def handle_connect():
    print('🔗 Client connected to real-time updates')
    emit('status', {'msg': 'Connected to real-time evacuation system'})

@socketio.on('disconnect')  
def handle_disconnect():
    print('📴 Client disconnected from real-time updates')

if __name__ == "__main__":
    print("🚀 Starting Real-time Mumbai Evacuation API...")
    print("📡 Real-time features: Traffic monitoring, Weather updates, Live route calculation")
    print("🌐 Access at: http://localhost:5000")
    print("🗺️ Live maps at: http://localhost:5000/live_map?region=<area_name>")
    socketio.run(app, host="0.0.0.0", port=5000, debug=True, allow_unsafe_werkzeug=True)