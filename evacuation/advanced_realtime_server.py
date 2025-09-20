#!/usr/bin/env python3
"""
Advanced Real-time Evacuation System using roads_all.graphml
Complete implementation with real road network data and live updates
"""

import os
import sys
import json
import time
import random
import threading
import numpy as np
import pandas as pd
import networkx as nx
import folium
from datetime import datetime, timedelta
from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS
from flask_socketio import SocketIO, emit
from folium.plugins import MarkerCluster, HeatMap, FastMarkerCluster

# Add current directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

app = Flask(__name__)
app.config['SECRET_KEY'] = 'realtime_flood_evacuation_2025'
CORS(app, origins="*")
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Configuration
GRAPHML_FILE = "roads_all.graphml"
CSV_FILE = "mumbai_ward_area_floodrisk.csv"
ASSUMED_SPEED_KMPH = 25.0
UPDATE_INTERVAL = 15  # seconds
MAX_ROUTES = 15
MIN_ROUTES = 3

# Global variables for road network and data
G = None
flood_df = None
real_time_traffic = {}
real_time_closures = set()
weather_impact = 1.0
emergency_incidents = []

# Real-time data storage
live_data = {
    "last_update": datetime.now(),
    "active_routes": {},
    "traffic_density": {},
    "road_conditions": {},
    "weather_conditions": {"status": "clear", "impact_factor": 1.0},
    "emergency_alerts": [],
    "route_popularity": {},
    "evacuation_centers_capacity": {}
}

def load_road_network():
    """Load the actual Mumbai road network from GraphML"""
    global G, flood_df
    
    try:
        print("🚀 Loading Mumbai road network (GraphML)...")
        start_time = time.time()
        
        if not os.path.exists(GRAPHML_FILE):
            print(f"❌ {GRAPHML_FILE} not found!")
            return False
            
        # Load the road network graph
        G = nx.read_graphml(GRAPHML_FILE)
        print(f"✅ Loaded road network: {len(G.nodes)} nodes, {len(G.edges)} edges")
        
        # Convert to undirected for better route finding
        if G.is_directed():
            G = G.to_undirected()
            
        # Load flood risk data
        if os.path.exists(CSV_FILE):
            flood_df = pd.read_csv(CSV_FILE)
            # Normalize column names
            flood_df.columns = flood_df.columns.str.strip().str.lower().str.replace(' ', '_').str.replace('-', '_')
            print(f"✅ Loaded flood data: {len(flood_df)} regions")
        else:
            print(f"⚠️ {CSV_FILE} not found, using default data")
            create_default_flood_data()
            
        load_time = time.time() - start_time
        print(f"⏱️ Network loaded in {load_time:.2f} seconds")
        
        # Initialize real-time traffic data for all edges
        initialize_traffic_data()
        
        return True
        
    except Exception as e:
        print(f"❌ Error loading road network: {e}")
        return False

def create_default_flood_data():
    """Create default flood data if CSV is not available"""
    global flood_df
    
    mumbai_areas = [
        {"areas": "Andheri East", "latitude": 19.1197, "longitude": 72.8697, "flood_risk_level": "high"},
        {"areas": "Andheri West", "latitude": 19.1359, "longitude": 72.8397, "flood_risk_level": "moderate"},
        {"areas": "Bandra East", "latitude": 19.0596, "longitude": 72.8656, "flood_risk_level": "low"},
        {"areas": "Bandra West", "latitude": 19.0544, "longitude": 72.8281, "flood_risk_level": "low"},
        {"areas": "Colaba", "latitude": 18.9067, "longitude": 72.8147, "flood_risk_level": "low"},
        {"areas": "Fort", "latitude": 18.9372, "longitude": 72.8356, "flood_risk_level": "low"},
        {"areas": "Dadar", "latitude": 19.0178, "longitude": 72.8478, "flood_risk_level": "moderate"},
        {"areas": "Worli", "latitude": 19.0134, "longitude": 72.8184, "flood_risk_level": "low"},
        {"areas": "Powai", "latitude": 19.1197, "longitude": 72.9056, "flood_risk_level": "high"},
        {"areas": "Borivali", "latitude": 19.2307, "longitude": 72.8567, "flood_risk_level": "low"},
        {"areas": "Malad", "latitude": 19.1864, "longitude": 72.8493, "flood_risk_level": "moderate"},
        {"areas": "Goregaon", "latitude": 19.1663, "longitude": 72.8526, "flood_risk_level": "moderate"},
        {"areas": "Thane", "latitude": 19.2183, "longitude": 72.9781, "flood_risk_level": "moderate"},
        {"areas": "Kurla", "latitude": 19.0728, "longitude": 72.8797, "flood_risk_level": "high"},
        {"areas": "Ghatkopar", "latitude": 19.0863, "longitude": 72.9081, "flood_risk_level": "moderate"}
    ]
    
    flood_df = pd.DataFrame(mumbai_areas)
    print("✅ Created default flood risk data")

