import streamlit as st
from streamlit_folium import st_folium
import os
import numpy as np
import pandas as pd
import networkx as nx
import osmnx as ox
import folium
from folium import GeoJson, PolyLine, CircleMarker
from folium.plugins import MarkerCluster, MiniMap, Fullscreen, MeasureControl, MousePosition, LocateControl
from shapely.geometry import Point

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
        # This handles the case where scikit-learn is not available
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

# Load data
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

G = load_graph()
flood_df = load_flood_df()
regions = flood_df["areas"].tolist()
region_lons = flood_df["longitude"].to_numpy()
region_lats = flood_df["latitude"].to_numpy()
region_risks = flood_df["flood_risk_level"].tolist()
n_regions = len(regions)

node_ids = np.array(list(G.nodes))
node_lons = np.array([G.nodes[n].get("x", G.nodes[n].get("lon")) for n in node_ids], dtype=float)
node_lats = np.array([G.nodes[n].get("y", G.nodes[n].get("lat")) for n in node_ids], dtype=float)
dist_stack = np.empty((n_regions, len(node_ids)), dtype=float)
for i in range(n_regions):
    dist_stack[i] = haversine_m(region_lons[i], region_lats[i], node_lons, node_lats)
nearest_region_idx_per_node = np.argmin(dist_stack, axis=0)
nodeid_to_region_idx = dict(zip(node_ids.tolist(), nearest_region_idx_per_node.tolist()))

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
            # Mumbai is approximately in UTM zone 43N
            try:
                gdf_projected = gdf.to_crs(epsg=32643)  # UTM 43N
                gdf_projected["geometry"] = gdf_projected.geometry.centroid
                gdf = gdf_projected.to_crs(epsg=4326)  # Back to WGS84
            except Exception:
                # Fallback: use centroid directly (with warning)
                gdf["geometry"] = gdf.geometry.centroid
            
            if len(gdf) > MAX_POIS_PER_CAT:
                gdf = gdf.sample(MAX_POIS_PER_CAT, random_state=1)
            pois_by_cat[cat] = gdf
        except Exception:
            pois_by_cat[cat] = None
    return pois_by_cat

pois_by_cat = fetch_pois()

# Route finder

def get_k_nearest_low_risk_routes(user_area: str, G, flood_df, k=ROUTE_COUNT):
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
            eta_min = (length_m / 1000.0) / max(ASSUMED_SPEED_KMPH, 1) * 60.0
            routes.append({
                "dest_region": area,
                "dest_node": int(node),
                "path": path,
                "distance_km": round(length_m / 1000.0, 3),
                "eta_min": round(eta_min, 1)
            })
        except Exception:
            continue
    return best_match, score, routes

