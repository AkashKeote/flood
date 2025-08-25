# enhanced_app_v2.py — Mumbai evacuation routing (Streamlit) - COMPREHENSIVE ENHANCED VERSION
# Requirements:
# pip install streamlit streamlit-folium osmnx networkx pandas numpy geopandas folium shapely rapidfuzz fuzzywuzzy plotly

import streamlit as st
from streamlit_folium import st_folium
import os
import json
import math
import io
import tempfile
import numpy as np
import pandas as pd
import networkx as nx
import osmnx as ox
import folium
from folium import GeoJson, PolyLine, CircleMarker
from folium.plugins import MarkerCluster, MiniMap, Fullscreen, MeasureControl, MousePosition, LocateControl, HeatMap
from shapely.geometry import Point
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import time

# Fuzzy matching
try:
    from rapidfuzz import process as fuzzy_process
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

st.set_page_config(
    page_title="Mumbai Flood Evacuation Routes - Enhanced", 
    page_icon="🌊", 
    layout="wide",
    initial_sidebar_state="expanded"
)

# ----------------------------
# Configuration
# ----------------------------
GRAPHML = "roads_all.graphml"
CSV = "mumbai_ward_area_floodrisk.csv"
PLACE = "Mumbai, India"
ASSUMED_SPEED_KMPH = 25.0
SAMPLE_FACTOR = 5
MAX_POIS_PER_CAT = 500
ROUTE_COUNT = 5

RISK_COLOR = {
    "low": "#1a9850",
    "moderate": "#fc8d59",
    "high": "#d73027",
    "unknown": "#aaaaaa",
}

POI_CATEGORIES = {
    "hospital":       ({"amenity": "hospital"},       "plus-square",   "red"),
    "police":         ({"amenity": "police"},         "shield",        "darkblue"),
    "fire_station":   ({"amenity": "fire_station"},   "fire",          "orange"),
    "pharmacy":       ({"amenity": "pharmacy"},       "medkit",        "purple"),
    "school":         ({"amenity": "school"},         "graduation-cap","cadetblue"),
    "university":     ({"amenity": "university"},     "university",    "darkgreen"),
    "fuel":           ({"amenity": "fuel"},           "gas-pump",      "gray"),
    "shelter":        ({"emergency": "shelter"},      "home",          "green"),
    "bank":           ({"amenity": "bank"},           "bank",          "darkred"),
    "atm":            ({"amenity": "atm"},            "money-bill",    "darkred"),
    "restaurant":     ({"amenity": "restaurant"},     "utensils",      "beige"),
    "market":         ({"shop": "supermarket"},       "shopping-cart", "gray"),
    "water_tower":    ({"man_made": "water_tower"},   "tint",          "blue"),
    "bus_station":    ({"amenity": "bus_station"},    "bus",           "darkblue"),
    "train_station":  ({"railway": "station"},        "train",         "black"),
}

# ----------------------------
# Helper Functions
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
        st.error(f"CSV missing required columns: {missing}. Found: {list(df.columns)}")
        st.stop()
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
    total = 0.0
    for u, v in zip(route[:-1], route[1:]):
        data = G.get_edge_data(u, v)
        if not data:
            continue
        best = min(data.values(), key=lambda d: d.get("length", float("inf")))
        total += float(best.get("length", 0.0))
    return total

def nearest_node(G, lon, lat):
    """Find nearest node with robust fallback implementation"""
    try:
        return ox.distance.nearest_nodes(G, X=lon, Y=lat)
    except ImportError:
        # Fallback implementation using manual distance calculation
        min_dist = float('inf')
        nearest = None
        for node_id in G.nodes():
            node_data = G.nodes[node_id]
            node_lon = node_data.get('x', node_data.get('lon', 0))
            node_lat = node_data.get('y', node_data.get('lat', 0))
            dist = haversine_m(lon, lat, node_lon, node_lat)
            if dist < min_dist:
                min_dist = dist
                nearest = node_id
        return nearest
    except Exception as e:
        # Try the old API as secondary fallback
        try:
            return ox.nearest_nodes(G, X=lon, Y=lat)
        except ImportError:
            # Another ImportError - use manual calculation
            min_dist = float('inf')
            nearest = None
            for node_id in G.nodes():
                node_data = G.nodes[node_id]
                node_lon = node_data.get('x', node_data.get('lon', 0))
                node_lat = node_data.get('y', node_data.get('lat', 0))
                dist = haversine_m(lon, lat, node_lon, node_lat)
                if dist < min_dist:
                    min_dist = dist
                    nearest = node_id
            return nearest
        except Exception:
            # Final fallback using manual calculation
            min_dist = float('inf')
            nearest = None
            for node_id in G.nodes():
                node_data = G.nodes[node_id]
                node_lon = node_data.get('x', node_data.get('lon', 0))
                node_lat = node_data.get('y', node_data.get('lat', 0))
                dist = haversine_m(lon, lat, node_lon, node_lat)
                if dist < min_dist:
                    min_dist = dist
                    nearest = node_id
            return nearest