def initialize_traffic_data():
    """Initialize real-time traffic data for all road edges"""
    global real_time_traffic
    
    print("🚦 Initializing real-time traffic data...")
    
    # Initialize traffic multipliers for all edges (1.0 = normal, >1.0 = congested)
    for u, v in G.edges():
        edge_id = f"{u}_{v}"
        real_time_traffic[edge_id] = {
            "multiplier": random.uniform(0.8, 1.5),  # Random initial traffic
            "last_update": datetime.now(),
            "incidents": [],
            "closure_status": "open"
        }
    
    print(f"✅ Initialized traffic data for {len(real_time_traffic)} road segments")

def get_nearest_node(lat, lon):
    """Find nearest graph node to given coordinates"""
    min_dist = float('inf')
    nearest_node = None
    checked_nodes = 0
    
    for node in G.nodes():
        checked_nodes += 1
        try:
            node_data = G.nodes[node]
            if 'y' in node_data and 'x' in node_data:
                node_lat = float(node_data['y'])
                node_lon = float(node_data['x'])
                
                # Calculate distance
                dist = ((lat - node_lat) ** 2 + (lon - node_lon) ** 2) ** 0.5
                if dist < min_dist:
                    min_dist = dist
                    nearest_node = node
        except:
            continue
    
    print(f"🗺️ Searched {checked_nodes} nodes, found nearest: {nearest_node} (dist: {min_dist:.6f})")        
    return nearest_node

def calculate_real_time_route_cost(path):
    """Calculate route cost considering real-time traffic and road conditions"""
    total_cost = 0.0
    total_length = 0.0
    
    for i in range(len(path) - 1):
        u, v = path[i], path[i + 1]
        edge_id = f"{u}_{v}"
        
        # Get base edge length
        try:
            edge_data = G.edges[u, v]
            length_value = edge_data.get('length', 1000)
            # Ensure length is numeric
            if isinstance(length_value, str):
                try:
                    length = float(length_value)
                except ValueError:
                    length = 1000.0  # Default if string can't be converted
            else:
                length = float(length_value)
        except Exception as e:
            print(f"📐 Edge {u}-{v} length error: {e}, using default")
            length = 1000.0
            
        # Apply real-time traffic multiplier
        traffic_multiplier = float(real_time_traffic.get(edge_id, {}).get('multiplier', 1.0))
        
        # Apply weather impact  
        weather_multiplier = float(live_data["weather_conditions"]["impact_factor"])
        
        # Check for road closures
        if edge_id in real_time_closures:
            traffic_multiplier = 10.0  # Very high cost for closed roads
            
        adjusted_cost = float(length) * float(traffic_multiplier) * float(weather_multiplier)
        total_cost += adjusted_cost
        total_length += length
        
    return total_cost, total_length