def build_map(start_region_name: str, routes: list, show_pois: bool = False, zoom_level: int = 13):
    idx = int(flood_df.index[flood_df["areas"] == start_region_name][0])
    center = [float(region_lats[idx]), float(region_lons[idx])]
    m = folium.Map(location=center, zoom_start=zoom_level, tiles=None, control_scale=True)
    
    # Add multiple tile layers
    folium.TileLayer("OpenStreetMap", name="🗺️ Street Map").add_to(m)
    folium.TileLayer("cartodbpositron", name="🌟 Light Mode").add_to(m)
    folium.TileLayer("cartodbdark_matter", name="🌙 Dark Mode").add_to(m)
    
    # Add enhanced map controls
    MiniMap(toggle_display=True, position="bottomleft").add_to(m)
    Fullscreen(position="topleft", title="Fullscreen", title_cancel="Exit Fullscreen").add_to(m)
    MeasureControl(primary_length_unit='kilometers', primary_area_unit='sqkilometers').add_to(m)
    MousePosition(position="bottomright", separator=" | ", prefix="📍 ").add_to(m)
    LocateControl(auto_start=False, position="topleft").add_to(m)
    
    # Only show roads along the evacuation routes
    route_nodes = set()
    for r in routes:
        route_nodes.update(r["path"])
    
    # Filter roads to only those on or near evacuation routes
    relevant_edges = edges_gdf_sampled[
        edges_gdf_sampled["u"].isin(route_nodes) | 
        edges_gdf_sampled["v"].isin(route_nodes) |
        edges_gdf_sampled["region_name"] == start_region_name
    ]
    
    if not relevant_edges.empty:
        GeoJson(
            data=relevant_edges.__geo_interface__,
            name="Road risk (evacuation area)",
            style_function=edge_style,
            tooltip=folium.GeoJsonTooltip(
                fields=["region_name", "risk_level"],
                aliases=["Region", "Risk"],
                sticky=True
            ),
        ).add_to(m)
    
    # Only show the start region and destination regions
    start_region_idx = idx
    start_color = RISK_COLOR.get(str(region_risks[start_region_idx]).lower(), RISK_COLOR["unknown"])
    CircleMarker(
        location=[float(region_lats[start_region_idx]), float(region_lons[start_region_idx])],
        radius=8,
        color=start_color, fill=True, fill_opacity=0.9,
        tooltip=f"START: {start_region_name.title()} — Risk: {str(region_risks[start_region_idx]).title()}",
    ).add_to(m)
    
    # Show destination regions
    dest_regions = [r["dest_region"] for r in routes]
    for dest_region in dest_regions:
        dest_idx = regions.index(dest_region)
        dest_color = RISK_COLOR.get(str(region_risks[dest_idx]).lower(), RISK_COLOR["unknown"])
        CircleMarker(
            location=[float(region_lats[dest_idx]), float(region_lons[dest_idx])],
            radius=6,
            color=dest_color, fill=True, fill_opacity=0.9,
            tooltip=f"DESTINATION: {dest_region.title()} — Risk: {str(region_risks[dest_idx]).title()}",
        ).add_to(m)
    
    # Only show POIs if requested
    if show_pois:
        # Only show POIs near the evacuation routes (within a reasonable distance)
        route_coords = []
        for r in routes:
            route_coords.extend([(G.nodes[n]["y"], G.nodes[n]["x"]) for n in r["path"]])
        
        if route_coords:
            # Get bounds of all route coordinates
            lats = [coord[0] for coord in route_coords]
            lons = [coord[1] for coord in route_coords]
            min_lat, max_lat = min(lats), max(lats)
            min_lon, max_lon = min(lons), max(lons)
            
            # Add some padding
            lat_padding = (max_lat - min_lat) * 0.1
            lon_padding = (max_lon - min_lon) * 0.1
            
            for cat, gdf in pois_by_cat.items():
                if gdf is None or gdf.empty:
                    continue
                # Filter POIs to only those within the route area
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
                cluster = MarkerCluster(name=f"{cat.replace('_',' ').title()} ({len(filtered_pois)})")
                for _, row in filtered_pois.iterrows():
                    geom = row.geometry
                    if geom is None:
                        continue
                    lat, lon = geom.y, geom.x
                    popup_txt = str(row.get("name") or cat.replace("_", " ").title())
                    folium.Marker(
                        location=[lat, lon],
                        icon=folium.Icon(color=color, icon=icon, prefix="fa"),
                        popup=popup_txt
                    ).add_to(cluster)
                m.add_child(cluster)
    
    # Draw evacuation routes
    route_colors = ["#0078FF", "#1ABC9C", "#F39C12", "#C0392B", "#8E44AD"]
    for i, r in enumerate(routes):
        coords = [(G.nodes[n]["y"], G.nodes[n]["x"]) for n in r["path"]]
        PolyLine(
            coords,
            color=route_colors[i % len(route_colors)],
            weight=6, opacity=0.9,
            tooltip=f"Route {i+1}: {r['distance_km']:.2f} km • {r['eta_min']:.0f} min → {r['dest_region'].title()}",
        ).add_to(m)
        start_node = r["path"][0]
        dest_node = r["path"][-1]
        folium.CircleMarker(
            location=(G.nodes[start_node]["y"], G.nodes[start_node]["x"]),
            radius=8, color="#111", fill=True, fill_color="#fff",
            tooltip=f"Start: {start_region_name.title()}",
        ).add_to(m)
        folium.CircleMarker(
            location=(G.nodes[dest_node]["y"], G.nodes[dest_node]["x"]),
            radius=8, color="#111", fill=True, fill_color="#2ecc71",
            tooltip=f"Destination: {r['dest_region'].title()}",
        ).add_to(m)
    
    folium.LayerControl(collapsed=False).add_to(m)
    return m

st.set_page_config(
    page_title="Mumbai Flood Evacuation Routes", 
    page_icon="🌊", 
    layout="wide",
    initial_sidebar_state="expanded"
)

st.title("🌊 Mumbai Flood Evacuation Routes")
st.markdown("**Find safe evacuation routes during flood emergencies in Mumbai**")

