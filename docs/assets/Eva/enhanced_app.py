# app.py — Mumbai evacuation routing (Streamlit) - ENHANCED VERSION
# Requirements:
# pip install streamlit streamlit-folium osmnx networkx pandas numpy geopandas folium shapely rapidfuzz fuzzywuzzy plotly

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
import streamlit as st
from streamlit_folium import st_folium
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import time

# Fuzzy matching (rapidfuzz preferred; fallback to fuzzywuzzy or difflib)
try:
    from rapidfuzz import process as fuzzy_process
except Exception:
    try:
        from fuzzywuzzy import process as fuzzy_process
    except Exception:
        import difflib
        class _DLProc:
            @staticmethod
            def extractOne(q, choices):
                matches = difflib.get_close_matches(q, choices, n=1, cutoff=0)
                if matches:
                    score = int(difflib.SequenceMatcher(None, q, matches[0]).ratio() * 100)
                    return matches[0], score
                return None, 0
        fuzzy_process = _DLProc()

st.set_page_config(
    page_title="Mumbai Evacuation Routing - Enhanced", 
    layout="wide",
    page_icon="🚨",
    initial_sidebar_state="expanded"
)

# ----------------------------
# Config / Filenames
# ----------------------------
GRAPHML = "roads_all.graphml"   # pre-saved graph (faster than downloading)
CSV = "mumbai_ward_area_floodrisk.csv"
OUT_HTML = "mumbai_evacuation_routes.html"

ASSUMED_SPEED_KMPH = 25.0   # evacuation average speed for ETA
SAMPLE_FACTOR = 5           # sample edges 1/SAMPLE_FACTOR for lighter map
MAX_POIS_PER_CAT = 400      # cap POIs per category

# POI categories (tag dict, icon, color)
POI_CATEGORIES = {
    "hospital": ({"amenity":"hospital"}, "plus-square", "red"),
    "police": ({"amenity":"police"}, "shield", "darkblue"),
    "fire_station": ({"amenity":"fire_station"}, "fire", "orange"),
    "pharmacy": ({"amenity":"pharmacy"}, "medkit", "purple"),
    "school": ({"amenity":"school"}, "graduation-cap", "cadetblue"),
    "university": ({"amenity":"university"}, "university", "darkgreen"),
    "fuel": ({"amenity":"fuel"}, "gas-pump", "lightgray"),
    "shelter": ({"emergency":"shelter"}, "home", "green"),
    "bus": ({"amenity":"bus_station"}, "bus", "darkblue"),
    "train": ({"railway":"station"}, "train", "black"),
    "market": ({"shop":"supermarket"}, "shopping-cart", "brown"),
}

RISK_COLOR = {"low":"#1a9850","moderate":"#fc8d59","high":"#d73027","unknown":"#9e9e9e"}

# ----------------------------
# Helper Functions
# ----------------------------
def extract_best_match(q, choices):
    try:
        res = fuzzy_process.extractOne(q, choices)
        if res is None:
            return None, 0
        if isinstance(res, (tuple, list)):
            return res[0], int(res[1])
        return res, 100
    except Exception:
        return None, 0

def haversine_m(lon1, lat1, lon2, lat2):
    R = 6371000.0
    lon1 = np.radians(lon1); lat1 = np.radians(lat1)
    lon2 = np.radians(lon2); lat2 = np.radians(lat2)
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = np.sin(dlat/2.0)**2 + np.cos(lat1)*np.cos(lat2)*np.sin(dlon/2.0)**2
    c = 2*np.arctan2(np.sqrt(a), np.sqrt(1-a))
    return R*c

def route_length_m(G, path):
    total = 0.0
    for u,v in zip(path[:-1], path[1:]):
        ed = G.get_edge_data(u,v)
        if not ed:
            continue
        best = min(ed.values(), key=lambda d: d.get("length", float("inf")))
        total += float(best.get("length",0.0))
    return total

def nearest_node(G, lon, lat):
    try:
        return ox.distance.nearest_nodes(G, X=lon, Y=lat)
    except Exception:
        return ox.nearest_nodes(G, X=lon, Y=lat)

# NEW: Weather simulation for enhanced planning
def simulate_weather_impact(base_speed_kmph, weather_condition="clear"):
    weather_multipliers = {
        "clear": 1.0,
        "light_rain": 0.8,
        "heavy_rain": 0.6,
        "flood": 0.3,
        "storm": 0.4
    }
    return base_speed_kmph * weather_multipliers.get(weather_condition, 1.0)