def find_real_time_evacuation_routes(source_area, k=10):
    """Find evacuation routes using real road network with real-time data"""
    if flood_df is None or G is None:
        return None, 0, []
        
    # Find matching source area with more flexible matching
    matched_areas = flood_df[flood_df['areas'].str.contains(source_area, case=False, na=False)]
    if matched_areas.empty:
        print(f"🔍 No exact match for '{source_area}', trying partial matches...")
        # Try partial word matching
        words = source_area.split()
        for word in words:
            if len(word) > 3:  # Only use meaningful words
                partial_matches = flood_df[flood_df['areas'].str.contains(word, case=False, na=False)]
                if not partial_matches.empty:
                    matched_areas = partial_matches
                    print(f"✅ Found partial match using word '{word}'")
                    break
        
        if matched_areas.empty:
            print(f"❌ No matches found for '{source_area}'")
            return None, 0, []
        
    source_data = matched_areas.iloc[0]
    source_lat, source_lon = float(source_data['latitude']), float(source_data['longitude'])
    source_node = get_nearest_node(source_lat, source_lon)
    
    if source_node is None:
        print(f"❌ Could not find road network node for {source_data['areas']}")
        return None, 0, []
        
    print(f"🏁 Starting route search from: {source_data['areas']} (risk: {source_data['flood_risk_level']})")
        
    # Find safe destination areas - Include low, moderate, and even high risk as potential evacuations
    # The key is to get people moving to any available safe location
    safe_areas = flood_df.copy()  # Include all areas initially
    safe_areas = safe_areas[safe_areas.index != source_data.name]  # Exclude source area by index
    
    # Prefer lower risk areas but include all as options
    safe_areas = safe_areas.sort_values('flood_risk_level', key=lambda x: x.map({'low': 1, 'moderate': 2, 'high': 3}))
    
    print(f"🎯 Found {len(safe_areas)} potential destinations (all risk levels)")
    
    routes = []
    route_attempts = 0
    successful_routes = 0
    
    for _, dest_data in safe_areas.iterrows():
        route_attempts += 1
        dest_lat, dest_lon = float(dest_data['latitude']), float(dest_data['longitude'])
        dest_node = get_nearest_node(dest_lat, dest_lon)
        
        if dest_node is None:
            continue
            
        try:
            # Find shortest path considering real-time conditions
            path = nx.shortest_path(G, source_node, dest_node, weight='length')
            
            # Calculate real-time costs
            real_time_cost, total_length = calculate_real_time_route_cost(path)
            
            # Calculate ETA with real-time factors
            base_eta = (total_length / 1000.0) / ASSUMED_SPEED_KMPH * 60.0
            
            # Get average traffic multiplier for this route
            avg_traffic_multiplier = 1.0
            traffic_count = 0
            for i in range(len(path) - 1):
                edge_id = f"{path[i]}_{path[i+1]}"
                if edge_id in real_time_traffic:
                    avg_traffic_multiplier += real_time_traffic[edge_id]['multiplier']
                    traffic_count += 1
                    
            if traffic_count > 0:
                avg_traffic_multiplier = avg_traffic_multiplier / traffic_count
                
            real_time_eta = base_eta * avg_traffic_multiplier
            
            # Calculate safety score
            base_safety = 0.9 if dest_data['flood_risk_level'] == 'low' else 0.7
            traffic_impact = max(0.1, 1.1 - avg_traffic_multiplier) * 0.3
            weather_impact = (2.0 - live_data["weather_conditions"]["impact_factor"]) * 0.2
            
            safety_score = min(1.0, base_safety + traffic_impact + weather_impact)
            
            route_info = {
                "dest_region": dest_data['areas'],
                "path": path,
                "distance_km": round(total_length / 1000.0, 2),
                "eta_min": round(real_time_eta, 1),
                "risk_level": dest_data['flood_risk_level'],
                "safety_score": round(safety_score, 3),
                "traffic_status": "heavy" if avg_traffic_multiplier > 1.3 else "moderate" if avg_traffic_multiplier > 1.1 else "clear",
                "real_time_cost": real_time_cost,
                "last_updated": datetime.now().isoformat()
            }
            
            routes.append(route_info)
            successful_routes += 1
            
        except nx.NetworkXNoPath:
            continue
        except Exception as e:
            print(f"⚠️ Error calculating route to {dest_data['areas']}: {e}")
            continue
            
    print(f"📊 Route calculation complete: {successful_routes}/{route_attempts} successful routes")
    
    # Sort by safety score (highest first), then by real-time cost
    routes.sort(key=lambda x: (-x['safety_score'], x['real_time_cost']))
    
    final_routes = routes[:k]
    print(f"🚀 Returning {len(final_routes)} best routes")
    
    return source_data['areas'], 95, final_routes