# Sidebar with information
with st.sidebar:
    st.header("📋 Information")
    st.markdown("""
    **How to use:**
    1. Enter your area/region name
    2. View suggested evacuation routes
    3. Toggle POIs to see nearby facilities
    4. Use map controls for navigation
    
    **Route Colors:**
    - 🔵 Blue: Primary route
    - 🟢 Green: Secondary route  
    - 🟠 Orange: Alternative route
    - 🔴 Red: Emergency route
    - 🟣 Purple: Backup route
    """)
    
    st.markdown("---")
    st.subheader("🏥 Emergency Contacts")
    st.markdown("""
    - **Fire Brigade:** 101
    - **Police:** 100
    - **Ambulance:** 108
    - **Disaster Helpline:** 1077
    - **Mumbai Traffic:** 103
    """)
    
    st.markdown("---")
    st.subheader("⚙️ Settings")
    
    # Speed setting
    speed_kmph = st.slider("Average Speed (km/h)", 5, 50, 25, help="Adjust for ETA calculation")
    ASSUMED_SPEED_KMPH = speed_kmph
    
    # Number of routes
    num_routes = st.selectbox("Number of Routes", [3, 5, 7, 10], index=1)
    ROUTE_COUNT = num_routes
    
    # Map zoom
    map_zoom = st.slider("Map Zoom Level", 10, 16, 13)

# Main content area
col1, col2 = st.columns([2, 1])

with col1:
    st.write("Enter your region name (area) to find safe evacuation routes.")

with col2:
    # Add refresh button
    if st.button("🔄 Refresh Data", help="Reload map data"):
        st.cache_resource.clear()
        st.cache_data.clear()
        st.rerun()

# Show statistics
col1, col2, col3, col4 = st.columns(4)
with col1:
    st.metric("Total Regions", len(regions))
with col2:
    low_risk_count = len(flood_df[flood_df["flood_risk_level"] == "low"])
    st.metric("Low Risk Areas", low_risk_count)
with col3:
    st.metric("Road Network Nodes", f"{len(G.nodes):,}")
with col4:
    st.metric("Road Network Edges", f"{len(G.edges):,}")

# Region search with autocomplete-like functionality
st.write("### 🏠 Enter Your Location")
user_region = st.text_input("Region name (area):", placeholder="Type your area name... (e.g., andheri, bandra, colaba)")

# Show region suggestions as you type
if user_region and len(user_region) >= 2:
    matching_regions = [r for r in regions if user_region.lower() in r.lower()][:10]
    if matching_regions:
        st.write("**Suggestions:**")
        suggestion_cols = st.columns(min(len(matching_regions), 5))
        for i, region in enumerate(matching_regions):
            with suggestion_cols[i % 5]:
                if st.button(f"📍 {region.title()}", key=f"suggest_{i}"):
                    user_region = region
                    st.rerun()