# NEW: Time-based congestion simulation
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
def load_graph_and_data(graphml_path: str, csv_path: str):
    if not os.path.exists(graphml_path):
        raise FileNotFoundError(f"{graphml_path} not found.")
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"{csv_path} not found.")
    G = ox.load_graphml(graphml_path)

    try:
        largest = max(nx.weakly_connected_components(G), key=len)
        G = G.subgraph(largest).copy()
    except Exception:
        pass

    df = pd.read_csv(csv_path)
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_")
    if "areas" not in df.columns and "area" in df.columns:
        df.rename(columns={"area":"areas"}, inplace=True)
    df = df.rename(columns={
        "flood-risk_level":"flood_risk_level",
        "flood_risk_level":"flood_risk_level"
    })
    if "flood_risk_level" not in df.columns and "risk" in df.columns:
        df["flood_risk_level"] = df["risk"]
    df["areas"] = df["areas"].astype(str).str.strip().str.lower()
    df["flood_risk_level"] = df["flood_risk_level"].astype(str).str.strip().str.lower()
    df["latitude"] = df["latitude"].astype(float)
    df["longitude"] = df["longitude"].astype(float)

    node_ids = np.array(list(G.nodes))
    node_x = np.array([G.nodes[n].get("x", G.nodes[n].get("lon")) for n in node_ids], dtype=float)
    node_y = np.array([G.nodes[n].get("y", G.nodes[n].get("lat")) for n in node_ids], dtype=float)
    region_lons = df["longitude"].to_numpy()
    region_lats = df["latitude"].to_numpy()
    n_regions = len(df)
    dist_stack = np.empty((n_regions, len(node_ids)), dtype=float)
    for i in range(n_regions):
        dist_stack[i] = haversine_m(region_lons[i], region_lats[i], node_x, node_y)
    nearest_region_idx_per_node = np.argmin(dist_stack, axis=0)
    node_to_region_idx = dict(zip(node_ids.tolist(), nearest_region_idx_per_node.tolist()))

    edges_gdf = ox.graph_to_gdfs(G, nodes=False, edges=True, fill_edge_geometry=True).reset_index()
    if "u" not in edges_gdf.columns:
        edges_gdf = edges_gdf.reset_index()
    edges_gdf["_u"] = edges_gdf["u"].astype(int)
    edges_gdf["region_idx"] = edges_gdf["_u"].map(node_to_region_idx)
    def idx_to_risk(i):
        try:
            return df.iloc[int(i)]["flood_risk_level"]
        except Exception:
            return "unknown"
    edges_gdf["risk_level"] = edges_gdf["region_idx"].apply(idx_to_risk)
    edges_sampled = edges_gdf.iloc[::SAMPLE_FACTOR].copy()

    return G, df, edges_sampled

@st.cache_data
def fetch_pois(place="Mumbai, India", categories=POI_CATEGORIES, cap=MAX_POIS_PER_CAT):
    pois = {}
    for cat, (tagdict, icon, color) in categories.items():
        try:
            g = ox.features_from_place(place, tagdict)
            if g is None or g.empty:
                pois[cat] = None
                continue
            g = g.to_crs(epsg=4326)
            g["geometry"] = g.geometry.centroid
            if len(g) > cap:
                g = g.sample(cap, random_state=1)
            pois[cat] = g
        except Exception:
            pois[cat] = None
    return pois