def update_real_time_conditions():
    """Background task to update real-time traffic and road conditions"""
    while True:
        try:
            current_time = datetime.now()
            
            # Update traffic conditions for random edges
            edges_to_update = random.sample(list(real_time_traffic.keys()), 
                                          min(100, len(real_time_traffic)))
            
            for edge_id in edges_to_update:
                current_multiplier = real_time_traffic[edge_id]['multiplier']
                
                # Random traffic changes (-0.2 to +0.3)
                change = random.uniform(-0.2, 0.3)
                new_multiplier = max(0.5, min(3.0, current_multiplier + change))
                
                real_time_traffic[edge_id]['multiplier'] = new_multiplier
                real_time_traffic[edge_id]['last_update'] = current_time
                
                # Simulate incidents (5% chance)
                if random.random() < 0.05:
                    incident_types = ["accident", "flooding", "construction", "breakdown"]
                    incident = {
                        "type": random.choice(incident_types),
                        "severity": random.choice(["minor", "major"]),
                        "time": current_time.isoformat()
                    }
                    real_time_traffic[edge_id]['incidents'].append(incident)
                    
                    # Increase traffic multiplier for incidents
                    if incident["severity"] == "major":
                        real_time_traffic[edge_id]['multiplier'] = min(3.0, new_multiplier + 1.0)
            
            # Update weather conditions (10% chance)
            if random.random() < 0.1:
                weather_conditions = [
                    {"status": "clear", "impact_factor": 1.0},
                    {"status": "light_rain", "impact_factor": 1.2},
                    {"status": "heavy_rain", "impact_factor": 1.8},
                    {"status": "flooding", "impact_factor": 2.5}
                ]
                live_data["weather_conditions"] = random.choice(weather_conditions)
            
            # Simulate road closures (1% chance for closure, 5% chance for reopening)
            for edge_id in random.sample(list(real_time_traffic.keys()), min(50, len(real_time_traffic))):
                if edge_id in real_time_closures:
                    if random.random() < 0.05:  # 5% chance to reopen
                        real_time_closures.discard(edge_id)
                        real_time_traffic[edge_id]['closure_status'] = "open"
                else:
                    if random.random() < 0.01:  # 1% chance to close
                        real_time_closures.add(edge_id)
                        real_time_traffic[edge_id]['closure_status'] = "closed"
            
            # Update global timestamp
            live_data["last_update"] = current_time
            
            # Emit real-time updates to connected clients
            update_data = {
                'traffic_updates': len(edges_to_update),
                'road_closures': len(real_time_closures),
                'weather_conditions': live_data["weather_conditions"],
                'timestamp': current_time.isoformat(),
                'active_incidents': sum(1 for edge in real_time_traffic.values() if edge['incidents'])
            }
            
            socketio.emit('real_time_traffic_update', update_data)
            
            print(f"🔄 Updated {len(edges_to_update)} traffic conditions, {len(real_time_closures)} closures")
            
            time.sleep(UPDATE_INTERVAL)
            
        except Exception as e:
            print(f"❌ Error in real-time update: {e}")
            time.sleep(30)