# NEW: Weather and traffic simulation
def simulate_weather_impact(base_speed_kmph, weather_condition="clear"):
    weather_multipliers = {
        "clear": 1.0,
        "light_rain": 0.8,
        "heavy_rain": 0.6,
        "flood": 0.3,
        "storm": 0.4
    }
    return base_speed_kmph * weather_multipliers.get(weather_condition, 1.0)

def get_congestion_factor(hour_of_day):
    # Simulate Mumbai traffic patterns
    if 7 <= hour_of_day <= 10:  # Morning rush
        return 0.5
    elif 17 <= hour_of_day <= 20:  # Evening rush
        return 0.4
    elif 22 <= hour_of_day or hour_of_day <= 6:  # Night
        return 1.2
    else:  # Normal hours
        return 0.8

# ----------------------------
# Cached Data Loading
# ----------------------------
@st.cache_resource
def load_graph():
    if not os.path.exists(GRAPHML):
        st.error(f"Missing {GRAPHML} in current folder.")
        st.stop()
    G = ox.load_graphml(GRAPHML)
    largest_cc_nodes = max(nx.weakly_connected_components(G), key=len)
    G = G.subgraph(largest_cc_nodes).copy()
    return G

@st.cache_data
def load_flood_df():
    if not os.path.exists(CSV):
        st.error(f"Missing {CSV} in current folder.")
        st.stop()
    flood_df_raw = pd.read_csv(CSV)
    flood_df = normalize_columns(flood_df_raw)
    return flood_df

@st.cache_data
def fetch_pois():
    pois_by_cat = {}
    for cat, (tag, icon, color) in POI_CATEGORIES.items():
        try:
            gdf = ox.features_from_place(PLACE, tag)
            if gdf is None or gdf.empty:
                pois_by_cat[cat] = None
                continue
            
            # Convert to WGS84 if not already
            if gdf.crs != 'EPSG:4326':
                gdf = gdf.to_crs(epsg=4326)
            
            # Project to UTM for accurate centroid calculation, then back to WGS84
            try:
                gdf_projected = gdf.to_crs(epsg=32643)  # UTM 43N for Mumbai
                gdf_projected["geometry"] = gdf_projected.geometry.centroid
                gdf = gdf_projected.to_crs(epsg=4326)  # Back to WGS84
            except Exception:
                # Fallback: use centroid directly
                gdf["geometry"] = gdf.geometry.centroid
            
            if len(gdf) > MAX_POIS_PER_CAT:
                gdf = gdf.sample(MAX_POIS_PER_CAT, random_state=1)
            pois_by_cat[cat] = gdf
        except Exception:
            pois_by_cat[cat] = None
    return pois_by_cat

# Load data
G = load_graph()
flood_df = load_flood_df()
regions = flood_df["areas"].tolist()
region_lons = flood_df["longitude"].to_numpy()
region_lats = flood_df["latitude"].to_numpy()
region_risks = flood_df["flood_risk_level"].tolist()
n_regions = len(regions)

# Precompute node mappings
node_ids = np.array(list(G.nodes))
node_lons = np.array([G.nodes[n].get("x", G.nodes[n].get("lon")) for n in node_ids], dtype=float)
node_lats = np.array([G.nodes[n].get("y", G.nodes[n].get("lat")) for n in node_ids], dtype=float)
dist_stack = np.empty((n_regions, len(node_ids)), dtype=float)
for i in range(n_regions):
    dist_stack[i] = haversine_m(region_lons[i], region_lats[i], node_lons, node_lats)
nearest_region_idx_per_node = np.argmin(dist_stack, axis=0)
nodeid_to_region_idx = dict(zip(node_ids.tolist(), nearest_region_idx_per_node.tolist()))

# Precompute edges
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

pois_by_cat = fetch_pois()