# ----------------------------
# ENHANCED UI WITH SIDEBAR
# ----------------------------
with st.sidebar:
    st.title("🚨 Control Panel")
    
    # Emergency Alert System
    st.subheader("🚨 Emergency Alert")
    alert_level = st.selectbox("Alert Level", ["None", "Yellow - Caution", "Orange - Warning", "Red - Emergency"])
    
    if alert_level != "None":
        alert_colors = {"Yellow - Caution": "warning", "Orange - Warning": "error", "Red - Emergency": "error"}
        st.error(f"⚠️ {alert_level} Alert Active!")
    
    # Weather Conditions
    st.subheader("🌦️ Weather Conditions")
    weather = st.selectbox("Current Weather", ["clear", "light_rain", "heavy_rain", "flood", "storm"])
    
    # Time Settings
    st.subheader("⏰ Time Settings")
    evacuation_time = st.time_input("Evacuation Start Time", value=datetime.now().time())
    hour = evacuation_time.hour
    
    # Advanced Settings
    st.subheader("⚙️ Advanced Settings")
    speed_kmph = st.slider("Base Speed (km/h)", 10, 50, int(ASSUMED_SPEED_KMPH))
    top_k = st.slider("Number of Routes", 1, 8, 5)
    
    # Population density consideration
    consider_population = st.checkbox("Consider Population Density", value=False)
    
    st.markdown("---")
    st.subheader("📞 Emergency Contacts")
    st.markdown("""
    - 🚒 Fire: **101**
    - 👮 Police: **100** 
    - 🚑 Ambulance: **108**
    - 🌊 Disaster: **1077**
    """)

# ----------------------------
# MAIN CONTENT
# ----------------------------
st.title("🌊 Mumbai Evacuation Routing System - Enhanced")
st.markdown("**Advanced flood evacuation planning with real-time conditions**")

# Status indicators
col1, col2, col3, col4 = st.columns(4)
with col1:
    adjusted_speed = simulate_weather_impact(speed_kmph, weather)
    adjusted_speed *= get_congestion_factor(hour)
    st.metric("Effective Speed", f"{adjusted_speed:.1f} km/h", f"{adjusted_speed-speed_kmph:.1f}")

with col2:
    weather_impact = (simulate_weather_impact(100, weather) - 100)
    st.metric("Weather Impact", f"{weather_impact:+.0f}%")

with col3:
    congestion_impact = (get_congestion_factor(hour) - 1) * 100
    st.metric("Traffic Impact", f"{congestion_impact:+.0f}%")

with col4:
    if alert_level != "None":
        st.metric("Alert Status", "🚨 ACTIVE", delta_color="off")
    else:
        st.metric("Alert Status", "✅ Normal", delta_color="off")

# Loading data
with st.spinner("Loading evacuation network..."):
    try:
        G, flood_df, edges_sampled = load_graph_and_data(GRAPHML, CSV)
    except Exception as e:
        st.error(f"Loading error: {e}")
        st.stop()

with st.spinner("Loading emergency facilities..."):
    pois_by_cat = fetch_pois()

# Main input area
st.subheader("📍 Location Input")
col1, col2 = st.columns([2, 1])

with col1:
    user_region = st.text_input("Enter your current location:", placeholder="e.g., Bandra, Andheri, Colaba")
    
    # NEW: Quick location buttons
    st.write("**Quick Locations:**")
    quick_locations = ["bandra", "andheri", "colaba", "dadar", "powai", "malad"]
    cols = st.columns(len(quick_locations))
    for i, loc in enumerate(quick_locations):
        with cols[i]:
            if st.button(f"📍 {loc.title()}", key=f"quick_{i}"):
                user_region = loc
                st.rerun()

with col2:
    st.subheader("Map Options")
    show_roads = st.checkbox("Risk-colored roads", value=True)
    show_pois = st.checkbox("Emergency facilities", value=True)
    show_heatmap = st.checkbox("Risk heatmap", value=False)
    show_population = st.checkbox("Population density", value=False) if consider_population else False

compute_btn = st.button("🚨 COMPUTE EVACUATION ROUTES", type="primary", use_container_width=True)