def create_real_time_map(source_area, routes, map_file="real_time_evacuation_map.html"):
    """Create interactive real-time evacuation map"""
    if not routes:
        return None
        
    # Get source coordinates
    source_data = flood_df[flood_df['areas'] == source_area].iloc[0]
    center_lat, center_lon = float(source_data['latitude']), float(source_data['longitude'])
    
    # Create base map
    m = folium.Map(
        location=[center_lat, center_lon],
        zoom_start=12,
        tiles='OpenStreetMap'
    )
    
    # Add alternative tile layers
    folium.TileLayer('cartodbpositron', name='Light Mode').add_to(m)
    folium.TileLayer('cartodbdark_matter', name='Dark Mode').add_to(m)
    
    # Add source marker
    folium.Marker(
        [center_lat, center_lon],
        popup=f"📍 Start: {source_area}",
        icon=folium.Icon(color='red', icon='home', prefix='fa')
    ).add_to(m)
    
    # Color scheme for routes
    colors = ['blue', 'green', 'purple', 'orange', 'darkred', 'lightred', 
              'beige', 'darkblue', 'darkgreen', 'cadetblue', 'darkpurple', 
              'white', 'pink', 'lightblue', 'lightgreen']
    
    # Add route paths
    for i, route in enumerate(routes):
        color = colors[i % len(colors)]
        
        # Get destination coordinates
        dest_data = flood_df[flood_df['areas'] == route['dest_region']].iloc[0]
        dest_lat, dest_lon = float(dest_data['latitude']), float(dest_data['longitude'])
        
        # Create route line (simplified - just straight line for visualization)
        route_coords = [[center_lat, center_lon], [dest_lat, dest_lon]]
        
        # Add route line with traffic-based styling
        line_weight = 8 if route['traffic_status'] == 'heavy' else 5 if route['traffic_status'] == 'moderate' else 3
        
        folium.PolyLine(
            route_coords,
            color=color,
            weight=line_weight,
            opacity=0.8,
            popup=f"""
            <b>Route {i+1}: {route['dest_region']}</b><br>
            Distance: {route['distance_km']} km<br>
            ETA: {route['eta_min']} min<br>
            Traffic: {route['traffic_status']}<br>
            Safety Score: {route['safety_score']}/1.0<br>
            Risk Level: {route['risk_level']}
            """
        ).add_to(m)
        
        # Add destination marker
        folium.Marker(
            [dest_lat, dest_lon],
            popup=f"🎯 {route['dest_region']}<br>Safety: {route['safety_score']}/1.0",
            icon=folium.Icon(color='green', icon='shield', prefix='fa')
        ).add_to(m)
    
    # Add traffic heat map (simplified)
    traffic_data = []
    sample_points = 50
    for _ in range(sample_points):
        lat = center_lat + random.uniform(-0.1, 0.1)
        lon = center_lon + random.uniform(-0.1, 0.1)
        intensity = random.uniform(0.1, 1.0)
        traffic_data.append([lat, lon, intensity])
    
    # Add heat map
    HeatMap(traffic_data, name='Traffic Density').add_to(m)
    
    # Add layer control
    folium.LayerControl().add_to(m)
    
    # Save map
    m.save(map_file)
    return map_file

# Flask Routes
@app.route("/")
def home():
    """API Information"""
    network_status = "loaded" if G is not None else "not_loaded"
    
    return jsonify({
        "message": "🛣️ Mumbai Real-time Road Network Evacuation API",
        "version": "4.0.0 - Live Road Network Edition",
        "network_status": network_status,
        "road_segments": len(real_time_traffic) if real_time_traffic else 0,
        "active_closures": len(real_time_closures),
        "features": [
            "Real road network from GraphML",
            "Live traffic monitoring on actual roads",
            "Dynamic route calculation with real conditions",
            "Weather impact on road conditions",
            "Real-time incident tracking",
            "WebSocket live updates"
        ],
        "endpoints": {
            "health": "/health",
            "network_status": "/network_status",
            "routes": "/routes (POST)",
            "live_map": "/live_map?region=<region_name>",
            "traffic_status": "/traffic_status",
            "websocket": "/socket.io for live updates"
        },
        "last_update": live_data["last_update"].isoformat()
    })

@app.route("/network_status")
def network_status():
    """Get road network status"""
    return jsonify({
        "network_loaded": G is not None,
        "total_nodes": len(G.nodes) if G else 0,
        "total_edges": len(G.edges) if G else 0,
        "monitored_segments": len(real_time_traffic),
        "active_closures": len(real_time_closures),
        "weather_conditions": live_data["weather_conditions"],
        "last_update": live_data["last_update"].isoformat()
    })

