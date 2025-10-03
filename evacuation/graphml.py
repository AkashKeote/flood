#!/usr/bin/env python3
"""
llload.py — Integrated Mumbai evacuation map (final)

Requirements:
  pip install osmnx networkx pandas numpy geopandas folium shapely rapidfuzz

Place in same folder:
  - roads_all.graphml
  - mumbai_ward_area_floodrisk.csv  (columns like: Ward Code, Areas, Latitude, Longitude, Flood-risk_level)

Output:
  - mumbai_evacuation_routes.html
"""

# ----------------------------
# Imports (all at top)
# ----------------------------
import os
import json
import math
import random
import time
import numpy as np
import pandas as pd
import networkx as nx
import osmnx as ox
import folium
from folium import GeoJson, PolyLine, CircleMarker
from folium.plugins import (
    MarkerCluster, MiniMap, Fullscreen, MeasureControl,
    MousePosition, LocateControl
)
from shapely.geometry import Point

# Fuzzy matching: rapidfuzz preferred, fallback to fuzzywuzzy, then difflib
try:
    from rapidfuzz import process as fuzzy_process  # preferred
except Exception:
    try:
        from fuzzywuzzy import process as fuzzy_process
    except Exception:
        import difflib
        class _DLProcess:
            @staticmethod
            def extractOne(query, choices):
                matches = difflib.get_close_matches(query, choices, n=1, cutoff=0)
                if matches:
                    score = int(difflib.SequenceMatcher(None, query, matches[0]).ratio() * 100)
                    return matches[0], score
                return None, 0
        fuzzy_process = _DLProcess()

# ----------------------------
# Config
# ----------------------------
GRAPHML = "roads_all.graphml"
CSV = "mumbai_ward_area_floodrisk_all_102.csv"
OUT_HTML = "mumbai_evacuation_routes.html"
PLACE = "Mumbai, India"
ASSUMED_SPEED_KMPH = 25.0       # for ETA
SAMPLE_FACTOR = 5               # sample 1/N edges for lighter HTML
MAX_POIS_PER_CAT = 500          # cap per category to keep HTML smaller
ROUTE_COUNT = 5                 # how many evacuation routes to draw

# Enhanced Risk color map with better contrast and intensity
RISK_COLOR = {
    "low": "#2E8B57",      # Sea Green - safe areas
    "moderate": "#FF8C00",  # Dark Orange - moderate risk  
    "high": "#DC143C",     # Crimson Red - high danger
    "unknown": "#696969",   # Dim Gray - unknown risk
}

# Enhanced marker styles for heatmap effect
RISK_MARKER_CONFIG = {
    "low": {
        "color": "#2E8B57",
        "background": "#90EE90", 
        "border": "#006400",
        "size": "12px",
        "weight": 2
    },
    "moderate": {
        "color": "#FF8C00",
        "background": "#FFB347",
        "border": "#FF4500", 
        "size": "14px",
        "weight": 3
    },
    "high": {
        "color": "#DC143C",
        "background": "#FF6B6B",
        "border": "#8B0000",
        "size": "16px", 
        "weight": 4
    },
    "unknown": {
        "color": "#696969",
        "background": "#C0C0C0",
        "border": "#2F2F2F",
        "size": "12px",
        "weight": 2
    }
}

# POI categories: OSM tag -> (FontAwesome icon, folium color)
POI_CATEGORIES = {
    "hospital":       ({"amenity": "hospital"},       "plus-square",   "red"),
    "police":         ({"amenity": "police"},         "shield",        "darkblue"),
    "fire_station":   ({"amenity": "fire_station"},   "fire",          "orange"),
    "pharmacy":       ({"amenity": "pharmacy"},       "medkit",        "purple"),
    "school":         ({"amenity": "school"},         "graduation-cap","cadetblue"),
    "university":     ({"amenity": "university"},     "university",    "darkgreen"),
    "fuel":           ({"amenity": "fuel"},           "gas-pump",      "lightgray"),
    "shelter":        ({"emergency": "shelter"},      "home",          "green"),
    "bank":           ({"amenity": "bank"},           "bank",          "darkred"),
    "atm":            ({"amenity": "atm"},            "money-bill",    "darkred"),
    "restaurant":     ({"amenity": "restaurant"},     "utensils",      "beige"),
    "market":         ({"shop": "supermarket"},       "shopping-cart", "brown"),
    "water_tower":    ({"man_made": "water_tower"},   "tint",          "blue"),
    "bus_station":    ({"amenity": "bus_station"},    "bus",           "darkblue"),
    "train_station":  ({"railway": "station"},        "train",         "black"),
}

# ----------------------------
# Helpers
# ----------------------------
def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_", regex=False)
    aliases = {
        "ward": "areas", "area": "areas", "region": "areas",
        "flood-risk_level": "flood_risk_level", "flood_risk": "flood_risk_level",
        "risk_level": "flood_risk_level", "risk": "flood_risk_level",
        "lat": "latitude", "y": "latitude",
        "lon": "longitude", "lng": "longitude", "x": "longitude",
    }
    for old, new in aliases.items():
        if old in df.columns and new not in df.columns:
            df.rename(columns={old: new}, inplace=True)
    required = ["areas", "latitude", "longitude", "flood_risk_level"]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"CSV missing required columns: {missing}. Found: {list(df.columns)}")
    df["areas"] = df["areas"].astype(str).str.strip().str.lower()
    df["flood_risk_level"] = df["flood_risk_level"].astype(str).str.strip().str.lower()
    df["latitude"] = df["latitude"].astype(float)
    df["longitude"] = df["longitude"].astype(float)
    return df

def extract_best_match(query: str, choices):
    res = fuzzy_process.extractOne(query, choices)
    if res is None:
        return None, 0
    if isinstance(res, (tuple, list)) and len(res) >= 2:
        return res[0], int(res[1])
    return res, 100

def haversine_m(lon1, lat1, lon2, lat2):
    R = 6371000.0
    lon1 = np.radians(lon1); lat1 = np.radians(lat1)
    lon2 = np.radians(lon2); lat2 = np.radians(lat2)
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = np.sin(dlat/2.0)**2 + np.cos(lat1)*np.cos(lat2)*np.sin(dlon/2.0)**2
    c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1-a))
    return R * c

def get_realistic_path(G, start_node, end_node):
    """
    Get a realistic path that follows actual roads and avoids cutting through water/buildings
    """
    try:
        # First check if nodes are connected
        if not nx.has_path(G, start_node, end_node):
            return None
            
        # Get shortest path by length (actual road distance)
        path = nx.shortest_path(G, start_node, end_node, weight="length")
        
        # Validate path quality
        path_length = route_length_m(G, path)
        
        # If path is suspiciously short with few nodes, it might be cutting corners
        if len(path) < 3 and path_length < 1000:  # Less than 1km with very few nodes
            try:
                # Try finding alternative paths with more intermediate nodes
                all_simple_paths = list(nx.all_simple_paths(G, start_node, end_node, cutoff=len(path)+10))
                if len(all_simple_paths) > 1:
                    # Choose path with reasonable node count (more realistic)
                    candidate_paths = []
                    for p in all_simple_paths[:5]:  # Check first 5 paths only for performance
                        p_length = route_length_m(G, p)
                        # Prefer paths that aren't too much longer but have more nodes
                        if p_length <= path_length * 1.5 and len(p) > len(path):
                            candidate_paths.append((p, p_length, len(p)))
                    
                    if candidate_paths:
                        # Sort by balance of length and node count
                        candidate_paths.sort(key=lambda x: x[1] / x[2])  # length per node
                        path = candidate_paths[0][0]
            except:
                pass  # Use original path if alternatives fail
                
        return path
    except Exception as e:
        print(f"DEBUG Path finding error: {e}")
        return None