# Route computation function with enhancements
def get_k_nearest_low_risk_routes(user_area: str, G, flood_df, k=5, weather_condition="clear", hour=12):
    all_areas = flood_df["areas"].unique().tolist()
    match, score = extract_best_match(user_area.strip().lower(), all_areas)
    if not match or score < 40:
        return None, score, []
    
    start_row = flood_df[flood_df["areas"] == match].iloc[0]
    start_node = nearest_node(G, float(start_row["longitude"]), float(start_row["latitude"]))

    low_df = flood_df[flood_df["flood_risk_level"] == "low"]
    if low_df.empty:
        return match, score, []

    # Enhanced routing with weather and traffic considerations
    effective_speed = simulate_weather_impact(speed_kmph, weather_condition)
    effective_speed *= get_congestion_factor(hour)

    try:
        dists = nx.single_source_dijkstra_path_length(G, start_node, weight="length")
    except Exception:
        dists = {}

    candidates = []
    for _, r in low_df.iterrows():
        node = nearest_node(G, float(r["longitude"]), float(r["latitude"]))
        d = dists.get(node, None)
        if d is not None:
            candidates.append((r["areas"], int(node), d))
    if not candidates:
        return match, score, []

    candidates.sort(key=lambda x: x[2])
    selected = []
    seen = set()
    for area, node, d in candidates:
        if area in seen:
            continue
        selected.append((area, node, d))
        seen.add(area)
        if len(selected) >= k:
            break

    routes = []
    for area, node, d in selected:
        try:
            path = nx.shortest_path(G, start_node, node, weight="length")
            lm = route_length_m(G, path)
            eta_min = (lm/1000.0)/max(effective_speed,1)*60.0
            routes.append({
                "dest_region": area,
                "dest_node": int(node),
                "path": path,
                "distance_km": round(lm/1000.0, 3),
                "eta_min": round(eta_min,1),
                "effective_speed": round(effective_speed, 1)
            })
        except Exception:
            continue
    return match, score, routes