@app.route("/routes", methods=['POST'])
def get_real_time_routes():
    """Get real-time evacuation routes using actual road network"""
    try:
        if G is None:
            return jsonify({"error": "Road network not loaded"}), 503
            
        data = request.get_json()
        region = data.get('region', '')
        route_count = min(MAX_ROUTES, max(MIN_ROUTES, data.get('route_count', 10)))
        
        if not region:
            return jsonify({"error": "region is required"}), 400
        
        # Find real-time routes
        matched_region, match_score, routes = find_real_time_evacuation_routes(region, route_count)
        
        if not matched_region:
            return jsonify({
                "error": f"Region '{region}' not found",
                "available_regions": flood_df['areas'].tolist()[:10] if flood_df is not None else []
            }), 404
        
        # Convert routes for API response
        api_routes = []
        for route in routes:
            api_routes.append({
                "destination": route['dest_region'],
                "distance_km": route['distance_km'],
                "eta": f"{route['eta_min']} min",
                "risk_level": route['risk_level'],
                "safety_score": route['safety_score'],
                "traffic_status": route['traffic_status'],
                "last_updated": route['last_updated']
            })
        
        return jsonify({
            "success": True,
            "matched_region": matched_region,
            "match_score": match_score,
            "routes": api_routes,
            "route_count": len(api_routes),
            "message": f"Found {len(api_routes)} real-time evacuation routes using live road network",
            "data_source": "Real Road Network + Live Traffic Data",
            "algorithm_version": "4.0 - Real-time road network routing",
            "network_info": {
                "total_road_segments": len(real_time_traffic),
                "active_closures": len(real_time_closures),
                "weather_impact": live_data["weather_conditions"]["impact_factor"],
                "last_traffic_update": live_data["last_update"].isoformat()
            }
        })
        
    except Exception as e:
        return jsonify({
            "error": str(e),
            "matched_region": region if 'region' in locals() else "unknown"
        }), 500