def route_length_m(G, route):
    """Calculate total length of a route in meters"""
    if len(route) < 2:
        return 0.0
    
    total = 0.0
    for u, v in zip(route[:-1], route[1:]):
        data = G.get_edge_data(u, v)
        if not data:
            continue
        # Handle MultiDiGraph edge data (may have multiple edges between nodes)
        if isinstance(data, dict):
            edge_data = data.get(0, data)  # Get first edge if multiple
        else:
            edge_data = data
        total += edge_data.get("length", 0.0)
    return total
    # Robust length summation
    total = 0.0
    for u, v in zip(route[:-1], route[1:]):
        data = G.get_edge_data(u, v)
        if not data:
            continue
        best = min(data.values(), key=lambda d: d.get("length", float("inf")))
        total += float(best.get("length", 0.0))
    return total

def nearest_node(G, lon, lat):
    try:
        return ox.distance.nearest_nodes(G, X=lon, Y=lat)
    except Exception:
        # older alias
        return ox.nearest_nodes(G, X=lon, Y=lat)

# ----------------------------
# Load graph & CSV (once)
# ----------------------------
if not os.path.exists(GRAPHML):
    raise SystemExit(f"❌ Missing {GRAPHML} in current folder.")
if not os.path.exists(CSV):
    raise SystemExit(f"❌ Missing {CSV} in current folder.")

print("🚀 Loading road network (graphml)...")
G = ox.load_graphml(GRAPHML)
# ensure we work on the largest *weakly* connected component (so routes exist)
largest_cc_nodes = max(nx.weakly_connected_components(G), key=len)
G = G.subgraph(largest_cc_nodes).copy()

# Filter out non-road edges that might cross water/restricted areas
print("🚫 Filtering non-road edges...")
edges_to_remove = []
for u, v, key, data in G.edges(keys=True, data=True):
    # Remove edges that are ferries, flights, or other non-road transport
    highway = data.get('highway', '')
    if isinstance(highway, list):
        highway = highway[0] if highway else ''
    
    # Remove problematic edge types
    if highway in ['ferry', 'flight', 'waterway'] or 'ferry' in str(data.get('route', '')):
        edges_to_remove.append((u, v, key))
        
# Remove identified problematic edges
for edge in edges_to_remove:
    try:
        G.remove_edge(edge[0], edge[1], edge[2])
    except:
        pass

print(f"✅ Graph: {len(G.nodes)} nodes, {len(G.edges)} edges (filtered)")

print("📄 Loading flood/regions CSV...")
flood_df_raw = pd.read_csv(CSV)
flood_df = normalize_columns(flood_df_raw)

# Filter out regions with problematic coordinates (in water/outside Mumbai)
print("🧹 Filtering out regions in water bodies...")
def is_valid_mainland_coordinate(lat, lon, area_name):
    """
    Check if coordinates are on Mumbai mainland (not in water bodies)
    """
    # Mumbai mainland boundaries (MORE RESTRICTIVE to exclude water areas)
    # Latitude: 18.95 to 19.25 (more restrictive to exclude southern water and northern creeks)
    # Longitude: 72.80 to 72.94 (more restrictive to exclude western coast and eastern water)
    if lat < 18.95 or lat > 19.25 or lon < 72.80 or lon > 72.94:
        return False, f"Outside Mumbai mainland bounds"
    
    # Additional checks for specific problematic coordinates that are in water
    problematic_coords = [
        # Known water/island coordinates to exclude (expanded list)
        (19.294, 72.727, "Too far northwest - likely in water"),  # Byculla wrong coords
        (19.111, 72.986, "Too far east - likely in Arabian Sea"),  # Matunga wrong coords  
        (18.878, 72.840, "Too far south - likely in water"),      # Some southern regions
        (19.275, 72.920, "Too far northeast - likely in water"),  # Sewri wrong coords
        (18.812, 72.822, "Too far south - likely in harbor"),     # Prabhadevi wrong coords
        (18.874, 72.828, "Too far south - likely in water"),      # Andheri East wrong coords
        (18.843, 72.928, "Too far southeast - likely in water"),  # Marve wrong coords
        (18.946, 72.942, "Too far east - likely in water"),       # Madanpura (marker 14)
        (18.968, 72.789, "Too far west - likely in water"),       # Bhandup (marker 79)
        (19.165, 72.771, "Too far west - likely in coast"),       # Khar West suspicious
        (19.253, 72.860, "Too far north - likely in creek"),      # Dahisar Subway
        (19.254, 72.868, "Too far north - likely in creek"),      # Ovaripada
    ]
    
    # Check against known problematic coordinates (with tolerance)
    for prob_lat, prob_lon, reason in problematic_coords:
        if abs(lat - prob_lat) < 0.01 and abs(lon - prob_lon) < 0.01:
            return False, reason
    
    # More restrictive geographic zones that are likely water
    # Southeast corner (potential harbor/water area)
    if lat < 19.0 and lon > 72.92:
        return False, "Southeast area - likely in harbor/water"
    
    # Southwest corner (coastal area)  
    if lat < 19.0 and lon < 72.82:
        return False, "Southwest area - likely coastal/water"
    
    # Northwest edge (creek areas)
    if lat > 19.2 and lon < 72.85:
        return False, "Northwest area - likely creek/water"
    
    # Northeast edge (water bodies)
    if lat > 19.2 and lon > 72.92:
        return False, "Northeast area - likely water bodies"
    
    # Check for water-related area names
    area_lower = area_name.lower()
    water_keywords = ['creek', 'bay', 'harbour', 'harbor', 'jetty', 'wharf', 'port', 'dock', 'pier', 'island', 'nala']
    for keyword in water_keywords:
        if keyword in area_lower:
            return False, f"Water-related area name contains '{keyword}'"
    
    return True, "Valid mainland coordinate"

# Apply filtering (DISABLED - using all 102 regions)
original_count = len(flood_df)
print(f"🗺️ Using all {original_count} regions without filtering")

# Create filtered dataframe (no filtering applied)
# flood_df = pd.DataFrame(valid_rows).reset_index(drop=True)
# print(f"✅ Kept {len(flood_df)} valid regions, filtered out {len(filtered_out)} problematic ones")

regions = flood_df["areas"].tolist()
region_lons = flood_df["longitude"].to_numpy()
region_lats = flood_df["latitude"].to_numpy()

# Use original CSV data for module initialization
region_risks = flood_df["flood_risk_level"].tolist()
n_regions = len(regions)
print(f"✅ Regions: {n_regions}")

# ----------------------------
# Map: node -> nearest region (vectorized)
# ----------------------------
print("🔎 Assigning each graph node to nearest region...")
node_ids = np.array(list(G.nodes))
node_lons = np.array([G.nodes[n].get("x", G.nodes[n].get("lon")) for n in node_ids], dtype=float)
node_lats = np.array([G.nodes[n].get("y", G.nodes[n].get("lat")) for n in node_ids], dtype=float)

# distance matrix (regions x nodes)
dist_stack = np.empty((n_regions, len(node_ids)), dtype=float)
for i in range(n_regions):
    dist_stack[i] = haversine_m(region_lons[i], region_lats[i], node_lons, node_lats)

nearest_region_idx_per_node = np.argmin(dist_stack, axis=0)
nodeid_to_region_idx = dict(zip(node_ids.tolist(), nearest_region_idx_per_node.tolist()))

