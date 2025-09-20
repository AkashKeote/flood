#!/usr/bin/env python3
"""
Simplified app_core.py for evacuation routes with lazy loading
"""

import os
import json
import math
import numpy as np
import pandas as pd
import networkx as nx
import osmnx as ox

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
CSV = "mumbai_ward_area_floodrisk.csv"
ASSUMED_SPEED_KMPH = 25.0       # for ETA
ROUTE_COUNT = 10                # default evacuation routes to draw (increased from 5)
MAX_ROUTE_COUNT = 15            # maximum routes allowed for performance
MIN_ROUTE_COUNT = 3             # minimum routes to show

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

def route_length_m(G: nx.MultiDiGraph, route):
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
# Global variables for lazy loading
# ----------------------------
G = None
flood_df = None
regions = []
region_lons = []
region_lats = []
region_risks = []

def load_graph_if_needed():
    """Lazy load the road network graph when actually needed"""
    global G, flood_df, regions, region_lons, region_lats, region_risks
    
    if G is not None:
        return G
        
    if not os.path.exists(GRAPHML):
        raise FileNotFoundError(f"❌ Missing {GRAPHML} in current folder.")
    if not os.path.exists(CSV):
        raise FileNotFoundError(f"❌ Missing {CSV} in current folder.")
    
    try:
        print("🔄 Loading road network on demand...")
        G = ox.load_graphml(GRAPHML)
        # ensure we work on the largest *weakly* connected component (so routes exist)
        largest_cc_nodes = max(nx.weakly_connected_components(G), key=len)
        G = G.subgraph(largest_cc_nodes).copy()
        print(f"✅ Graph loaded: {len(G.nodes)} nodes, {len(G.edges)} edges")
        
        # Load CSV data
        print("📄 Loading flood/regions CSV...")
        flood_df_raw = pd.read_csv(CSV)
        flood_df = normalize_columns(flood_df_raw)
        regions = flood_df["areas"].tolist()
        region_lons = flood_df["longitude"].to_numpy()
        region_lats = flood_df["latitude"].to_numpy()
        region_risks = flood_df["flood_risk_level"].tolist()
        print(f"✅ Regions: {len(regions)}")
        
    except Exception as e:
        print(f"❌ Failed to load graph or CSV: {e}")
        raise
    return G

