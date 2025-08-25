import streamlit as st
import os
import json
import numpy as np
import pandas as pd
import networkx as nx
import osmnx as ox
import folium
from folium import GeoJson, PolyLine, CircleMarker
from folium.plugins import MarkerCluster, MiniMap, Fullscreen, MeasureControl, MousePosition, LocateControl
from streamlit_folium import st_folium

# ----------------------------
# Config
# ----------------------------
GRAPHML = "roads_all.graphml"
CSV = "mumbai_ward_area_floodrisk.csv"
PLACE = "Mumbai, India"
ASSUMED_SPEED_KMPH = 25.0
ROUTE_COUNT = 5
SAMPLE_FACTOR = 5
MAX_POIS_PER_CAT = 500

RISK_COLOR = {
    "low": "#1a9850",
    "moderate": "#fc8d59",
    "high": "#d73027",
    "unknown": "#aaaaaa",
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

def haversine_m(lon1, lat1, lon2, lat2):
    R = 6371000.0
    lon1, lat1, lon2, lat2 = map(np.radians, [lon1, lat1, lon2, lat2])
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = np.sin(dlat/2.0)**2 + np.cos(lat1)*np.cos(lat2)*np.sin(dlon/2.0)**2
    return R * (2 * np.arctan2(np.sqrt(a), np.sqrt(1-a)))

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
    return ox.distance.nearest_nodes(G, X=lon, Y=lat)

# ----------------------------
# Route finder
# ----------------------------
def fuzzy_match_region(user_area: str, all_areas: list):
    """Find best matching region name using fuzzy matching"""
    user_area_lower = user_area.lower().strip()
    
    # First try exact match
    if user_area_lower in all_areas:
        return user_area_lower, 100
    
    # Try partial matches
    for area in all_areas:
        if user_area_lower in area or area in user_area_lower:
            return area, 90
    
    # Try basic fuzzy matching
    best_match = None
    best_score = 0
    for area in all_areas:
        # Simple character overlap scoring
        common_chars = set(user_area_lower) & set(area)
        score = len(common_chars) / max(len(user_area_lower), len(area)) * 100
        if score > best_score and score > 50:
            best_score = score
            best_match = area
    
    return best_match, int(best_score) if best_match else 0

def get_k_nearest_low_risk_routes(user_area: str, G, flood_df, k=ROUTE_COUNT):
    all_areas = flood_df["areas"].unique().tolist()
    matched_region, score = fuzzy_match_region(user_area, all_areas)
    
    if not matched_region or score < 50:
        return None, 0, []
    
    start_row = flood_df[flood_df["areas"] == matched_region].iloc[0]
    start_lat, start_lon = float(start_row["latitude"]), float(start_row["longitude"])
    orig_node = nearest_node(G, start_lon, start_lat)

    low_df = flood_df[flood_df["flood_risk_level"] == "low"]
    if low_df.empty:
        return matched_region, score, []

    try:
        dists = nx.single_source_dijkstra_path_length(G, orig_node, weight="length")
    except Exception:
        return matched_region, score, []
        
    candidates = []
    for _, row in low_df.iterrows():
        node = nearest_node(G, float(row["longitude"]), float(row["latitude"]))
        d = dists.get(node, None)
        if d is not None:
            candidates.append((row["areas"], node, d))
    if not candidates:
        return user_area, 100, []

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
    return matched_region, score, routes

# ----------------------------
# Build map
# ----------------------------
def build_map(start_region_name: str, routes: list, G, flood_df):
    # Find the region in the dataframe
    region_rows = flood_df[flood_df["areas"] == start_region_name]
    if region_rows.empty:
        st.error(f"Region '{start_region_name}' not found in flood data")
        return None
    
    start_row = region_rows.iloc[0]
    center = [float(start_row["latitude"]), float(start_row["longitude"])]
    m = folium.Map(location=center, zoom_start=12)

    # Add base layers
    folium.TileLayer("OpenStreetMap", name="OpenStreetMap").add_to(m)
    folium.TileLayer("cartodbpositron", name="Carto Positron").add_to(m)
    folium.TileLayer("cartodbdark_matter", name="Carto Dark").add_to(m)
    
    # Add map controls
    MiniMap(toggle_display=True).add_to(m)
    Fullscreen(position="topleft").add_to(m)
    MeasureControl(primary_length_unit='kilometers').add_to(m)
    MousePosition(position="bottomright", separator=" | ", prefix="Lat/Lon:").add_to(m)
    LocateControl(auto_start=False).add_to(m)

    # Add start marker
    start_risk = start_row["flood_risk_level"]
    start_color = RISK_COLOR.get(start_risk, RISK_COLOR["unknown"])
    CircleMarker(
        location=center,
        radius=10,
        color=start_color,
        fill=True,
        fill_opacity=0.9,
        tooltip=f"START: {start_region_name.title()} — Risk: {start_risk.title()}",
    ).add_to(m)

    # Add routes
    route_colors = ["#0078FF", "#1ABC9C", "#F39C12", "#C0392B", "#8E44AD"]
    for i, r in enumerate(routes):
        coords = [(G.nodes[n]["y"], G.nodes[n]["x"]) for n in r["path"]]
        PolyLine(
            coords,
            color=route_colors[i % len(route_colors)],
            weight=6,
            opacity=0.9,
            tooltip=f"Route {i+1}: {r['distance_km']} km • {r['eta_min']} min → {r['dest_region'].title()}"
        ).add_to(m)
        
        # Add destination marker
        dest_node = r["path"][-1]
        dest_lat, dest_lon = G.nodes[dest_node]["y"], G.nodes[dest_node]["x"]
        CircleMarker(
            location=[dest_lat, dest_lon],
            radius=8,
            color="#2ecc71",
            fill=True,
            fill_opacity=0.9,
            tooltip=f"DESTINATION: {r['dest_region'].title()}",
        ).add_to(m)
    
    folium.LayerControl(collapsed=False).add_to(m)
    return m

# ----------------------------
# Streamlit app
# ----------------------------
def main():
    st.set_page_config(page_title="Mumbai Evacuation Routes", layout="wide")
    st.title("🌊 Mumbai Flood Evacuation Map")
    st.write("Enter your region name to find safe evacuation routes to low-risk areas.")

    @st.cache_resource
    def load_data():
        if not os.path.exists(GRAPHML):
            st.error(f"❌ Missing {GRAPHML} file in current directory.")
            st.stop()
        if not os.path.exists(CSV):
            st.error(f"❌ Missing {CSV} file in current directory.")
            st.stop()
            
        with st.spinner("Loading road network..."):
            G = ox.load_graphml(GRAPHML)
            largest_cc_nodes = max(nx.weakly_connected_components(G), key=len)
            G = G.subgraph(largest_cc_nodes).copy()
            st.success(f"✅ Road network loaded: {len(G.nodes)} nodes, {len(G.edges)} edges")
            
        with st.spinner("Loading flood risk data..."):
            flood_df_raw = pd.read_csv(CSV)
            flood_df = normalize_columns(flood_df_raw)
            st.success(f"✅ Flood data loaded: {len(flood_df)} regions")
            
        return G, flood_df

    try:
        G, flood_df = load_data()
    except Exception as e:
        st.error(f"❌ Error loading data: {str(e)}")
        st.stop()

    # Show available regions
    with st.expander("📋 Available Regions", expanded=False):
        regions_list = sorted(flood_df["areas"].unique())
        st.write(f"**Total regions:** {len(regions_list)}")
        cols = st.columns(3)
        for i, region in enumerate(regions_list):
            with cols[i % 3]:
                st.write(f"• {region.title()}")

    user_region = st.text_input("🏠 Enter your region name (area):", placeholder="e.g., andheri, bandra, colaba")
    
    if user_region:
        with st.spinner("Finding evacuation routes..."):
            matched, score, routes = get_k_nearest_low_risk_routes(user_region, G, flood_df)
            
        if not matched:
            st.error(f"❌ Region '{user_region}' not found. Please check the available regions above.")
            
            # Show suggestions for similar regions
            user_lower = user_region.lower()
            suggestions = [region for region in flood_df["areas"].unique() 
                          if user_lower in region or region in user_lower]
            if suggestions:
                st.write("**Did you mean:**")
                for suggestion in suggestions[:5]:  # Show max 5 suggestions
                    st.write(f"• {suggestion.title()}")
        elif not routes:
            st.warning("⚠️ No safe evacuation routes found from this region.")
        else:
            if score < 100:
                st.info(f"🔍 Using closest match: **{matched.title()}** (similarity: {score}%)")
            else:
                st.success(f"✅ Found {len(routes)} evacuation routes from **{matched.title()}**")
            
            # Show route details
            for i, r in enumerate(routes, 1):
                st.write(f"**Route {i}:** {r['distance_km']} km, {r['eta_min']} min → **{r['dest_region'].title()}**")
            
            st.write("---")
            st.write("### 🗺️ Interactive Evacuation Map")
            
            try:
                with st.spinner("Creating map..."):
                    folium_map = build_map(matched, routes, G, flood_df)
                    
                if folium_map is not None:
                    st_folium(folium_map, width=1200, height=700, returned_objects=[])
                    
                    # Add legend
                    st.write("**Map Legend:**")
                    st.write("🔵 **Start Location** - Your current region")
                    st.write("🟢 **Destinations** - Safe evacuation areas (low flood risk)")
                    st.write("🛣️ **Colored Lines** - Evacuation routes")
                else:
                    st.error("❌ Could not create map due to data issues.")
                
            except Exception as e:
                st.error(f"❌ Error creating map: {str(e)}")
                st.write("**Debug info:**")
                st.write(f"- Matched region: {matched}")
                st.write(f"- Number of routes: {len(routes)}")
                st.write(f"- Available regions in data: {len(flood_df)}")

if __name__ == "__main__":
    main()