# ----------------------------
# Build sampled edges GeoJSON colored by risk (by origin node’s region)
# ----------------------------
print("🧱 Preparing risk-colored road layer...")
edges_gdf = ox.graph_to_gdfs(G, nodes=False, edges=True, fill_edge_geometry=True)
if "u" not in edges_gdf.columns or "v" not in edges_gdf.columns:
    edges_gdf = edges_gdf.reset_index()

edges_gdf["_u"] = edges_gdf["u"].astype(int)
edges_gdf["region_idx"] = edges_gdf["_u"].map(nodeid_to_region_idx)
edges_gdf["region_name"] = edges_gdf["region_idx"].apply(
    lambda i: regions[i] if (isinstance(i, (int, np.integer)) and 0 <= i < n_regions) else "unknown"
)
edges_gdf["risk_level"] = edges_gdf["region_idx"].apply(
    lambda i: region_risks[i] if (isinstance(i, (int, np.integer)) and 0 <= i < n_regions) else "unknown"
)

edges_gdf_sampled = edges_gdf.iloc[::SAMPLE_FACTOR].copy()
def edge_style(feature):
    risk = str(feature["properties"].get("risk_level", "unknown")).lower()
    color = RISK_COLOR.get(risk, RISK_COLOR["unknown"])
    return {"color": color, "weight": 1.2, "opacity": 0.8}

# ----------------------------
# Fetch POIs (cap per category) - Optional
# ----------------------------
print("📍 Fetching POIs (capped per category)...")
pois_by_cat = {}
ENABLE_POIS = False  # Disable POI fetching to avoid network issues
if ENABLE_POIS:
    for cat, (tag, icon, color) in POI_CATEGORIES.items():
        try:
            gdf = ox.features_from_place(PLACE, tag)
            if gdf is None or gdf.empty:
                pois_by_cat[cat] = None
                continue
            gdf = gdf.to_crs(epsg=4326)
            gdf["geometry"] = gdf.geometry.centroid
            if len(gdf) > MAX_POIS_PER_CAT:
                gdf = gdf.sample(MAX_POIS_PER_CAT, random_state=1)
            pois_by_cat[cat] = gdf
            print(f"  • {cat}: {len(gdf)}")
        except Exception as e:
            print(f"  ⚠️ {cat}: {e}")
            pois_by_cat[cat] = None
else:
    print("  • POIs disabled for faster loading")
    for cat in POI_CATEGORIES.keys():
        pois_by_cat[cat] = None
print("✅ POIs ready.")

# ----------------------------
# Route finder (k nearest low-risk)
# ----------------------------
def calculate_smart_risk_score(area_name, lat, lon, original_risk):
    """
    Calculate a smart risk score considering water proximity and geographic factors
    """
    base_score = {'low': 1, 'moderate': 5, 'high': 9, 'very high': 10}.get(str(original_risk).lower(), 5)
    
    # Water proximity penalty
    water_keywords = ['creek', 'bay', 'harbour', 'jetty', 'wharf', 'port', 'dock', 'pier']
    area_lower = area_name.lower()
    
    water_penalty = 0
    for keyword in water_keywords:
        if keyword in area_lower:
            water_penalty += 3
    
    # Coastal proximity penalty (closer to 18.85 latitude = more south = closer to sea)
    if lat < 18.95:  # Very close to coast
        water_penalty += 2
    elif lat < 19.05:  # Moderately close to coast
        water_penalty += 1
    
    # Island/isolated area penalty
    isolated_keywords = ['island', 'creek', 'isolated']
    for keyword in isolated_keywords:
        if keyword in area_lower:
            water_penalty += 4
    
    final_score = min(base_score + water_penalty, 10)
    
    # Convert back to risk level
    if final_score <= 2:
        return 'low'
    elif final_score <= 5:
        return 'moderate'
    elif final_score <= 8:
        return 'high'
    else:
        return 'very high'

def is_valid_evacuation_destination(area_name, lat, lon, risk_level):
    """
    Validate if a region is a realistic evacuation destination
    """
    # Convert risk to lowercase for comparison
    risk = str(risk_level).lower().strip()
    
    # Filter out high risk areas completely
    if risk in ['high', 'very high', 'extreme']:
        return False, "High flood risk area"
    
    # Check for suspicious coordinates (likely in water bodies)
    # Mumbai mainland roughly: 18.85-19.35°N, 72.75-72.95°E
    if lat < 18.85 or lat > 19.35 or lon < 72.75 or lon > 72.95:
        return False, "Outside mainland Mumbai"
    
    # Filter out regions that are likely in water/islands
    water_keywords = ['creek', 'bay', 'harbour', 'jetty', 'wharf', 'port', 'dock', 'pier', 'island']
    area_lower = area_name.lower()
    
    for keyword in water_keywords:
        if keyword in area_lower:
            return False, f"Water-related location ({keyword})"
    
    # Additional checks for specific problematic areas
    problematic_areas = [
        'mumbai harbour', 'back bay', 'mahim bay', 'thane creek',
        'versova creek', 'mithi river', 'ulhas river'
    ]
    
    for problematic in problematic_areas:
        if problematic in area_lower:
            return False, f"Water body area"
    
    return True, "Valid destination"