if user_region:
    with st.spinner("🔍 Finding evacuation routes..."):
        matched, score, routes = get_k_nearest_low_risk_routes(user_region, G, flood_df, k=num_routes)
    
    if not matched:
        st.error(f"❌ Could not match '{user_region}'. Try a different area name.")
        
        # Show region browser
        with st.expander("🔍 Browse Available Regions", expanded=True):
            search_term = st.text_input("Search in regions:", "")
            if search_term:
                filtered_regions = [r for r in regions if search_term.lower() in r.lower()]
            else:
                filtered_regions = regions[:20]  # Show first 20
            
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
        # Show match quality
        if score < 100:
            st.info(f"🔍 Using closest match: **{matched.title()}** (similarity: {score}%)")
        else:
            st.success(f"✅ Found {len(routes)} evacuation routes from **{matched.title()}**")
        
        # Enhanced route display
        st.write("### 🛣️ Evacuation Routes")
        
        # Summary statistics
        total_distance = sum(r['distance_km'] for r in routes)
        avg_time = sum(r['eta_min'] for r in routes) / len(routes)
        
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("Total Distance", f"{total_distance:.1f} km")
        with col2:
            st.metric("Average Time", f"{avg_time:.0f} min")
        with col3:
            shortest_route = min(routes, key=lambda x: x['distance_km'])
            st.metric("Shortest Route", f"{shortest_route['distance_km']:.1f} km")
        
        # Detailed route information
        for i, r in enumerate(routes, 1):
            with st.expander(f"🛣️ Route {i}: to {r['dest_region'].title()} — {r['distance_km']:.2f} km, {r['eta_min']:.0f} min"):
                col1, col2 = st.columns(2)
                with col1:
                    st.write(f"**Distance:** {r['distance_km']:.2f} km")
                    st.write(f"**Estimated Time:** {r['eta_min']:.0f} minutes")
                    st.write(f"**Destination:** {r['dest_region'].title()}")
                with col2:
                    dest_row = flood_df[flood_df["areas"] == r['dest_region']].iloc[0]
                    st.write(f"**Destination Risk:** {dest_row['flood_risk_level'].title()}")
                    st.write(f"**Route Efficiency:** {(r['distance_km']/total_distance*100):.1f}% of total distance")
        
        st.write("---")
        st.write("### 🗺️ Interactive Evacuation Map")
        
        # Enhanced map options
        col1, col2, col3 = st.columns([2, 1, 1])
        with col1:
            st.write("**Map Options:**")
        with col2:
            show_pois = st.checkbox("📍 Show POIs", value=False, help="Points of Interest")
        with col3:
            download_routes = st.checkbox("💾 Enable Download", value=False, help="Download route data")
        
        # Build and display the map
        with st.spinner("🗺️ Creating evacuation map..."):
            try:
                folium_map = build_map(matched, routes, show_pois, map_zoom)
                st.write("✅ Map created successfully. Displaying map...")
                
                map_data = st_folium(
                    folium_map, 
                    width=1000, 
                    height=650, 
                    returned_objects=[],
                    key="evacuation_map",
                    feature_group_to_add=None,
                    use_container_width=False
                )
                
                # Download functionality
                if download_routes:
                    route_data = {
                        "start_region": matched,
                        "routes": routes,
                        "total_distance_km": total_distance,
                        "average_time_min": avg_time
                    }
                    
                    col1, col2 = st.columns(2)
                    with col1:
                        st.download_button(
                            "📥 Download Routes (JSON)",
                            data=pd.Series(route_data).to_json(indent=2),
                            file_name=f"evacuation_routes_{matched}.json",
                            mime="application/json"
                        )
                    with col2:
                        # Create CSV for routes
                        routes_df = pd.DataFrame(routes)
                        st.download_button(
                            "📥 Download Routes (CSV)", 
                            data=routes_df.to_csv(index=False),
                            file_name=f"evacuation_routes_{matched}.csv",
                            mime="text/csv"
                        )
                
                # Legend and help
                with st.expander("📖 Map Legend & Help", expanded=False):
                    col1, col2 = st.columns(2)
                    with col1:
                        st.write("**Map Symbols:**")
                        st.write("🔵 **Start Location** - Your current region")
                        st.write("🟢 **Destinations** - Safe evacuation areas")
                        st.write("🛣️ **Colored Lines** - Evacuation routes")
                        if show_pois:
                            st.write("📍 **POI Clusters** - Points of Interest")
                    with col2:
                        st.write("**Map Controls:**")
                        st.write("🔍 **Zoom** - Mouse wheel or +/- buttons")
                        st.write("🖱️ **Pan** - Click and drag")
                        st.write("📏 **Measure** - Use measure tool")
                        st.write("🌐 **Layers** - Toggle different map styles")
                        st.write("📍 **Location** - Find your current location")
                
                if show_pois:
                    st.info("📍 POIs are now visible! Use the layer control (top-right) to toggle specific categories.")
                    
            except Exception as e:
                st.error(f"❌ Map could not be displayed: {str(e)}")
                st.write("**Error details:**", e)
                
                # Enhanced fallback
                st.write("🔄 Attempting to create a simple fallback map...")
                try:
                    simple_map = folium.Map(location=[19.0760, 72.8777], zoom_start=11)
                    st_folium(simple_map, width=1000, height=400)
                    st.info("🗺️ Simple Mumbai map displayed as fallback.")
                except Exception as fallback_error:
                    st.error(f"❌ Even fallback map failed: {str(fallback_error)}")

else:
    st.info("👆 Please enter your region name above to get started.")
    
    # Show sample regions when no input
    with st.expander("💡 Popular Areas in Mumbai", expanded=True):
        sample_regions = ["andheri west", "bandra", "colaba", "dadar", "powai", "malad", "borivali", "thane"]
        available_samples = [r for r in sample_regions if r in regions]
        
        cols = st.columns(4)
        for i, region in enumerate(available_samples[:8]):
            with cols[i % 4]:
                if st.button(f"🏘️ {region.title()}", key=f"sample_{i}"):
                    user_region = region
                    st.rerun()