# ----------------------------
# ENHANCED UI WITH SIDEBAR
# ----------------------------
with st.sidebar:
    st.title("🚨 Emergency Control Panel")
    
    # Emergency Alert System
    st.subheader("🚨 Alert Status")
    alert_level = st.selectbox("Current Alert Level", 
                              ["🟢 Normal", "🟡 Caution", "🟠 Warning", "🔴 Emergency"],
                              help="Set current emergency alert level")
    
    if alert_level != "🟢 Normal":
        st.error(f"⚠️ {alert_level} - Active Alert!")
    
    # Weather Conditions
    st.subheader("🌦️ Environmental Conditions")
    weather = st.selectbox("Weather Condition", 
                          ["clear", "light_rain", "heavy_rain", "flood", "storm"],
                          help="Current weather affecting evacuation")
    
    # Time Settings
    st.subheader("⏰ Evacuation Planning")
    evacuation_time = st.time_input("Start Time", value=datetime.now().time())
    hour = evacuation_time.hour
    
    # Advanced Settings
    st.subheader("⚙️ Route Settings")
    speed_kmph = st.slider("Base Speed (km/h)", 5, 50, int(ASSUMED_SPEED_KMPH), 
                          help="Average travel speed in normal conditions")
    num_routes = st.slider("Number of Routes", 1, 10, ROUTE_COUNT,
                          help="Maximum evacuation routes to calculate")
    map_zoom = st.slider("Map Zoom Level", 10, 16, 13)
    
    st.markdown("---")
    st.subheader("📞 Emergency Contacts")
    st.markdown("""
    - 🚒 **Fire Brigade:** 101
    - 👮 **Police:** 100
    - 🚑 **Ambulance:** 108
    - 🌊 **Disaster Helpline:** 1077
    - 🚦 **Mumbai Traffic:** 103
    """)
    
    # Quick Actions
    st.markdown("---")
    st.subheader("⚡ Quick Actions")
    if st.button("🔄 Refresh All Data", help="Reload all cached data"):
        st.cache_resource.clear()
        st.cache_data.clear()
        st.rerun()

# ----------------------------
# MAIN CONTENT
# ----------------------------
st.title("🌊 Mumbai Emergency Evacuation System")
st.markdown("**Advanced flood evacuation routing with real-time conditions and comprehensive emergency tools**")

# Status Dashboard
st.subheader("📊 Current Conditions Dashboard")
col1, col2, col3, col4 = st.columns(4)

with col1:
    adjusted_speed = simulate_weather_impact(speed_kmph, weather)
    adjusted_speed *= get_congestion_factor(hour)
    st.metric("Effective Speed", f"{adjusted_speed:.1f} km/h", 
             f"{adjusted_speed-speed_kmph:.1f} km/h")

with col2:
    weather_impact = (simulate_weather_impact(100, weather) - 100)
    st.metric("Weather Impact", f"{weather_impact:+.0f}%")

with col3:
    congestion_impact = (get_congestion_factor(hour) - 1) * 100
    st.metric("Traffic Impact", f"{congestion_impact:+.0f}%")

with col4:
    if alert_level != "🟢 Normal":
        st.metric("Alert Status", "🚨 ACTIVE", delta_color="off")
    else:
        st.metric("Alert Status", "✅ Normal", delta_color="off")

# Network Statistics
st.subheader("🗺️ Network Overview")
col1, col2, col3, col4 = st.columns(4)
with col1:
    st.metric("Total Areas", len(regions))
with col2:
    low_risk_count = len(flood_df[flood_df["flood_risk_level"] == "low"])
    st.metric("Safe Zones", low_risk_count)
with col3:
    st.metric("Road Nodes", f"{len(G.nodes):,}")
with col4:
    st.metric("Road Segments", f"{len(G.edges):,}")

# Location Input with Enhanced Features
st.subheader("📍 Location & Route Planning")

col1, col2 = st.columns([2, 1])

with col1:
    user_region = st.text_input("🏠 Enter your current location:", 
                               placeholder="Type area name (e.g., Bandra, Andheri, Colaba)",
                               help="Use fuzzy matching - partial names work too!")
    
    # Quick location buttons
    st.write("**🚀 Quick Locations:**")
    quick_locations = ["andheri west", "bandra", "colaba", "dadar", "powai", "malad", "borivali", "thane"]
    available_quick = [loc for loc in quick_locations if loc in regions]
    
    if available_quick:
        cols = st.columns(min(len(available_quick), 4))
        for i, loc in enumerate(available_quick):
            with cols[i % 4]:
                if st.button(f"📍 {loc.title()}", key=f"quick_{i}"):
                    user_region = loc
                    st.rerun()