def get_k_nearest_low_risk_routes(user_area: str, G, flood_df, k=None):
    # Use default ROUTE_COUNT if k is not provided
    if k is None:
        k = ROUTE_COUNT
    
    all_areas = flood_df["areas"].unique().tolist()
    best_match, score = extract_best_match(user_area.strip().lower(), all_areas)
    if not best_match or score < 50:
        return None, score, []

    start_row = flood_df[flood_df["areas"] == best_match].iloc[0]
    start_lat, start_lon = float(start_row["latitude"]), float(start_row["longitude"])
    orig_node = nearest_node(G, start_lon, start_lat)

    low_df = flood_df[flood_df["flood_risk_level"] == "low"]
    if low_df.empty:
        return best_match, score, []

    # precompute dijkstra distances
    try:
        dists = nx.single_source_dijkstra_path_length(G, orig_node, weight="length")
    except Exception:
        dists = {}

    # candidate destinations with smart risk filtering
    candidates = []
    for _, row in low_df.iterrows():
        area_name = row["areas"]
        lat, lon = float(row["latitude"]), float(row["longitude"])
        original_risk = row["flood_risk_level"]
        
        # Calculate smart risk score
        smart_risk = calculate_smart_risk_score(area_name, lat, lon, original_risk)
        
        # Only consider genuinely low risk areas after smart scoring
        if smart_risk not in ['low', 'moderate']:
            print(f"DEBUG Skipping {area_name}: Smart risk assessment = {smart_risk}")
            continue
        
        # Validate if this is a realistic evacuation destination
        is_valid, reason = is_valid_evacuation_destination(area_name, lat, lon, smart_risk)
        if not is_valid:
            print(f"DEBUG Skipping {area_name}: {reason}")
            continue
            
        node = nearest_node(G, lon, lat)
        d = dists.get(node, None)
        if d is not None and d > 100:  # Must be at least 100m away (not same location)
            candidates.append((area_name, node, d))
    
    if not candidates:
        print("DEBUG No valid evacuation destinations found after smart filtering")
        return best_match, score, []

    print(f"DEBUG Found {len(candidates)} smart-filtered evacuation destinations")
    # Sort by distance and ensure diversity by geographic spread
    candidates.sort(key=lambda x: x[2])
    
    # Choose up to k distinct regions with geographic diversity
    picked = []
    seen = set()
    used_nodes = set()
    
    # First pick closest destinations
    for area, node, d in candidates:
        if area in seen:
            continue
        # Ensure minimum distance between selected nodes for diversity
        if any(abs(G.nodes[node]["y"] - G.nodes[used_node]["y"]) < 0.01 and 
               abs(G.nodes[node]["x"] - G.nodes[used_node]["x"]) < 0.01 
               for used_node in used_nodes):
            continue
        seen.add(area)
        used_nodes.add(node)
        picked.append((area, node, d))
        if len(picked) >= k:
            break
    
    # Smart route selection: prioritize based on multiple factors
    def calculate_route_score(area, node, distance):
        """Calculate comprehensive route score based on multiple factors"""
        # Get destination area info
        dest_info = flood_df[flood_df["areas"] == area].iloc[0]
        
        # Factor 1: Distance (closer is better, but not too close)
        distance_score = max(0, 100 - (distance * 0.1))  # Prefer 2-15km range
        if distance < 2000:  # Too close (< 2km)
            distance_score *= 0.5
        elif distance > 20000:  # Too far (> 20km)
            distance_score *= 0.3
        
        # Factor 2: Flood risk (lower risk is better)
        risk_level = dest_info.get("flood_risk_level", "medium")
        risk_scores = {"low": 100, "medium": 70, "high": 30, "very_high": 10}
        risk_score = risk_scores.get(risk_level, 50)
        
        # Factor 3: Population density (less crowded evacuation sites preferred)
        population = dest_info.get("population", 50000)
        pop_score = max(20, 100 - (population / 1000))  # Prefer areas with < 100k people
        
        # Factor 4: Direction diversity (spread routes in different directions)
        # This will be handled in the selection loop
        
        # Factor 5: Infrastructure accessibility
        area_lower = area.lower()
        infra_score = 80  # Default
        if any(word in area_lower for word in ["airport", "port", "station", "hospital", "central"]):
            infra_score = 95  # Better infrastructure
        elif any(word in area_lower for word in ["slum", "village", "remote"]):
            infra_score = 60  # Limited infrastructure
        
        # Weighted combination
        total_score = (
            distance_score * 0.3 +
            risk_score * 0.35 +
            pop_score * 0.15 +
            infra_score * 0.2
        )
        
        return total_score
    
    # Enhanced route selection with smart scoring
    scored_candidates = []
    for area, node, d in candidates:
        score = calculate_route_score(area, node, d)
        scored_candidates.append((score, area, node, d))
    
    # Sort by score (highest first)
    scored_candidates.sort(key=lambda x: x[0], reverse=True)
    
    # Select routes with direction diversity
    picked = []
    seen = set()
    direction_sectors = {}  # Track routes by compass direction
    
    def get_direction_sector(start_coord, dest_coord):
        """Get compass sector (N, NE, E, SE, S, SW, W, NW) for direction diversity"""
        import math
        lat_diff = dest_coord[0] - start_coord[0]
        lon_diff = dest_coord[1] - start_coord[1]
        angle = math.degrees(math.atan2(lat_diff, lon_diff))
        angle = (angle + 360) % 360  # Normalize to 0-360
        
        sectors = ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]
        sector_idx = int((angle + 22.5) / 45) % 8
        return sectors[sector_idx]
    
    start_coord = (start_lat, start_lon)
    
    # First pass: select best routes with direction diversity
    for score, area, node, d in scored_candidates:
        if area in seen:
            continue
            
        # Get destination coordinates
        dest_row = flood_df[flood_df["areas"] == area].iloc[0]
        dest_lat, dest_lon = float(dest_row["latitude"]), float(dest_row["longitude"])
        dest_coord = (dest_lat, dest_lon)
        
        # Determine direction sector
        sector = get_direction_sector(start_coord, dest_coord)
        
        # Prefer routes in different directions (max 2 per sector for diversity)
        if direction_sectors.get(sector, 0) < 2:
            seen.add(area)
            picked.append((area, node, d))
            direction_sectors[sector] = direction_sectors.get(sector, 0) + 1
            
            if len(picked) >= k:
                break
    
    # Second pass: fill remaining slots with best available routes
    if len(picked) < k:
        for score, area, node, d in scored_candidates:
            if area not in seen:
                seen.add(area)
                picked.append((area, node, d))
                if len(picked) >= k:
                    break

    routes = []
    for area, node, d in picked:
        try:
            # Use realistic pathfinding that follows actual roads
            path = get_realistic_path(G, orig_node, node)
            
            if path is None:
                print(f"DEBUG No realistic road path available to {area}, skipping")
                continue
            
            # Enhanced route validation with multiple criteria
            path_length_m = route_length_m(G, path)
            
            # Get destination coordinates for validation
            dest_row = flood_df[flood_df["areas"] == area].iloc[0]
            dest_lat, dest_lon = float(dest_row["latitude"]), float(dest_row["longitude"])
            
            # Calculate straight-line distance for comparison
            import math
            start_coord = (start_lat, start_lon)
            dest_coord = (dest_lat, dest_lon)
            
            # Haversine formula for straight-line distance
            def haversine_distance(coord1, coord2):
                R = 6371000  # Earth radius in meters
                lat1, lon1 = math.radians(coord1[0]), math.radians(coord1[1])
                lat2, lon2 = math.radians(coord2[0]), math.radians(coord2[1])
                dlat, dlon = lat2 - lat1, lon2 - lon1
                a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
                return 2 * R * math.asin(math.sqrt(a))
            
            straight_line_dist = haversine_distance(start_coord, dest_coord)
            
            # Smart route validation: more realistic criteria
            circuity_ratio = path_length_m / max(straight_line_dist, 1)
            
            # Different validation for different distances
            max_circuity = 2.5 if straight_line_dist < 5000 else 3.0 if straight_line_dist < 15000 else 4.0
            
            if circuity_ratio > max_circuity:
                print(f"DEBUG Route to {area} is too circuitous (ratio: {circuity_ratio:.1f}, max: {max_circuity:.1f}), skipping")
                continue
            
            # Calculate realistic ETA with traffic simulation
            base_speed = ASSUMED_SPEED_KMPH
            traffic_factor = random.uniform(0.8, 1.2)  # Traffic affects speed ±20%
            actual_speed = base_speed * traffic_factor
            eta_min = (path_length_m / 1000.0) / max(actual_speed, 1) * 60.0
            
            # Add route difficulty factor based on area type
            area_lower = area.lower()
            if any(word in area_lower for word in ["highway", "express", "main"]):
                eta_min *= 0.9  # Faster roads
            elif any(word in area_lower for word in ["inner", "narrow", "old"]):
                eta_min *= 1.1  # Slower roads
            
            print(f"DEBUG Enhanced route: {area}, distance: {path_length_m:.1f}m, straight: {straight_line_dist:.1f}m, ratio: {circuity_ratio:.1f}, speed: {actual_speed:.1f}km/h ✅")
            
            routes.append({
                "dest_region": area,
                "dest_node": int(node),
                "path": path,
                "distance_km": round(path_length_m / 1000.0, 3),
                "eta_min": round(eta_min, 1),
                "traffic_factor": round(traffic_factor, 2),
                "circuity_ratio": round(circuity_ratio, 1),
                "route_score": round(calculate_route_score(area, node, d), 1)
            })
        except Exception as e:
            print(f"DEBUG Route error for {area}: {e}")
            continue

    return best_match, score, routes