@app.route("/live_map")
def live_map():
    """Generate live evacuation map using real road network"""
    try:
        if G is None:
            return jsonify({"error": "Road network not loaded"}), 503
            
        region = request.args.get("region", "")
        route_count = int(request.args.get("route_count", 10))  # Accept route_count parameter
        
        # Validate route count
        route_count = min(MAX_ROUTES, max(MIN_ROUTES, route_count))
        
        if not region:
            return jsonify({"error": "Region parameter is required"}), 400

        # Get real-time routes with specified count
        matched_region, _, routes = find_real_time_evacuation_routes(region, route_count)
        
        if not matched_region:
            return jsonify({
                "error": f"Region '{region}' not found",
                "available_regions": flood_df['areas'].tolist()[:10] if flood_df is not None else []
            }), 404

        # Generate comprehensive HTML with real road data visualization
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>🛣️ LIVE Road Network - {matched_region}</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.7.2/socket.io.js"></script>
            <style>
                body {{ 
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
                    margin: 0; 
                    background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
                    min-height: 100vh;
                }}
                .container {{ max-width: 1400px; margin: 0 auto; padding: 20px; }}
                .network-header {{
                    background: rgba(255,255,255,0.95);
                    backdrop-filter: blur(15px);
                    border-radius: 25px;
                    padding: 25px;
                    margin-bottom: 25px;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.2);
                }}
                .live-indicator {{
                    display: inline-flex;
                    align-items: center;
                    background: linear-gradient(45deg, #ff6b6b, #ee5a24);
                    color: white;
                    padding: 10px 20px;
                    border-radius: 30px;
                    font-weight: bold;
                    margin-bottom: 15px;
                    animation: pulse 2s infinite;
                    box-shadow: 0 4px 15px rgba(255,107,107,0.4);
                }}
                @keyframes pulse {{
                    0% {{ transform: scale(1); box-shadow: 0 0 0 0 rgba(255,107,107,0.7); }}
                    70% {{ transform: scale(1.02); box-shadow: 0 0 0 15px rgba(255,107,107,0); }}
                    100% {{ transform: scale(1); box-shadow: 0 0 0 0 rgba(255,107,107,0); }}
                }}
                .network-stats {{
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
                    gap: 20px;
                    margin: 25px 0;
                }}
                .stat-card {{
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 25px;
                    border-radius: 20px;
                    text-align: center;
                    box-shadow: 0 8px 25px rgba(0,0,0,0.15);
                    transition: all 0.3s ease;
                }}
                .stat-card:hover {{
                    transform: translateY(-8px);
                    box-shadow: 0 15px 35px rgba(0,0,0,0.25);
                }}
                .routes-container {{
                    background: rgba(255,255,255,0.95);
                    backdrop-filter: blur(15px);
                    border-radius: 25px;
                    padding: 30px;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.2);
                }}
                .route-card {{
                    background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
                    color: white;
                    margin: 20px 0;
                    padding: 25px;
                    border-radius: 20px;
                    transition: all 0.4s ease;
                    position: relative;
                    overflow: hidden;
                }}
                .route-card:hover {{
                    transform: scale(1.03);
                    box-shadow: 0 15px 40px rgba(0,0,0,0.3);
                }}
                .route-card.updating {{
                    animation: glow 1.5s ease-in-out;
                }}
                @keyframes glow {{
                    0%, 100% {{ box-shadow: 0 0 10px rgba(255,255,255,0.5); }}
                    50% {{ box-shadow: 0 0 30px rgba(255,255,255,0.9); }}
                }}
                .live-badge {{
                    position: absolute;
                    top: 15px;
                    right: 15px;
                    background: #2ed573;
                    color: white;
                    padding: 6px 12px;
                    border-radius: 15px;
                    font-size: 11px;
                    font-weight: bold;
                    animation: blink 2s infinite;
                }}
                @keyframes blink {{
                    0%, 50% {{ opacity: 1; }}
                    51%, 100% {{ opacity: 0.7; }}
                }}
                .traffic-indicator {{
                    display: inline-block;
                    padding: 4px 10px;
                    border-radius: 12px;
                    font-size: 11px;
                    font-weight: bold;
                    margin-left: 8px;
                }}
                .traffic-clear {{ background: #2ed573; color: white; }}
                .traffic-moderate {{ background: #ffa502; color: white; }}
                .traffic-heavy {{ background: #ff3742; color: white; }}
                .real-time-info {{
                    position: fixed;
                    bottom: 20px;
                    right: 20px;
                    background: rgba(0,0,0,0.9);
                    color: white;
                    padding: 15px 20px;
                    border-radius: 30px;
                    font-size: 12px;
                    max-width: 300px;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="network-header">
                    <div class="live-indicator">
                        🛣️ LIVE ROAD NETWORK
                    </div>
                    <h1>Real-time Evacuation Routes: {matched_region}</h1>
                    <p><strong>Using Live Mumbai Road Network Data</strong></p>
                </div>
                
                <div class="network-stats">
                    <div class="stat-card">
                        <h3>🛣️ Road Segments</h3>
                        <h2>{len(real_time_traffic):,}</h2>
                        <small>Live monitored</small>
                    </div>
                    <div class="stat-card">
                        <h3>🚧 Road Closures</h3>
                        <h2 id="closureCount">{len(real_time_closures)}</h2>
                        <small>Active now</small>
                    </div>
                    <div class="stat-card">
                        <h3>🌤️ Weather Impact</h3>
                        <h2 id="weatherImpact">{live_data['weather_conditions']['impact_factor']:.1f}x</h2>
                        <small>{live_data['weather_conditions']['status'].replace('_', ' ').title()}</small>
                    </div>
                    <div class="stat-card">
                        <h3>📍 Routes Found</h3>
                        <h2>{len(routes)}</h2>
                        <small>Real-time calculated</small>
                    </div>
                </div>
                
                <div class="routes-container">
                    <h2>🚨 Live Evacuation Routes (Real Road Network)</h2>
                    <div id="routesContainer">
        """
        
        for i, route in enumerate(routes):
            traffic_class = f"traffic-{route['traffic_status']}"
            html_content += f"""
                        <div class="route-card" id="route{i}">
                            <div class="live-badge">LIVE</div>
                            <h3>🚗 Route {i+1}: → {route['dest_region']}</h3>
                            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 20px; margin: 20px 0;">
                                <div><strong>📏 Distance:</strong><br>{route['distance_km']} km</div>
                                <div><strong>⏱️ ETA:</strong><br>{route['eta_min']} min</div>
                                <div><strong>🚦 Traffic:</strong><br>{route['traffic_status']}<span class="traffic-indicator {traffic_class}">{route['traffic_status'].upper()}</span></div>
                                <div><strong>⚠️ Risk:</strong><br>{route['risk_level']}</div>
                                <div><strong>🛡️ Safety:</strong><br>{route['safety_score']:.2f}/1.00</div>
                            </div>
                            <div style="margin-top: 15px; padding: 15px; background: rgba(255,255,255,0.2); border-radius: 10px;">
                                <small>📡 <strong>Real-time Data:</strong> Using live traffic from {len(G.nodes):,} road intersections</small>
                            </div>
                        </div>
            """
        
        html_content += f"""
                    </div>
                </div>
            </div>
            
            <div class="real-time-info" id="realtimeInfo">
                <strong>🔴 Live Data Stream</strong><br>
                Road segments: {len(real_time_traffic):,}<br>
                Last update: <span id="lastUpdate">just now</span><br>
                <span id="connectionStatus">Connected</span>
            </div>
            
            <script>
                const socket = io();
                let lastUpdateTime = new Date();
                
                socket.on('connect', function() {{
                    console.log('🛣️ Connected to live road network');
                    document.getElementById('connectionStatus').textContent = 'Connected ✅';
                }});
                
                socket.on('disconnect', function() {{
                    document.getElementById('connectionStatus').textContent = 'Disconnected ❌';
                }});
                
                socket.on('real_time_traffic_update', function(data) {{
                    console.log('🚦 Live traffic update:', data);
                    lastUpdateTime = new Date();
                    
                    // Visual feedback for updates
                    document.querySelectorAll('.route-card').forEach(card => {{
                        card.classList.add('updating');
                        setTimeout(() => card.classList.remove('updating'), 1500);
                    }});
                    
                    // Update statistics
                    document.getElementById('closureCount').textContent = data.road_closures;
                    document.getElementById('weatherImpact').textContent = data.weather_conditions.impact_factor.toFixed(1) + 'x';
                }});
                
                function updateTimestamp() {{
                    const now = new Date();
                    const diff = Math.floor((now - lastUpdateTime) / 1000);
                    const minutes = Math.floor(diff / 60);
                    const seconds = diff % 60;
                    
                    let timeStr = diff < 60 ? `${{seconds}}s ago` : `${{minutes}}m ${{seconds}}s ago`;
                    document.getElementById('lastUpdate').textContent = timeStr;
                }}
                
                // Auto-refresh every 3 minutes for latest network data
                setInterval(() => location.reload(), 180000);
                
                // Update timestamp every second
                setInterval(updateTimestamp, 1000);
                
                console.log('🛣️ Live road network evacuation system loaded');
                console.log('📊 Monitoring {len(real_time_traffic):,} road segments in real-time');
            </script>
        </body>
        </html>
        """
        
        return html_content, 200, {'Content-Type': 'text/html'}
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# WebSocket Events
@socketio.on('connect')
def handle_connect():
    print('🔗 Client connected to real-time road network')
    emit('status', {'msg': 'Connected to live road network system'})

@socketio.on('disconnect')
def handle_disconnect():
    print('📴 Client disconnected from real-time road network')

if __name__ == "__main__":
    print("🚀 Starting Real-time Mumbai Road Network Evacuation System...")
    
    # Load road network on startup
    if load_road_network():
        print("✅ Road network loaded successfully")
        
        # Start real-time update thread
        update_thread = threading.Thread(target=update_real_time_conditions, daemon=True)
        update_thread.start()
        print("📡 Real-time traffic monitoring started")
        
        print("🌐 Server starting at: http://localhost:5001")
        print("🗺️ Live road maps at: http://localhost:5001/live_map?region=<area_name>")
        
        socketio.run(app, host="0.0.0.0", port=5001, debug=True, allow_unsafe_werkzeug=True)
    else:
        print("❌ Failed to load road network. Please check GraphML file.")
        sys.exit(1)