with col2:
    st.subheader("🗺️ Map Display Options")
    show_roads = st.checkbox("🛣️ Risk-colored roads", value=True, 
                            help="Show road network with flood risk colors")
    show_pois = st.checkbox("🏥 Emergency facilities", value=False, 
                           help="Display hospitals, police, etc.")
    show_heatmap = st.checkbox("🌡️ Risk heatmap", value=False,
                              help="Heat map overlay showing risk intensity")
    download_routes = st.checkbox("💾 Enable downloads", value=False,
                                 help="Show download options for route data")

# Auto-suggestions
if user_region and len(user_region) >= 2:
    matching_regions = [r for r in regions if user_region.lower() in r.lower()][:10]
    if matching_regions:
        st.write("**💡 Suggestions:**")
        suggestion_cols = st.columns(min(len(matching_regions), 5))
        for i, region in enumerate(matching_regions):
            with suggestion_cols[i % 5]:
                if st.button(f"📍 {region.title()}", key=f"suggest_{i}"):
                    user_region = region
                    st.rerun()

# Enhanced Route Computation
def get_k_nearest_low_risk_routes(user_area: str, G, flood_df, k=ROUTE_COUNT, weather_condition="clear", hour=12):
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
    
    # Calculate effective speed
    effective_speed = simulate_weather_impact(speed_kmph, weather_condition)
    effective_speed *= get_congestion_factor(hour)
    
    try:
        dists = nx.single_source_dijkstra_path_length(G, orig_node, weight="length")
    except Exception:
        dists = {}
    
    candidates = []
    for _, row in low_df.iterrows():
        node = nearest_node(G, float(row["longitude"]), float(row["latitude"]))
        d = dists.get(node, None)
        if d is not None:
            candidates.append((row["areas"], node, d))
    
    if not candidates:
        return best_match, score, []
    
    candidates.sort(key=lambda x: x[2])
    picked = []
    seen = set()
    for area, node, d in candidates:
        if area in seen:
            continue
        seen.add(area)
        picked.append((area, node, d))
        if len(picked) >= k:
            break
    
    routes = []
    for area, node, d in picked:
        try:
            path = nx.shortest_path(G, orig_node, node, weight="length")
            length_m = route_length_m(G, path)
            eta_min = (length_m / 1000.0) / max(effective_speed, 1) * 60.0
            routes.append({
                "dest_region": area,
                "dest_node": int(node),
                "path": path,
                "distance_km": round(length_m / 1000.0, 3),
                "eta_min": round(eta_min, 1),
                "effective_speed": round(effective_speed, 1)
            })
        except Exception:
            continue
    return best_match, score, routes