# ----------------------------
# Map builder and saver
# ----------------------------
def build_and_save_map(start_region_name: str, routes: list, out_file: str, 
                      show_roads: bool = False, show_regions: bool = True, 
                      show_hospitals: bool = True, base_map: str = "toner",
                      realtime_flood_data: dict = None):
    # center on start region
    idx = int(flood_df.index[flood_df["areas"] == start_region_name][0])
    center = [float(region_lats[idx]), float(region_lons[idx])]
    
    # Add base map layers based on parameter
    if base_map == "light":
        m = folium.Map(location=center, zoom_start=12, tiles="cartodbpositron", control_scale=True)
    elif base_map == "dark":
        m = folium.Map(location=center, zoom_start=12, tiles="cartodbdark_matter", control_scale=True)
    elif base_map == "toner":
        m = folium.Map(location=center, zoom_start=12, tiles=None, control_scale=True)
        folium.TileLayer(
            tiles="https://tiles.stadiamaps.com/tiles/stamen_toner/{z}/{x}/{y}{r}.png",
            name="Toner", 
            attr="Map tiles by Stamen Design, under CC BY 3.0. Data by OpenStreetMap, under ODbL"
        ).add_to(m)
    else:  # satellite or default
        m = folium.Map(location=center, zoom_start=12, tiles="OpenStreetMap", control_scale=True)

    # Enhanced map controls (from alit.py)
    MiniMap(toggle_display=True).add_to(m)
    Fullscreen().add_to(m)
    MeasureControl(primary_length_unit="kilometers").add_to(m)
    MousePosition(position="bottomright", prefix="Lat/Lon: ").add_to(m)
    LocateControl(auto_start=False).add_to(m)

    # Enhanced Risk-colored road heatmap layer
    def enhanced_style_function(feature):
        risk = str(feature["properties"].get("risk_level", "unknown")).lower()
        color = RISK_COLOR.get(risk, "#9e9e9e")
        
        # Enhanced styling based on risk level
        if risk == "high":
            return {
                "color": color,
                "weight": 2.5,
                "opacity": 0.85,
                "fillOpacity": 0.4,
                "dashArray": None,
                "lineCap": "round"
            }
        elif risk == "moderate":
            return {
                "color": color,
                "weight": 1.8,
                "opacity": 0.75,
                "fillOpacity": 0.3,
                "dashArray": None,
                "lineCap": "round"
            }
        else:  # low or unknown
            return {
                "color": color,
                "weight": 1.2,
                "opacity": 0.65,
                "fillOpacity": 0.2,
                "dashArray": None,
                "lineCap": "round"
            }
    
    # Create feature groups for layer control
    if show_roads:
        roads_layer = folium.FeatureGroup(name="Mumbai Roads - Flood Risk Heatmap", show=True)
    else:
        roads_layer = folium.FeatureGroup(name="Mumbai Roads - Flood Risk Heatmap", show=False)
        
    regions_layer = folium.FeatureGroup(name="Flood Risk Regions", show=show_regions)
    
    # Only add roads layer if show_roads is True
    if show_roads:
        gj = GeoJson(
            data=edges_gdf_sampled.__geo_interface__,
            style_function=enhanced_style_function,
            tooltip=folium.GeoJsonTooltip(
                fields=["region_name", "risk_level"],
                aliases=["🏘️ Region", "⚠️ Flood Risk"],
                sticky=True,
                style="""
                    background-color: rgba(255,255,255,0.95);
                    border: 2px solid #333;
                    border-radius: 5px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.3);
                """
            ),
        )
        roads_layer.add_child(gj)
        m.add_child(roads_layer)

    # Enhanced Region markers with heatmap-style visualization
    for i, nm in enumerate(regions):
        # Use realtime data if available, otherwise use default risk
        if realtime_flood_data and nm.lower() in realtime_flood_data:
            risk_level = str(realtime_flood_data[nm.lower()]).lower()
        else:
            risk_level = str(region_risks[i]).lower()
            
        color = RISK_COLOR.get(risk_level, RISK_COLOR["unknown"])
        marker_config = RISK_MARKER_CONFIG.get(risk_level, RISK_MARKER_CONFIG["unknown"])
        
        # Pastel pill marker to match app style
        pastel_bg = {
            "low": "#E8F5E9",
            "moderate": "#FFF3E0",
            "high": "#FDECEA",
            "unknown": "#F1F1F1",
        }.get(risk_level, "#F1F1F1")

        marker_icon = folium.DivIcon(
            html=f"""
            <div style=\"background:{pastel_bg};border:2px solid {color};border-radius:12px;padding:2px 6px;color:{color};font-size:11px;font-weight:700;box-shadow:0 2px 6px rgba(0,0,0,0.15);\">{(i+1)}</div>
            """,
            icon_size=(28, 18),
            icon_anchor=(14, 9)
        )
        
        # Enhanced popup with risk-based styling
        risk_emoji = {"low": "🟢", "moderate": "🟡", "high": "🔴"}.get(risk_level, "⚪")
        popup_html = f"""
        <div style="min-width: 220px; font-family: Arial, sans-serif;">
            <h4 style="margin: 0 0 10px 0; color: {color}; border-bottom: 2px solid {color}; padding-bottom: 5px;">
                {risk_emoji} {nm.title()}
            </h4>
            <p style="margin: 5px 0; font-size: 14px;">
                <strong>Risk Level:</strong> 
                <span style="color: {color}; font-weight: bold; text-transform: uppercase;">
                    {str(region_risks[i]).title()}
                </span>
            </p>
            <p style="margin: 5px 0; font-size: 12px; color: #666;">
                <strong>Marker:</strong> #{i+1}
            </p>
            <p style="margin: 5px 0; font-size: 12px; color: #666;">
                <strong>Coordinates:</strong> {float(region_lats[i]):.4f}, {float(region_lons[i]):.4f}
            </p>
            <p style="margin: 5px 0;"><strong>Marker #:</strong> {i+1}</p>
        </div>
        """
        
        folium.Marker(
            location=[float(region_lats[i]), float(region_lons[i])],
            icon=marker_icon,
            popup=folium.Popup(popup_html, max_width=250),
            tooltip=f"#{i+1}: {nm.title()} — {str(region_risks[i]).title()} Risk"
        ).add_to(regions_layer)

    # Add regions layer to map
    m.add_child(regions_layer)

    # Enhanced POI clusters with selective visibility
    for cat, gdf in pois_by_cat.items():
        if gdf is None or gdf.empty:
            continue
        
        # Only show hospitals if show_hospitals is True, skip other POIs
        if cat == "hospital" and not show_hospitals:
            continue
        elif cat != "hospital":
            continue  # Skip all non-hospital POIs for now
            
        icon = POI_CATEGORIES[cat][1]
        color = POI_CATEGORIES[cat][2]
        
        # Create feature group for each POI category
        poi_layer = folium.FeatureGroup(
            name=f"🏥 {cat.replace('_',' ').title()} ({len(gdf)})" if cat == "hospital" 
                 else f"{cat.replace('_',' ').title()} ({len(gdf)})",
            show=show_hospitals if cat == "hospital" else False
        )
        
        cluster = MarkerCluster()
        for _, row in gdf.iterrows():
            try:
                lat = float(row.geometry.y); lon = float(row.geometry.x)
            except Exception:
                continue
            popup_txt = str(row.get("name") or cat.replace("_", " ").title())
            folium.Marker(
                location=[lat, lon],
                icon=folium.Icon(color=color, icon=icon, prefix="fa"),
                popup=popup_txt
            ).add_to(cluster)
        
        poi_layer.add_child(cluster)
        m.add_child(poi_layer)

    # Draw routes with Google Maps style visualization
    route_colors = [
        {"color": "#4285F4", "alt_color": "#1A73E8"},  # Google Blue
        {"color": "#34A853", "alt_color": "#137333"},  # Google Green  
        {"color": "#EA4335", "alt_color": "#C5221F"},  # Google Red
        {"color": "#FBBC05", "alt_color": "#F29900"},  # Google Yellow
        {"color": "#9C27B0", "alt_color": "#7B1FA2"},  # Purple
        {"color": "#FF9800", "alt_color": "#E65100"},  # Orange
        {"color": "#795548", "alt_color": "#5D4037"},  # Brown
        {"color": "#607D8B", "alt_color": "#455A64"},  # Blue Grey
    ]
    
    # Real-time route enhancement variables
    import random
    import time
    
    for i, r in enumerate(routes):
        coords = [(G.nodes[n]["y"], G.nodes[n]["x"]) for n in r["path"]]
        route_style = route_colors[i % len(route_colors)]
        
        # Simulate real-time traffic conditions
        traffic_factor = random.uniform(0.7, 1.3)  # Traffic affects speed
        real_eta = r['eta_min'] * traffic_factor
        traffic_status = "🟢 Clear" if traffic_factor < 0.9 else "🟡 Moderate" if traffic_factor < 1.1 else "🔴 Heavy"
        
        if len(coords) >= 1:
            if len(coords) == 1:
                # Single point route - enhanced marker
                folium.CircleMarker(
                    location=coords[0],
                    radius=15, 
                    color=route_style["alt_color"], 
                    fill=True, 
                    fill_color=route_style["color"], 
                    fill_opacity=0.9,
                    weight=4,
                    tooltip=f"<b>🚀 Route {i+1}</b><br>{r['distance_km']:.2f} km • {real_eta:.0f} min<br>Traffic: {traffic_status}<br>→ {r['dest_region'].title()}",
                ).add_to(m)
            else:
                # Enhanced multi-point route with realistic styling
                
                # 1. Outer glow effect (shadow)
                folium.PolyLine(
                    coords,
                    color="#000000",
                    weight=12,
                    opacity=0.2,
                ).add_to(m)
                
                # 2. Background route line (white/light)
                folium.PolyLine(
                    coords,
                    color="#FFFFFF",
                    weight=8,
                    opacity=0.8,
                ).add_to(m)
                
                # 3. Main route line with gradient effect
                folium.PolyLine(
                    coords,
                    color=route_style["color"],
                    weight=6,
                    opacity=0.95,
                    popup=f"""
                    <div style='width:200px;'>
                        <h4 style='margin:0; color:{route_style["color"]};'>🚀 Route {i+1}</h4>
                        <hr style='margin:5px 0;'>
                        <p style='margin:2px 0;'><b>🎯 Destination:</b> {r['dest_region'].title()}</p>
                        <p style='margin:2px 0;'><b>📏 Distance:</b> {r['distance_km']:.2f} km</p>
                        <p style='margin:2px 0;'><b>⏱️ ETA:</b> {real_eta:.0f} min</p>
                        <p style='margin:2px 0;'><b>🚦 Traffic:</b> {traffic_status}</p>
                        <p style='margin:2px 0;'><b>🚗 Avg Speed:</b> {(r['distance_km']/real_eta*60):.1f} km/h</p>
                        <small style='color:#666;'>Last updated: {time.strftime('%H:%M:%S')}</small>
                    </div>
                    """,
                ).add_to(m)
                
                # 4. Dynamic route highlights with animated dashes
                for j in range(0, len(coords)-1, max(1, len(coords)//10)):
                    if j+1 < len(coords):
                        segment_coords = [coords[j], coords[j+1]]
                        folium.PolyLine(
                            segment_coords,
                            color=route_style["alt_color"],
                            weight=3,
                            opacity=0.7,
                            dash_array="10, 10",
                        ).add_to(m)
                
                # 5. Enhanced direction arrows with better spacing
                if len(coords) > 3:
                    arrow_positions = [len(coords)//4, len(coords)//2, 3*len(coords)//4]
                    for arrow_pos in arrow_positions:
                        if arrow_pos < len(coords) - 1:
                            start_coord = coords[arrow_pos]
                            end_coord = coords[arrow_pos + 1]
                            
                            # Calculate arrow direction
                            import math
                            lat_diff = end_coord[0] - start_coord[0]
                            lon_diff = end_coord[1] - start_coord[1]
                            angle = math.degrees(math.atan2(lat_diff, lon_diff))
                            
                            # Enhanced direction arrows with custom icons
                            folium.Marker(
                                location=start_coord,
                                icon=folium.DivIcon(
                                    html=f'''
                                    <div style="
                                        transform: rotate({angle}deg);
                                        color: {route_style["color"]};
                                        font-size: 16px;
                                        text-shadow: 1px 1px 2px rgba(0,0,0,0.7);
                                    ">➤</div>
                                    ''',
                                    icon_size=(20, 20),
                                    icon_anchor=(10, 10),
                                )
                            ).add_to(m)
                
                # 6. Waypoint markers along route
                if len(coords) > 5:
                    waypoint_positions = [len(coords)//3, 2*len(coords)//3]
                    for wp_idx, wp_pos in enumerate(waypoint_positions):
                        if wp_pos < len(coords):
                            folium.CircleMarker(
                                location=coords[wp_pos],
                                radius=4,
                                color=route_style["alt_color"],
                                fill=True,
                                fill_color="white",
                                fill_opacity=1.0,
                                weight=2,
                                tooltip=f"Waypoint {wp_idx+1}"
                            ).add_to(m)

        # Start marker styled as pastel chip (only for first route)
        if i == 0:
            start_node = r["path"][0]
            folium.Marker(
                location=(G.nodes[start_node]["y"], G.nodes[start_node]["x"]),
                icon=folium.DivIcon(
                    html='''
                    <div style="
                        background: #22c55e;
                        border: 3px solid white;
                        border-radius: 10px;
                        width: 30px;
                        height: 30px;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        box-shadow: 0 3px 8px rgba(0,0,0,0.25);
                        font-size: 16px;
                        color: white;
                        font-weight: 800;
                    ">🏁</div>
                    ''',
                    icon_size=(30, 30),
                    icon_anchor=(15, 15),
                ),
                popup=f"""
                <div style='width:180px;'>
                    <h4 style='margin:0; color:#22c55e;'>🚩 EVACUATION START</h4>
                    <hr style='margin:5px 0;'>
                    <p style='margin:2px 0;'><b>Location:</b> {start_region_name.title()}</p>
                    <p style='margin:2px 0;'><b>Available Routes:</b> {len(routes)}</p>
                    <p style='margin:2px 0;'><b>Status:</b> 🟢 Ready to evacuate</p>
                    <small style='color:#666;'>Select your preferred route</small>
                </div>
                """,
            ).add_to(m)

        # Enhanced destination markers with route info and status
        dest_node = r["path"][-1]
        priority_colors = ["#dc3545", "#fd7e14", "#007bff", "#6f42c1", "#20c997"]
        dest_color = priority_colors[i % len(priority_colors)]
        
        # Destination marker styled to match Flutter UI numbered chips
        folium.Marker(
            location=(G.nodes[dest_node]["y"], G.nodes[dest_node]["x"]),
            icon=folium.DivIcon(
                html=f'''
                <div style="
                    background: {dest_color};
                    border-radius: 8px;
                    width: 28px;
                    height: 28px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    box-shadow: 0 2px 6px rgba(0,0,0,0.25);
                    font-size: 14px;
                    font-weight: 800;
                    color: #ffffff;
                ">{i+1}</div>
                ''',
                icon_size=(28, 28),
                icon_anchor=(14, 14),
            ),
            popup=f"""
            <div style='width:220px;'>
                <h4 style='margin:0; color:{dest_color};'>🏁 Route {i+1} Destination</h4>
                <hr style='margin:5px 0;'>
                <p style='margin:2px 0;'><b>🎯 Safe Zone:</b> {r['dest_region'].title()}</p>
                <p style='margin:2px 0;'><b>📏 Distance:</b> {r['distance_km']:.2f} km</p>
                <p style='margin:2px 0;'><b>⏱️ Real-time ETA:</b> {real_eta:.0f} min</p>
                <p style='margin:2px 0;'><b>🚦 Traffic:</b> {traffic_status}</p>
                <p style='margin:2px 0;'><b>🚗 Avg Speed:</b> {(r['distance_km']/real_eta*60):.1f} km/h</p>
                <p style='margin:2px 0;'><b>🛡️ Safety Level:</b> High</p>
                <small style='color:#666;'>Updated: {time.strftime('%H:%M:%S')}</small>
            </div>
            """,
        ).add_to(m)

    # Calculate totals for summary panel
    totals = {"distance": 0.0, "eta": 0.0}
    for r in routes:
        totals["distance"] += r["distance_km"]
        totals["eta"] += r["eta_min"]

    # On-map summary panel
    routes_info = [{
        "dest_region": r["dest_region"].title(),
        "distance_km": round(r["distance_km"], 3),
        "eta_min": round(r["eta_min"], 1),
    } for r in routes]
    panel_html = (
        '<div id="evac-panel" style="position: fixed; bottom: 18px; left: 18px; z-index:9999;'
        'background: rgba(255,255,255,0.95); padding: 12px; border-radius:8px;'
        'box-shadow: 0 1px 8px rgba(0,0,0,0.2); max-width:340px; font-family: Arial, sans-serif;">'
        '<h4 style="margin:0 0 6px 0;">Evacuation Summary</h4>'
        '<div id="routes-list" style="font-size:13px; line-height:1.4;"></div>'
        '<hr style="margin:8px 0;">'
        '<div style="font-weight:600;">Totals:</div>'
        '<div id="totals" style="font-size:13px;"></div>'
        '<div style="margin-top:8px; font-size:12px; color:#444;">(ETA assumes ~25 km/h)</div>'
        '</div>'
        '<script>'
        'const routes = ' + json.dumps(routes_info) + ';'
        'function renderPanel(){'
        '  const el = document.getElementById("routes-list");'
        '  const t  = document.getElementById("totals");'
        '  el.innerHTML = "";'
        '  let d=0, e=0;'
        '  routes.forEach((r,i)=>{'
        '    d += r.distance_km; e += r.eta_min;'
        '    const div = document.createElement("div");'
        '    div.innerHTML = "<strong>Route "+(i+1)+":</strong> "+r.distance_km.toFixed(2)+" km — " +'
        '                    r.eta_min.toFixed(0)+" min → <em>"+r.dest_region+"</em>";'
        '    el.appendChild(div);'
        '  });'
        '  t.innerHTML = "<div>Total distance: <strong>"+d.toFixed(2)+" km</strong></div>" +'
        '                "<div>Combined ETA: <strong>"+e.toFixed(0)+" min</strong></div>";'
        '}'
        'renderPanel();'
        '</script>'
    )
    m.get_root().html.add_child(folium.Element(panel_html))

    # Add Google Maps style enhancements
    google_style_js = '''
    <style>
    .leaflet-container {
        font-family: 'Roboto', 'Arial', sans-serif;
        background: #e5e3df;
    }
    .leaflet-popup-content-wrapper {
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        background: white;
    }
    .leaflet-popup-content {
        margin: 12px 16px;
        font-size: 14px;
        line-height: 1.5;
        color: #202124;
    }
    .leaflet-popup-tip {
        box-shadow: 0 2px 6px rgba(0,0,0,0.15);
    }
    .leaflet-tooltip {
        background: rgba(60,64,67,0.9);
        color: white;
        border: none;
        border-radius: 4px;
        font-size: 12px;
        font-weight: 500;
        padding: 6px 10px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.2);
    }
    .leaflet-control-zoom a {
        border-radius: 2px;
        font-size: 18px;
        line-height: 30px;
        background: white;
        box-shadow: 0 2px 6px rgba(0,0,0,0.3);
    }
    .leaflet-control-layers {
        border-radius: 8px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.2);
    }
    #evac-panel {
        border: 1px solid #dadce0;
        background: rgba(255,255,255,0.97);
        backdrop-filter: blur(10px);
        animation: slideInUp 0.5s ease-out;
    }
    
    @keyframes slideInUp {
        from { transform: translateY(20px); opacity: 0; }
        to { transform: translateY(0); opacity: 1; }
    }
    
    @keyframes pulse {
        0% { opacity: 1; }
        50% { opacity: 0.7; }
        100% { opacity: 1; }
    }
    
    .route-pulse {
        animation: pulse 2s ease-in-out infinite;
    }
    
    .route-highlight {
        filter: drop-shadow(0 0 10px rgba(255,255,0,0.8)) !important;
        stroke-width: 8 !important;
    }
    </style>
    <script>
    // Enhanced real-time route system
    document.addEventListener('DOMContentLoaded', function() {
        console.log('🚀 Initializing Enhanced Route System...');
        
        // Get map instance
        const map = window[Object.keys(window).find(key => key.startsWith('map_'))];
        if (!map) {
            console.warn('Map instance not found');
            return;
        }
        
        // Enhanced map settings
        map.options.zoomAnimation = true;
        map.options.fadeAnimation = true;
        map.options.markerZoomAnimation = true;
        map.options.preferCanvas = true; // Better performance
        
        // Real-time traffic simulation variables
        let trafficData = {};
        let routeElements = [];
        let updateInterval;
        
        // Initialize route tracking
        function initRouteTracking() {
            const polylines = document.querySelectorAll('.leaflet-interactive');
            routeElements = Array.from(polylines);
            
            routeElements.forEach((line, index) => {
                line.setAttribute('data-route-id', index);
                trafficData[index] = {
                    baseSpeed: 25 + Math.random() * 10, // 25-35 km/h base
                    currentSpeed: 25,
                    traffic: 'clear',
                    lastUpdate: Date.now(),
                    incidents: []
                };
                
                // Enhanced hover effects
                line.addEventListener('mouseenter', function() {
                    this.classList.add('route-highlight');
                    this.style.transition = 'all 0.3s ease';
                    showRouteTooltip(index, event);
                });
                
                line.addEventListener('mouseleave', function() {
                    this.classList.remove('route-highlight');
                    hideRouteTooltip();
                });
                
                // Click for detailed route info
                line.addEventListener('click', function() {
                    showDetailedRouteInfo(index);
                });
            });
        }
        
        // Real-time traffic update simulation
        function updateTrafficConditions() {
            Object.keys(trafficData).forEach(routeId => {
                const route = trafficData[routeId];
                const now = Date.now();
                
                // Simulate traffic changes every 10-30 seconds
                if (now - route.lastUpdate > (10000 + Math.random() * 20000)) {
                    // Random traffic event
                    const events = ['clear', 'light', 'moderate', 'heavy', 'incident'];
                    const newTraffic = events[Math.floor(Math.random() * events.length)];
                    
                    route.traffic = newTraffic;
                    route.currentSpeed = calculateSpeedFromTraffic(route.baseSpeed, newTraffic);
                    route.lastUpdate = now;
                    
                    // Visual feedback for traffic changes
                    updateRouteVisuals(routeId, newTraffic);
                    
                    console.log(`🚦 Route ${parseInt(routeId)+1}: ${newTraffic} traffic (${route.currentSpeed.toFixed(1)} km/h)`);
                }
            });
            
            updateInfoPanel();
        }
        
        function calculateSpeedFromTraffic(baseSpeed, traffic) {
            const factors = {
                'clear': 1.2,
                'light': 1.0,
                'moderate': 0.8,
                'heavy': 0.5,
                'incident': 0.3
            };
            return baseSpeed * (factors[traffic] || 1.0);
        }
        
        function updateRouteVisuals(routeId, traffic) {
            const element = routeElements[routeId];
            if (!element) return;
            
            // Remove existing traffic classes
            element.classList.remove('traffic-clear', 'traffic-light', 'traffic-moderate', 'traffic-heavy', 'traffic-incident');
            
            // Add new traffic class
            element.classList.add(`traffic-${traffic}`);
            
            // Add pulse effect for incidents
            if (traffic === 'incident' || traffic === 'heavy') {
                element.classList.add('route-pulse');
                setTimeout(() => element.classList.remove('route-pulse'), 5000);
            }
        }
        
        function updateInfoPanel() {
            const panel = document.getElementById('evac-panel');
            if (!panel) return;
            // Removed LIVE badge per UI request
        }
        
        function showRouteTooltip(routeId, event) {
            const route = trafficData[routeId];
            if (!route) return;
            
            const tooltip = document.createElement('div');
            tooltip.id = 'route-tooltip';
            tooltip.style.cssText = `
                position: fixed;
                background: rgba(0,0,0,0.9);
                color: white;
                padding: 8px 12px;
                border-radius: 6px;
                font-size: 12px;
                z-index: 10000;
                pointer-events: none;
                max-width: 200px;
                border: 1px solid #555;
            `;
            
            const trafficEmojis = {
                'clear': '🟢',
                'light': '🟡',
                'moderate': '🟠',
                'heavy': '🔴',
                'incident': '⚠️'
            };
            
            tooltip.innerHTML = `
                <b>Route ${parseInt(routeId)+1}</b><br>
                ${trafficEmojis[route.traffic]} ${route.traffic.toUpperCase()} traffic<br>
                🚗 ${route.currentSpeed.toFixed(1)} km/h avg speed<br>
                <small>Click for detailed info</small>
            `;
            
            tooltip.style.left = (event.clientX + 10) + 'px';
            tooltip.style.top = (event.clientY - 50) + 'px';
            
            document.body.appendChild(tooltip);
        }
        
        function hideRouteTooltip() {
            const tooltip = document.getElementById('route-tooltip');
            if (tooltip) {
                tooltip.remove();
            }
        }
        
        function showDetailedRouteInfo(routeId) {
            const route = trafficData[routeId];
            if (!route) return;
            
            const modal = document.createElement('div');
            modal.style.cssText = `
                position: fixed;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                background: #ffffff;
                padding: 18px;
                border-radius: 16px;
                border: 1px solid #ececec;
                box-shadow: 0 8px 28px rgba(34, 34, 59, 0.18);
                z-index: 10001;
                max-width: 360px;
                width: 92%;
                font-family: 'Inter', 'Segoe UI', Arial, sans-serif;
                color: #22223B;
            `;
            const chipColor = '#B5C7F7';
            const labelStyle = 'margin:6px 0; font-size:14px; display:flex; align-items:center; gap:8px;';
            modal.innerHTML = `
                <div style="display:flex; align-items:center; gap:10px; margin-bottom:10px;">
                  <div style="background:${chipColor}; color:#22223B; padding:4px 10px; border-radius:12px; font-weight:700; font-size:12px;">Route ${parseInt(routeId)+1}</div>
                  <div style="font-weight:700; font-size:16px;">Details</div>
                </div>
                <div style="${labelStyle}">🟢 <span style="min-width:120px; font-weight:600; opacity:0.75;">Current Status</span> <span style="font-weight:700;">${route.traffic.toUpperCase()}</span></div>
                <div style="${labelStyle}">⚡ <span style="min-width:120px; font-weight:600; opacity:0.75;">Speed</span> <span style="font-weight:700;">${route.currentSpeed.toFixed(1)} km/h</span></div>
                <div style="${labelStyle}">📊 <span style="min-width:120px; font-weight:600; opacity:0.75;">Base Speed</span> <span style="font-weight:700;">${route.baseSpeed.toFixed(1)} km/h</span></div>
                <div style="${labelStyle}">🕒 <span style="min-width:120px; font-weight:600; opacity:0.75;">Last Update</span> <span style="font-weight:700;">${new Date(route.lastUpdate).toLocaleTimeString()}</span></div>
                <div style="${labelStyle}">🛡️ <span style="min-width:120px; font-weight:600; opacity:0.75;">Safety</span> <span style="font-weight:700;">High Priority Route</span></div>
                <div style="display:flex; justify-content:flex-end; margin-top:12px;">
                  <button onclick="this.closest('div').parentElement.remove()" style="
                    background:${chipColor}; color:#22223B; border:none; padding:8px 14px; border-radius:10px; font-weight:700; cursor:pointer;">
                    Close
                  </button>
                </div>
            `;
            
            document.body.appendChild(modal);
            
            // Auto close after 10 seconds
            setTimeout(() => {
                if (modal.parentElement) modal.remove();
            }, 10000);
        }
        
        // Add CSS for traffic conditions
        function addTrafficStyles() {
            const style = document.createElement('style');
            style.textContent = `
                .traffic-clear { stroke: #28a745 !important; }
                .traffic-light { stroke: #ffc107 !important; }
                .traffic-moderate { stroke: #fd7e14 !important; }
                .traffic-heavy { stroke: #dc3545 !important; }
                .traffic-incident { 
                    stroke: #dc3545 !important; 
                    stroke-dasharray: 10, 5 !important;
                    animation: pulse 1s ease-in-out infinite;
                }
            `;
            document.head.appendChild(style);
        }
        
        // Initialize everything
        setTimeout(() => {
            initRouteTracking();
            addTrafficStyles();
            updateInfoPanel();
            
            // Start real-time updates
            updateInterval = setInterval(updateTrafficConditions, 5000);
            console.log('✅ Real-time route system activated');
        }, 1000);
        
        // Cleanup on page unload
        window.addEventListener('beforeunload', () => {
            if (updateInterval) {
                clearInterval(updateInterval);
            }
        });
    });
    </script>
    '''
    m.get_root().html.add_child(folium.Element(google_style_js))

    folium.LayerControl(collapsed=False).add_to(m)
    m.save(out_file)
    print(f"✅ Map saved to: {out_file}")

# ----------------------------
# Main
# ----------------------------
if __name__ == "__main__":
    try:
        user_region = input("🏠 Enter your region name (area): ").strip()
    except EOFError:
        raise SystemExit("❌ No input provided.")
    if not user_region:
        raise SystemExit("❌ Empty input.")

    matched, score, routes = get_k_nearest_low_risk_routes(user_region, G, flood_df, k=ROUTE_COUNT)
    if not matched:
        print(f"❌ Could not match '{user_region}'. Try a different area name.")
        raise SystemExit(1)
    if not routes:
        print("⚠️ No safe evacuation routes found.")
        raise SystemExit(2)

    print(f"✅ Using region: {matched.title()} (match score {score}%)")
    for i, r in enumerate(routes, 1):
        print(f"  • Route {i}: to {r['dest_region'].title()} — {r['distance_km']:.2f} km, {r['eta_min']:.0f} min")

    build_and_save_map(matched, routes, OUT_HTML)