# Main computation and visualization
if compute_btn and user_region.strip():
    with st.spinner("Computing optimal evacuation routes..."):
        matched, score, routes = get_k_nearest_low_risk_routes(
            user_region, G, flood_df, k=top_k, weather_condition=weather, hour=hour
        )
    
    if not matched:
        st.error(f"❌ Could not match '{user_region}' (score {score}). Try a different name.")
    elif not routes:
        st.warning("⚠️ No reachable low-risk destinations found.")
    else:
        st.success(f"✅ Using region: **{matched.title()}** (match score {score}%)")
        
        # Enhanced route display with statistics
        st.subheader("🛣️ Evacuation Routes")
        
        # Route statistics
        total_distance = sum(r['distance_km'] for r in routes)
        avg_time = sum(r['eta_min'] for r in routes) / len(routes)
        fastest_route = min(routes, key=lambda x: x['eta_min'])
        
        col1, col2, col3, col4 = st.columns(4)
        with col1:
            st.metric("Total Routes", len(routes))
        with col2:
            st.metric("Fastest Route", f"{fastest_route['eta_min']:.1f} min")
        with col3:
            st.metric("Average Time", f"{avg_time:.1f} min")
        with col4:
            st.metric("Total Distance", f"{total_distance:.1f} km")
        
        # Route details table
        route_data = []
        for i, r in enumerate(routes, 1):
            route_data.append({
                "Route": f"Route {i}",
                "Destination": r['dest_region'].title(),
                "Distance (km)": f"{r['distance_km']:.2f}",
                "ETA (min)": f"{r['eta_min']:.1f}",
                "Speed (km/h)": f"{r['effective_speed']:.1f}"
            })
        
        df_routes = pd.DataFrame(route_data)
        st.dataframe(df_routes, use_container_width=True)
        
        # NEW: Route comparison chart
        fig = px.bar(df_routes, x="Route", y="ETA (min)", 
                     title="Route Comparison - Estimated Travel Time",
                     color="ETA (min)", color_continuous_scale="RdYlGn_r")
        st.plotly_chart(fig, use_container_width=True)
        
        # Map creation with enhancements
        start_idx = int(flood_df[flood_df["areas"]==matched].index[0])
        center = [float(flood_df.loc[start_idx,"latitude"]), float(flood_df.loc[start_idx,"longitude"])]
        m = folium.Map(location=center, zoom_start=12, tiles=None, control_scale=True)

        # Enhanced tile layers with proper attributions
        folium.TileLayer("OpenStreetMap", name="🗺️ Street Map").add_to(m)
        folium.TileLayer("cartodbpositron", name="🌟 Light Mode").add_to(m)
        folium.TileLayer("cartodbdark_matter", name="🌙 Dark Mode").add_to(m)
        
        # Add terrain with proper attribution
        try:
            folium.TileLayer(
                tiles="https://stamen-tiles-{s}.a.ssl.fastly.net/terrain/{z}/{x}/{y}.png",
                attr="Map tiles by Stamen Design, under CC BY 3.0. Data by OpenStreetMap, under ODbL.",
                name="🏔️ Terrain",
                overlay=False,
                control=True
            ).add_to(m)
        except Exception:
            # Fallback to OpenTopoMap if Stamen fails
            folium.TileLayer(
                tiles="https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png",
                attr="Map data: &copy; <a href='https://www.openstreetmap.org/copyright'>OpenStreetMap</a> contributors, <a href='http://viewfinderpanoramas.org'>SRTM</a> | Map style: &copy; <a href='https://opentopomap.org'>OpenTopoMap</a> (<a href='https://creativecommons.org/licenses/by-sa/3.0/'>CC-BY-SA</a>)",
                name="🏔️ Terrain",
                overlay=False,
                control=True
            ).add_to(m)
        
        # Add satellite imagery
        try:
            folium.TileLayer(
                tiles="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
                attr="Tiles &copy; Esri &mdash; Source: Esri, i-cubed, USDA, USGS, AEX, GeoEye, Getmapping, Aerogrid, IGN, IGP, UPR-EGP, and the GIS User Community",
                name="🛰️ Satellite",
                overlay=False,
                control=True
            ).add_to(m)
        except Exception:
            pass  # Skip satellite if not available
        
        # Enhanced map plugins
        MiniMap(toggle_display=True).add_to(m)
        Fullscreen().add_to(m)
        MeasureControl(primary_length_unit="kilometers").add_to(m)
        MousePosition(position="bottomright", prefix="📍 ").add_to(m)
        LocateControl(auto_start=False).add_to(m)

        # Risk heatmap
        if show_heatmap:
            heat_data = []
            for _, row in flood_df.iterrows():
                risk_val = {"high": 1.0, "moderate": 0.6, "low": 0.2, "unknown": 0.4}.get(row["flood_risk_level"], 0.4)
                heat_data.append([float(row["latitude"]), float(row["longitude"]), risk_val])
            HeatMap(heat_data, name="🌡️ Risk Heatmap", radius=20, blur=15).add_to(m)

        # Roads with enhanced styling
        if show_roads:
            gj = GeoJson(data=edges_sampled.__geo_interface__,
                         name="🛣️ Roads (risk-colored)",
                         style_function=lambda f: {
                             "color": RISK_COLOR.get(str(f["properties"].get("risk_level","unknown")).lower(), "#9e9e9e"),
                             "weight": 2.0, "opacity": 0.8
                         },
                         tooltip=folium.GeoJsonTooltip(
                             fields=["risk_level"],
                             aliases=["Risk Level:"],
                             sticky=True
                         ))
            gj.add_to(m)

        # Enhanced region markers
        rc = MarkerCluster(name=f"📍 Regions ({len(flood_df)})")
        for _, row in flood_df.iterrows():
            color = RISK_COLOR.get(str(row["flood_risk_level"]).lower(), "#9e9e9e")
            CircleMarker(location=[float(row["latitude"]), float(row["longitude"])],
                         radius=6, color=color, fill=True, fill_opacity=0.9,
                         tooltip=f"🏘️ {row['areas'].title()}<br>Risk: {row['flood_risk_level'].title()}").add_to(rc)
        m.add_child(rc)

        # Enhanced POI display
        if show_pois:
            for cat, gdf in pois_by_cat.items():
                if gdf is None or gdf.empty:
                    continue
                cluster = MarkerCluster(name=f"{POI_CATEGORIES[cat][1]} {cat.replace('_',' ').title()} ({len(gdf)})")
                for _, r in gdf.iterrows():
                    try:
                        lat = float(r.geometry.y); lon = float(r.geometry.x)
                    except Exception:
                        continue
                    popup = str(r.get("name") or cat.replace("_"," ").title())
                    folium.Marker(location=[lat,lon],
                                  icon=folium.Icon(color=POI_CATEGORIES[cat][2], 
                                                 icon=POI_CATEGORIES[cat][1], 
                                                 prefix="fa"),
                                  popup=popup).add_to(cluster)
                m.add_child(cluster)

        # Enhanced route visualization
        colors = ["#0066ff","#00cc44","#ff8800","#aa00ff","#0099cc","#ff0066","#00ffaa","#ffaa00"]
        for i, r in enumerate(routes):
            coords = [(G.nodes[n]["y"], G.nodes[n]["x"]) for n in r["path"]]
            PolyLine(coords, color=colors[i % len(colors)], weight=6, opacity=0.9,
                     tooltip=f"🛣️ Route {i+1}<br>📍 → {r['dest_region'].title()}<br>📏 {r['distance_km']:.2f} km<br>⏱️ {r['eta_min']:.0f} min<br>🚗 {r['effective_speed']:.1f} km/h").add_to(m)

            # Start marker (only for first route)
            if i == 0:
                s = r["path"][0]
                folium.CircleMarker(location=(G.nodes[s]["y"], G.nodes[s]["x"]),
                                    radius=10, color="#000", fill=True, fill_color="#ffffff",
                                    tooltip=f"🏁 START: {matched.title()}").add_to(m)

            # Destination markers
            dnode = r["path"][-1]
            folium.CircleMarker(location=(G.nodes[dnode]["y"], G.nodes[dnode]["x"]),
                                radius=8, color="#000", fill=True, fill_color=colors[i % len(colors)],
                                tooltip=f"🎯 DESTINATION {i+1}: {r['dest_region'].title()}").add_to(m)

        folium.LayerControl(collapsed=False).add_to(m)

        # Display map
        st.subheader("🗺️ Interactive Evacuation Map")
        try:
            st_map = st_folium(m, width=1200, height=700, returned_objects=[])
        except TypeError:
            st_map = st_folium(m, width=1200, height=700)

        # Enhanced download options
        col1, col2, col3 = st.columns(3)
        
        with col1:
            html_path = OUT_HTML
            m.save(html_path)
            with open(html_path, "rb") as fh:
                st.download_button("📥 Download Map (HTML)", data=fh, file_name=html_path, mime="text/html")
        
        with col2:
            # Download route data as JSON
            route_json = json.dumps({
                "evacuation_plan": {
                    "start_location": matched,
                    "weather_condition": weather,
                    "evacuation_time": str(evacuation_time),
                    "effective_speed_kmph": routes[0]["effective_speed"] if routes else 0,
                    "routes": routes,
                    "generated_at": datetime.now().isoformat()
                }
            }, indent=2)
            st.download_button("📥 Download Routes (JSON)", data=route_json, 
                             file_name=f"evacuation_plan_{matched}_{datetime.now().strftime('%Y%m%d_%H%M')}.json", 
                             mime="application/json")
        
        with col3:
            # Download as CSV
            csv_data = df_routes.to_csv(index=False)
            st.download_button("📥 Download Routes (CSV)", data=csv_data,
                             file_name=f"evacuation_routes_{matched}.csv", mime="text/csv")

        # NEW: Emergency checklist
        with st.expander("📋 Emergency Evacuation Checklist", expanded=False):
            st.markdown("""
            ### Before Leaving:
            - [ ] 📱 Charge all mobile devices
            - [ ] 💧 Pack emergency water (1 gallon per person)
            - [ ] 🍞 Pack non-perishable food
            - [ ] 💊 Take essential medications
            - [ ] 📄 Grab important documents
            - [ ] 💰 Bring cash and cards
            - [ ] 🔦 Pack flashlight and batteries
            - [ ] 👕 Pack extra clothing
            
            ### During Evacuation:
            - [ ] 🚗 Check vehicle fuel level
            - [ ] 📻 Monitor emergency radio
            - [ ] 👥 Stay with your group
            - [ ] 🚫 Avoid flooded roads
            - [ ] 📞 Inform relatives of your route
            """)

elif compute_btn:
    st.warning("⚠️ Please enter a location name first.")

else:
    # Show help and sample data when no computation is done
    st.info("👆 Enter your location above and click 'COMPUTE EVACUATION ROUTES' to get started.")
    
    # Show sample statistics
    if 'flood_df' in locals():
        st.subheader("📊 Mumbai Flood Risk Overview")
        risk_counts = flood_df['flood_risk_level'].value_counts()
        
        fig = px.pie(values=risk_counts.values, names=risk_counts.index, 
                     title="Risk Distribution Across Mumbai Areas",
                     color_discrete_map={"low": "#1a9850", "moderate": "#fc8d59", "high": "#d73027"})
        st.plotly_chart(fig, use_container_width=True)
        
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("Total Areas", len(flood_df))
        with col2:
            st.metric("Low Risk Areas", risk_counts.get('low', 0))
        with col3:
            st.metric("High Risk Areas", risk_counts.get('high', 0))

# Footer
st.markdown("---")
st.markdown("**🚨 Mumbai Emergency Evacuation System** - Enhanced with real-time conditions • Built with Streamlit")