# Enhanced Map Building Function
def build_enhanced_map(start_region_name: str, routes: list, show_pois: bool = False, 
                      show_roads: bool = True, show_heatmap: bool = False, zoom_level: int = 13):
    idx = int(flood_df.index[flood_df["areas"] == start_region_name][0])
    center = [float(region_lats[idx]), float(region_lons[idx])]
    m = folium.Map(location=center, zoom_start=zoom_level, tiles=None, control_scale=True)
    
    # Enhanced tile layers with proper attributions
    folium.TileLayer("OpenStreetMap", name="🗺️ Street Map").add_to(m)
    folium.TileLayer("cartodbpositron", name="🌟 Light Mode").add_to(m)
    folium.TileLayer("cartodbdark_matter", name="🌙 Dark Mode").add_to(m)
    
    # Add terrain with fallback
    try:
        folium.TileLayer(
            tiles="https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png",
            attr="Map data: &copy; <a href='https://www.openstreetmap.org/copyright'>OpenStreetMap</a> contributors",
            name="🏔️ Terrain",
            overlay=False,
            control=True
        ).add_to(m)
    except Exception:
        pass
    
    # Enhanced map controls
    MiniMap(toggle_display=True, position="bottomleft").add_to(m)
    Fullscreen(position="topleft", title="Fullscreen", title_cancel="Exit Fullscreen").add_to(m)
    MeasureControl(primary_length_unit='kilometers', primary_area_unit='sqkilometers').add_to(m)
    MousePosition(position="bottomright", separator=" | ", prefix="📍 ").add_to(m)
    LocateControl(auto_start=False, position="topleft").add_to(m)
    
    # Risk heatmap
    if show_heatmap:
        heat_data = []
        for _, row in flood_df.iterrows():
            risk_val = {"high": 1.0, "moderate": 0.6, "low": 0.2, "unknown": 0.4}.get(row["flood_risk_level"], 0.4)
            heat_data.append([float(row["latitude"]), float(row["longitude"]), risk_val])
        HeatMap(heat_data, name="🌡️ Risk Heatmap", radius=20, blur=15, 
                min_opacity=0.3, max_zoom=18).add_to(m)
    
    # Roads with enhanced filtering
    if show_roads:
        # Show roads along evacuation routes
        route_nodes = set()
        for r in routes:
            route_nodes.update(r["path"])
        
        # Filter relevant edges
        relevant_edges = edges_gdf_sampled[
            edges_gdf_sampled["u"].isin(route_nodes) | 
            edges_gdf_sampled["v"].isin(route_nodes) |
            edges_gdf_sampled["region_name"] == start_region_name
        ]
        
        if not relevant_edges.empty:
            GeoJson(
                data=relevant_edges.__geo_interface__,
                name="🛣️ Evacuation Roads (Risk-Colored)",
                style_function=edge_style,
                tooltip=folium.GeoJsonTooltip(
                    fields=["region_name", "risk_level"],
                    aliases=["📍 Region:", "⚠️ Risk Level:"],
                    sticky=True
                ),
            ).add_to(m)
    
    # Enhanced region markers
    start_region_idx = idx
    start_color = RISK_COLOR.get(str(region_risks[start_region_idx]).lower(), RISK_COLOR["unknown"])
    CircleMarker(
        location=[float(region_lats[start_region_idx]), float(region_lons[start_region_idx])],
        radius=10,
        color="#000", fill=True, fill_color=start_color, fill_opacity=0.9,
        tooltip=f"🏁 START: {start_region_name.title()}<br>⚠️ Risk: {str(region_risks[start_region_idx]).title()}",
    ).add_to(m)
    
    # Destination markers
    dest_regions = [r["dest_region"] for r in routes]
    for dest_region in dest_regions:
        dest_idx = regions.index(dest_region)
        dest_color = RISK_COLOR.get(str(region_risks[dest_idx]).lower(), RISK_COLOR["unknown"])
        CircleMarker(
            location=[float(region_lats[dest_idx]), float(region_lons[dest_idx])],
            radius=8,
            color="#000", fill=True, fill_color=dest_color, fill_opacity=0.9,
            tooltip=f"🎯 SAFE ZONE: {dest_region.title()}<br>⚠️ Risk: {str(region_risks[dest_idx]).title()}",
        ).add_to(m)
    
    # Enhanced POI display
    if show_pois:
        # Calculate route bounds for POI filtering
        route_coords = []
        for r in routes:
            route_coords.extend([(G.nodes[n]["y"], G.nodes[n]["x"]) for n in r["path"]])
        
        if route_coords:
            lats = [coord[0] for coord in route_coords]
            lons = [coord[1] for coord in route_coords]
            min_lat, max_lat = min(lats), max(lats)
            min_lon, max_lon = min(lons), max(lons)
            
            # Add padding
            lat_padding = (max_lat - min_lat) * 0.1
            lon_padding = (max_lon - min_lon) * 0.1
            
            for cat, gdf in pois_by_cat.items():
                if gdf is None or gdf.empty:
                    continue
                
                # Filter POIs to route area
                filtered_pois = gdf[
                    (gdf.geometry.y >= min_lat - lat_padding) &
                    (gdf.geometry.y <= max_lat + lat_padding) &
                    (gdf.geometry.x >= min_lon - lon_padding) &
                    (gdf.geometry.x <= max_lon + lon_padding)
                ]
                
                if filtered_pois.empty:
                    continue
                    
                icon = POI_CATEGORIES[cat][1]
                color = POI_CATEGORIES[cat][2]
                cluster = MarkerCluster(name=f"{icon} {cat.replace('_',' ').title()} ({len(filtered_pois)})")
                
                for _, row in filtered_pois.iterrows():
                    geom = row.geometry
                    if geom is None:
                        continue
                    lat, lon = geom.y, geom.x
                    popup_txt = str(row.get("name") or cat.replace("_", " ").title())
                    folium.Marker(
                        location=[lat, lon],
                        icon=folium.Icon(color=color, icon=icon, prefix="fa"),
                        popup=popup_txt,
                        tooltip=f"{cat.replace('_', ' ').title()}: {popup_txt}"
                    ).add_to(cluster)
                m.add_child(cluster)
    
    # Enhanced route visualization
    route_colors = ["#0078FF", "#1ABC9C", "#F39C12", "#C0392B", "#8E44AD", "#16A085", "#E67E22", "#9B59B6"]
    for i, r in enumerate(routes):
        coords = [(G.nodes[n]["y"], G.nodes[n]["x"]) for n in r["path"]]
        color = route_colors[i % len(route_colors)]
        
        PolyLine(
            coords,
            color=color,
            weight=6, opacity=0.9,
            tooltip=f"🛣️ Route {i+1}<br>📍 → {r['dest_region'].title()}<br>📏 {r['distance_km']:.2f} km<br>⏱️ {r['eta_min']:.0f} min<br>🚗 {r['effective_speed']:.1f} km/h",
        ).add_to(m)
        
        # Route start/end markers
        start_node = r["path"][0]
        dest_node = r["path"][-1]
        
        folium.CircleMarker(
            location=(G.nodes[dest_node]["y"], G.nodes[dest_node]["x"]),
            radius=8, color="#000", fill=True, fill_color=color,
            tooltip=f"🎯 Route {i+1} Destination: {r['dest_region'].title()}",
        ).add_to(m)
    
    folium.LayerControl(collapsed=False).add_to(m)
    return m