def get_k_nearest_low_risk_routes(from_area: str, to_area: str = "marine drive", k: int = 5, 
                                   safety_weight: float = 3.0, max_distance_km: float = 30.0):
    """
    Find the k nearest low-risk evacuation routes between two areas.
    """
    try:
        # Ensure graph is loaded
        G = load_graph_if_needed()
        
        print(f"🔍 Finding {k} evacuation routes from '{from_area}' to '{to_area}'...")
        
        # Fuzzy match areas
        from_match, from_score = extract_best_match(from_area.lower(), regions)
        to_match, to_score = extract_best_match(to_area.lower(), regions)
        
        if from_score < 60:
            return {"error": f"From area '{from_area}' not found. Closest match: {from_match} ({from_score}%)"}
        if to_score < 60:
            return {"error": f"To area '{to_area}' not found. Closest match: {to_match} ({to_score}%)"}
        
        # Get coordinates
        from_idx = regions.index(from_match)
        to_idx = regions.index(to_match)
        
        from_lat, from_lon = region_lats[from_idx], region_lons[from_idx]
        to_lat, to_lon = region_lats[to_idx], region_lons[to_idx]
        
        # Find nearest nodes
        from_node = nearest_node(G, from_lon, from_lat)
        to_node = nearest_node(G, to_lon, to_lat)
        
        print(f"📍 From: {from_match} ({from_lat:.4f}, {from_lon:.4f}) -> Node {from_node}")
        print(f"📍 To: {to_match} ({to_lat:.4f}, {to_lon:.4f}) -> Node {to_node}")
        
        if from_node == to_node:
            return {"error": "Source and destination are the same location"}
        
        # Calculate distance check
        direct_distance_km = haversine_m(from_lon, from_lat, to_lon, to_lat) / 1000.0
        if direct_distance_km > max_distance_km:
            return {"error": f"Distance too far: {direct_distance_km:.1f}km > {max_distance_km}km"}
        
        # Find routes using different algorithms
        routes = []
        
        # Method 1: Shortest path
        try:
            shortest_route = nx.shortest_path(G, from_node, to_node, weight='length')
            routes.append(("shortest", shortest_route))
        except nx.NetworkXNoPath:
            pass
        
        # Method 2: Alternative paths using different intermediate nodes
        try:
            # Get nodes within reasonable distance from both source and destination
            from_neighbors = list(G.neighbors(from_node))[:10]  # Limit for performance
            to_neighbors = list(G.neighbors(to_node))[:10]
            
            for intermediate in from_neighbors + to_neighbors:
                if intermediate != from_node and intermediate != to_node:
                    try:
                        route1 = nx.shortest_path(G, from_node, intermediate, weight='length')
                        route2 = nx.shortest_path(G, intermediate, to_node, weight='length')
                        full_route = route1 + route2[1:]  # Avoid duplicating intermediate node
                        routes.append(("alternative", full_route))
                        if len(routes) >= k * 2:  # Get more than needed, then filter
                            break
                    except nx.NetworkXNoPath:
                        continue
        except Exception as e:
            print(f"⚠️ Alternative route finding failed: {e}")
        
        if not routes:
            return {"error": "No routes found between these locations"}
        
        # Score routes by length and safety
        scored_routes = []
        for route_type, route in routes:
            try:
                length_m = route_length_m(G, route)
                if length_m == 0:
                    continue
                    
                # Simple safety score (lower risk areas are better)
                safety_score = 0.0
                for node in route:
                    node_data = G.nodes.get(node, {})
                    node_lat = node_data.get('y', node_data.get('lat', from_lat))
                    node_lon = node_data.get('x', node_data.get('lon', from_lon))
                    
                    # Find nearest region for this node
                    distances = [haversine_m(node_lon, node_lat, rlon, rlat) 
                               for rlon, rlat in zip(region_lons, region_lats)]
                    nearest_region_idx = np.argmin(distances)
                    risk_level = region_risks[nearest_region_idx].lower()
                    
                    if risk_level == 'low':
                        safety_score += 1.0
                    elif risk_level == 'moderate':
                        safety_score += 0.5
                    # high risk gets 0.0
                
                # Combined score (lower is better)
                combined_score = length_m + (safety_weight * 1000.0 * (len(route) - safety_score))
                
                scored_routes.append({
                    "route": route,
                    "length_m": length_m,
                    "length_km": length_m / 1000.0,
                    "eta_minutes": (length_m / 1000.0) / ASSUMED_SPEED_KMPH * 60,
                    "safety_score": safety_score,
                    "combined_score": combined_score,
                    "type": route_type
                })
                
            except Exception as e:
                print(f"⚠️ Error scoring route: {e}")
                continue
        
        if not scored_routes:
            return {"error": "No valid routes found after scoring"}
        
        # Sort by combined score and take top k
        scored_routes.sort(key=lambda x: x["combined_score"])
        final_routes = scored_routes[:k]
        
        # Convert routes to coordinate lists
        result_routes = []
        for i, route_data in enumerate(final_routes):
            try:
                route_coords = []
                for node in route_data["route"]:
                    node_data = G.nodes.get(node, {})
                    lat = node_data.get('y', node_data.get('lat'))
                    lon = node_data.get('x', node_data.get('lon'))
                    if lat is not None and lon is not None:
                        route_coords.append([float(lat), float(lon)])
                
                if len(route_coords) >= 2:
                    result_routes.append({
                        "id": i + 1,
                        "coordinates": route_coords,
                        "length_km": round(route_data["length_km"], 2),
                        "eta_minutes": round(route_data["eta_minutes"], 1),
                        "safety_score": round(route_data["safety_score"], 1),
                        "type": route_data["type"]
                    })
            except Exception as e:
                print(f"⚠️ Error converting route {i}: {e}")
                continue
        
        if not result_routes:
            return {"error": "No valid coordinate routes generated"}
        
        return {
            "success": True,
            "from_area": from_match,
            "to_area": to_match,
            "routes_found": len(result_routes),
            "routes": result_routes
        }
        
    except Exception as e:
        print(f"❌ Error in get_k_nearest_low_risk_routes: {e}")
        return {"error": f"Route calculation failed: {str(e)}"}

# For backward compatibility
def get_evacuation_routes(from_area: str, to_area: str = "marine drive", num_routes: int = 5):
    """Backward compatibility wrapper"""
    return get_k_nearest_low_risk_routes(from_area, to_area, num_routes)