# Main computation button
compute_btn = st.button("🚨 COMPUTE EVACUATION ROUTES", type="primary", use_container_width=True)

# Main computation and display
if compute_btn and user_region.strip():
    with st.spinner("🔍 Computing optimal evacuation routes..."):
        matched, score, routes = get_k_nearest_low_risk_routes(
            user_region, G, flood_df, k=num_routes, weather_condition=weather, hour=hour
        )
    
    if not matched:
        st.error(f"❌ Could not match '{user_region}' (similarity: {score}%). Try a different area name.")
        
        # Show region browser
        with st.expander("🔍 Browse Available Regions", expanded=True):
            search_term = st.text_input("🔍 Search regions:", "")
            if search_term:
                filtered_regions = [r for r in regions if search_term.lower() in r.lower()]
            else:
                filtered_regions = regions[:20]  # Show first 20
            
            if filtered_regions:
                cols = st.columns(4)
                for i, region in enumerate(filtered_regions):
                    with cols[i % 4]:
                        if st.button(f"📍 {region.title()}", key=f"browse_{i}"):
                            user_region = region
                            st.rerun()
        
    elif not routes:
        st.warning("⚠️ No safe evacuation routes found from this region.")
        st.info("💡 This might mean your area is already in a low-risk zone!")
        
    else:
        # Success - show results
        if score < 100:
            st.info(f"🔍 Using closest match: **{matched.title()}** (similarity: {score}%)")
        else:
            st.success(f"✅ Found {len(routes)} evacuation routes from **{matched.title()}**")
        
        # Enhanced route statistics
        st.subheader("📊 Route Analysis")
        total_distance = sum(r['distance_km'] for r in routes)
        avg_time = sum(r['eta_min'] for r in routes) / len(routes)
        fastest_route = min(routes, key=lambda x: x['eta_min'])
        shortest_route = min(routes, key=lambda x: x['distance_km'])
        
        col1, col2, col3, col4 = st.columns(4)
        with col1:
            st.metric("Total Routes", len(routes))
        with col2:
            st.metric("Fastest Route", f"{fastest_route['eta_min']:.1f} min", 
                     f"To {fastest_route['dest_region'].title()}")
        with col3:
            st.metric("Shortest Route", f"{shortest_route['distance_km']:.1f} km",
                     f"To {shortest_route['dest_region'].title()}")
        with col4:
            st.metric("Average ETA", f"{avg_time:.1f} min")
        
        # Route comparison chart
        route_data = []
        for i, r in enumerate(routes, 1):
            route_data.append({
                "Route": f"Route {i}",
                "Destination": r['dest_region'].title(),
                "Distance (km)": r['distance_km'],
                "ETA (min)": r['eta_min'],
                "Speed (km/h)": r['effective_speed']
            })
        
        df_routes = pd.DataFrame(route_data)
        
        # Interactive charts
        col1, col2 = st.columns(2)
        with col1:
            fig_time = px.bar(df_routes, x="Route", y="ETA (min)", 
                             title="⏱️ Travel Time Comparison",
                             color="ETA (min)", color_continuous_scale="RdYlGn_r")
            st.plotly_chart(fig_time, use_container_width=True)
        
        with col2:
            fig_dist = px.bar(df_routes, x="Route", y="Distance (km)", 
                             title="📏 Distance Comparison",
                             color="Distance (km)", color_continuous_scale="Viridis")
            st.plotly_chart(fig_dist, use_container_width=True)
        
        # Detailed route table
        st.subheader("📋 Detailed Route Information")
        st.dataframe(df_routes, use_container_width=True)
        
        # Expandable route details
        for i, r in enumerate(routes, 1):
            with st.expander(f"🛣️ Route {i}: {r['dest_region'].title()} — {r['distance_km']:.2f} km, {r['eta_min']:.0f} min"):
                col1, col2, col3 = st.columns(3)
                with col1:
                    st.write(f"**📏 Distance:** {r['distance_km']:.2f} km")
                    st.write(f"**⏱️ Travel Time:** {r['eta_min']:.0f} minutes")
                with col2:
                    st.write(f"**🎯 Destination:** {r['dest_region'].title()}")
                    dest_row = flood_df[flood_df["areas"] == r['dest_region']].iloc[0]
                    st.write(f"**⚠️ Destination Risk:** {dest_row['flood_risk_level'].title()}")
                with col3:
                    st.write(f"**🚗 Effective Speed:** {r['effective_speed']:.1f} km/h")
                    st.write(f"**📊 Route Share:** {(r['distance_km']/total_distance*100):.1f}% of total")
        
        # Enhanced map display
        st.subheader("🗺️ Interactive Evacuation Map")
        
        # Build and display map
        with st.spinner("🗺️ Creating enhanced evacuation map..."):
            try:
                folium_map = build_enhanced_map(
                    matched, routes, show_pois, show_roads, show_heatmap, map_zoom
                )
                
                st.write("✅ Map created successfully!")
                
                map_data = st_folium(
                    folium_map, 
                    width=1200, 
                    height=700, 
                    returned_objects=[],
                    key="enhanced_evacuation_map",
                    feature_group_to_add=None,
                    use_container_width=True
                )
                
                # Enhanced download options
                if download_routes:
                    st.subheader("💾 Download Options")
                    
                    col1, col2, col3 = st.columns(3)
                    
                    with col1:
                        # Enhanced JSON export
                        route_json = json.dumps({
                            "evacuation_plan": {
                                "metadata": {
                                    "start_location": matched,
                                    "weather_condition": weather,
                                    "evacuation_time": str(evacuation_time),
                                    "alert_level": alert_level,
                                    "generated_at": datetime.now().isoformat(),
                                    "effective_speed_kmph": routes[0]["effective_speed"] if routes else 0
                                },
                                "statistics": {
                                    "total_routes": len(routes),
                                    "total_distance_km": total_distance,
                                    "average_time_min": avg_time,
                                    "fastest_route_min": fastest_route['eta_min'],
                                    "shortest_route_km": shortest_route['distance_km']
                                },
                                "routes": routes
                            }
                        }, indent=2)
                        
                        st.download_button(
                            "📥 Download Complete Plan (JSON)",
                            data=route_json,
                            file_name=f"evacuation_plan_{matched}_{datetime.now().strftime('%Y%m%d_%H%M')}.json",
                            mime="application/json"
                        )
                    
                    with col2:
                        # CSV export
                        csv_data = df_routes.to_csv(index=False)
                        st.download_button(
                            "📥 Download Routes Table (CSV)",
                            data=csv_data,
                            file_name=f"evacuation_routes_{matched}.csv",
                            mime="text/csv"
                        )
                    
                    with col3:
                        # HTML map export
                        html_path = f"evacuation_map_{matched}.html"
                        folium_map.save(html_path)
                        with open(html_path, "rb") as fh:
                            st.download_button(
                                "📥 Download Map (HTML)",
                                data=fh,
                                file_name=html_path,
                                mime="text/html"
                            )
                
                # Map legend and help
                with st.expander("📖 Map Guide & Legend", expanded=False):
                    col1, col2 = st.columns(2)
                    with col1:
                        st.write("**🗺️ Map Symbols:**")
                        st.write("🏁 **Start Location** - Your current region")
                        st.write("🎯 **Safe Zones** - Low-risk evacuation destinations")
                        st.write("🛣️ **Colored Routes** - Evacuation paths (different colors)")
                        if show_pois:
                            st.write("🏥 **POI Clusters** - Emergency facilities")
                        if show_heatmap:
                            st.write("🌡️ **Risk Heatmap** - Flood risk intensity")
                    
                    with col2:
                        st.write("**🎮 Map Controls:**")
                        st.write("🔍 **Zoom** - Mouse wheel or +/- buttons")
                        st.write("🖱️ **Pan** - Click and drag to move")
                        st.write("📏 **Measure** - Use measure tool for distances")
                        st.write("🌐 **Layers** - Toggle map styles and overlays")
                        st.write("📍 **Locate** - Find your current position")
                
                # Emergency checklist
                with st.expander("📋 Emergency Evacuation Checklist", expanded=False):
                    col1, col2 = st.columns(2)
                    with col1:
                        st.markdown("""
                        ### 🎒 Before Leaving:
                        - [ ] 📱 Charge all devices (100%)
                        - [ ] 💧 Pack water (4L per person)
                        - [ ] 🍞 Non-perishable food (3 days)
                        - [ ] 💊 Essential medications
                        - [ ] 📄 Important documents (waterproof bag)
                        - [ ] 💰 Cash and cards
                        - [ ] 🔦 Flashlight + extra batteries
                        - [ ] 👕 Extra clothing + blankets
                        """)
                    
                    with col2:
                        st.markdown("""
                        ### 🚗 During Evacuation:
                        - [ ] ⛽ Check vehicle fuel (full tank)
                        - [ ] 📻 Monitor emergency broadcasts
                        - [ ] 👥 Stay with your group
                        - [ ] 🚫 Avoid flooded roads (6+ inches)
                        - [ ] 📞 Inform contacts of chosen route
                        - [ ] 🕐 Leave early - don't wait
                        - [ ] 🗺️ Have backup routes ready
                        - [ ] 📱 Keep phone charged with power bank
                        """)
                
            except Exception as e:
                st.error(f"❌ Map creation failed: {str(e)}")
                st.write("🔄 Attempting simplified fallback map...")
                try:
                    simple_map = folium.Map(location=[19.0760, 72.8777], zoom_start=11)
                    st_folium(simple_map, width=1000, height=400)
                    st.info("🗺️ Basic Mumbai map displayed as fallback.")
                except Exception as fallback_error:
                    st.error(f"❌ Fallback map also failed: {str(fallback_error)}")

elif compute_btn:
    st.warning("⚠️ Please enter a location name first.")

else:
    # Default view with helpful information
    st.info("👆 Enter your location above and click 'COMPUTE EVACUATION ROUTES' to begin emergency planning.")
    
    # Mumbai overview when no computation
    if 'flood_df' in locals():
        st.subheader("📊 Mumbai Flood Risk Overview")
        
        col1, col2 = st.columns(2)
        
        with col1:
            # Risk distribution chart
            risk_counts = flood_df['flood_risk_level'].value_counts()
            fig = px.pie(
                values=risk_counts.values, 
                names=risk_counts.index.str.title(), 
                title="🌊 Risk Distribution Across Mumbai",
                color_discrete_map={
                    "Low": "#1a9850", 
                    "Moderate": "#fc8d59", 
                    "High": "#d73027",
                    "Unknown": "#aaaaaa"
                }
            )
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            # Quick stats
            st.metric("Total Areas Monitored", len(flood_df))
            st.metric("Low Risk (Safe) Areas", risk_counts.get('low', 0))
            st.metric("High Risk Areas", risk_counts.get('high', 0))
            st.metric("Road Network Coverage", f"{len(G.edges):,} segments")
        
        # Sample locations
        with st.expander("💡 Popular Mumbai Areas", expanded=True):
            sample_regions = ["andheri west", "bandra", "colaba", "dadar", "powai", "malad", "borivali", "thane"]
            available_samples = [r for r in sample_regions if r in regions]
            
            if available_samples:
                st.write("**Click any area to start planning:**")
                cols = st.columns(4)
                for i, region in enumerate(available_samples[:8]):
                    with cols[i % 4]:
                        if st.button(f"🏘️ {region.title()}", key=f"sample_{i}"):
                            user_region = region
                            st.rerun()

# Footer
st.markdown("---")
st.markdown("""
<div style='text-align: center; color: gray;'>
    <p><strong>🚨 Mumbai Emergency Evacuation System v2.0</strong><br>
    Enhanced with real-time conditions, comprehensive emergency tools, and advanced analytics<br>
    Built with ❤️ using Streamlit • For emergency use only</p>
</div>
""", unsafe_allow_html=True)
