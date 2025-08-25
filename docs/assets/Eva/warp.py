#!/usr/bin/env python3
"""
tload.py — Integrated Mumbai evacuation map (final, 5 routes)

Requirements:
  pip install osmnx networkx pandas numpy geopandas folium rapidfuzz shapely
(If rapidfuzz unavailable, script falls back to fuzzywuzzy or difflib.)

Place in same folder:
  - roads_all.graphml
  - mumbai_ward_area_floodrisk.csv

Outputs:
  - mumbai_evacuation_routes.html
"""

# ======================
# Imports (top-only)
# ======================
import os
import json
import numpy as np
import pandas as pd
import networkx as nx
import osmnx as ox
import folium
from folium import GeoJson, PolyLine, CircleMarker
from folium.plugins import MarkerCluster
from shapely.geometry import Point

# ----------------------
# Fuzzy matching helpers
# ----------------------
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


# ----------------------
# Helpers
# ----------------------
def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_", regex=False)
    alias_map = {
        "ward": "areas", "area": "areas", "region": "areas",
        "neighbourhood": "areas", "neighborhood": "areas",
        "flood-risk_level": "flood_risk_level", "flood risk level": "flood_risk_level",
        "risk_level": "flood_risk_level", "risk": "flood_risk_level",
        "lat": "latitude", "y": "latitude", "lon": "longitude", "lng": "longitude", "x": "longitude"
    }
    for old, new in alias_map.items():
        if old in df.columns and new not in df.columns:
            df.rename(columns={old: new}, inplace=True)
    required = ["areas", "latitude", "longitude", "flood_risk_level"]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"CSV missing required columns: {missing} — found: {list(df.columns)}")
    df["areas"] = df["areas"].astype(str).str.strip().str.lower()
    df["flood_risk_level"] = df["flood_risk_level"].astype(str).str.strip().str.lower()
    return df


def extract_best_match(query: str, choices):
    res = fuzzy_process.extractOne(query, choices)
    if res is None:
        return None, 0
    if isinstance(res, (tuple, list)):
        if len(res) >= 2:
            return res[0], int(res[1])
        elif len(res) == 1:
            return res[0], 100
    return res, 100


def haversine_m(lon1, lat1, lon2, lat2):
    """Vectorized haversine for arrays."""
    R = 6371000.0
    lon1 = np.radians(lon1); lat1 = np.radians(lat1)
    lon2 = np.radians(lon2); lat2 = np.radians(lat2)
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = np.sin(dlat/2.0)**2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon/2.0)**2
    c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1-a))
    return R * c


def route_length_m(G: nx.MultiDiGraph, route):
    """Robust length calculation for a route."""
    try:
        lengths = ox.utils_graph.get_route_edge_attributes(G, route, "length")
        return float(sum(lengths)) if lengths else 0.0
    except Exception:
        total = 0.0
        for u, v in zip(route[:-1], route[1:]):
            data = G.get_edge_data(u, v)
            if data:
                vals = list(data.values())
                best = min(vals, key=lambda d: d.get("length", float("inf")))
                total += float(best.get("length", 0.0))
        return total


# ----------------------
# Load graph & CSV (single load)
# ----------------------
GRAPHML = "roads_all.graphml"
CSV = "mumbai_ward_area_floodrisk.csv"
OUT_HTML = "mumbai_evacuation_routes.html"

if not os.path.exists(GRAPHML):
    raise SystemExit(f"❌ Cannot find {GRAPHML} in current directory. Place roads_all.graphml here.")
if not os.path.exists(CSV):
    raise SystemExit(f"❌ Cannot find {CSV} in current directory. Place mumbai_ward_area_floodrisk.csv here.")

print("🔁 Loading graph (graphml)...")
G = ox.load_graphml(GRAPHML)
print(f"✅ Graph loaded: {len(G.nodes)} nodes, {len(G.edges)} edges")

print("🔁 Loading regions CSV...")
flood_df = normalize_columns(pd.read_csv(CSV))
regions = flood_df["areas"].tolist()
region_lons = flood_df["longitude"].astype(float).to_numpy()
region_lats = flood_df["latitude"].astype(float).to_numpy()
region_risks = flood_df["flood_risk_level"].tolist()
n_regions = len(regions)
print(f"✅ Loaded {n_regions} regions")


# ----------------------
# Assign each graph node → nearest region (vectorized)
# ----------------------
print("🔎 Assigning each graph node to nearest region...")
node_ids = np.array(list(G.nodes))
node_lons = np.array([G.nodes[n].get("x", G.nodes[n].get("lon")) for n in node_ids], dtype=float)
node_lats = np.array([G.nodes[n].get("y", G.nodes[n].get("lat")) for n in node_ids], dtype=float)

dist_stack = np.empty((n_regions, len(node_ids)), dtype=float)
for i in range(n_regions):
    dist_stack[i] = haversine_m(region_lons[i], region_lats[i], node_lons, node_lats)

nearest_region_idx_per_node = np.argmin(dist_stack, axis=0)
nodeid_to_region_idx = dict(zip(node_ids.tolist(), nearest_region_idx_per_node.tolist()))
nodeid_to_region_name = {nid: regions[idx] for nid, idx in nodeid_to_region_idx.items()}
nodeid_to_region_risk = {nid: region_risks[idx] for nid, idx in nodeid_to_region_idx.items()}
print("✅ Node → region assignment done.")


# ----------------------
# Edges GeoDataFrame (sampled for lighter HTML)
# ----------------------
print("🔁 Building edges GeoDataFrame (sampled)...")
edges_gdf = ox.graph_to_gdfs(G, nodes=False, edges=True, fill_edge_geometry=True)
if "u" not in edges_gdf.columns or "v" not in edges_gdf.columns:
    edges_gdf = edges_gdf.reset_index()

edges_gdf["_u"] = edges_gdf["u"].astype(int)
edges_gdf["_v"] = edges_gdf["v"].astype(int)

edges_gdf["region_idx"] = edges_gdf["_u"].map(nodeid_to_region_idx)
edges_gdf["region_name"] = edges_gdf["region_idx"].apply(
    lambda i: regions[i] if (i is not None and 0 <= i < n_regions) else "unknown"
)
edges_gdf["risk_level"] = edges_gdf["region_idx"].apply(
    lambda i: region_risks[i] if (i is not None and 0 <= i < n_regions) else "unknown"
)

SAMPLE_FACTOR = 5  # keep every 5th edge to keep HTML small; adjust if needed
edges_gdf_sampled = edges_gdf.iloc[::SAMPLE_FACTOR].copy()
print(f"✅ Edges prepared (sampled): {len(edges_gdf_sampled)} features (factor={SAMPLE_FACTOR})")


# ----------------------
# Risk color map
# ----------------------
risk_color_map = {
    "high": "#d73027",
    "moderate": "#fc8d59",
    "low": "#1a9850",
    "unknown": "#aaaaaa"
}

def edge_style(feature):
    props = feature.get("properties", {})
    risk = str(props.get("risk_level", "unknown")).lower()
    color = risk_color_map.get(risk, risk_color_map["unknown"])
    return {"color": color, "weight": 1.2, "opacity": 0.9}


# ----------------------
# POI categories (clustered, distinct icons/colors)
# ----------------------
POI_CATEGORIES = {
    "hospital": ({"amenity": "hospital"}, "plus", "red"),
    "police": ({"amenity": "police"}, "shield", "darkblue"),
    "fire_station": ({"amenity": "fire_station"}, "fire", "orange"),
    "pharmacy": ({"amenity": "pharmacy"}, "prescription", "purple"),
    "school": ({"amenity": "school"}, "graduation-cap", "cadetblue"),
    "university": ({"amenity": "university"}, "university", "darkgreen"),
    "fuel": ({"amenity": "fuel"}, "gas-pump", "lightgray"),
    "shelter": ({"emergency": "shelter"}, "home", "green"),
    "bank": ({"amenity": "bank"}, "bank", "darkred"),
    "atm": ({"amenity": "atm"}, "money-bill", "darkred"),
    "restaurant": ({"amenity": "restaurant"}, "utensils", "beige"),
    "marketplace": ({"shop": "supermarket"}, "shopping-cart", "brown"),
    "water_tower": ({"man_made": "water_tower"}, "tint", "blue"),
    "power": ({"power": True}, "bolt", "black"),
    "airport": ({"aeroway": "aerodrome"}, "plane", "cadetblue"),
    "port": ({"man_made": "pier"}, "ship", "navy"),
    "bus_station": ({"amenity": "bus_station"}, "bus", "darkblue"),
    "train_station": ({"railway": "station"}, "train", "black"),
    "polyclinic": ({"amenity": "clinic"}, "clinic-medical", "pink"),
    "warehouse_market": ({"building": "warehouse"}, "warehouse", "gray"),
}

print("🔁 Fetching POI layers from OSM (limited per category, may be slow)...")
pois_by_cat = {}
for cat, (tag, icon, color) in POI_CATEGORIES.items():
    try:
        gdf = ox.features_from_place("Mumbai, India", tag)
        if gdf is None or gdf.empty:
            pois_by_cat[cat] = None
            continue
        # normalize to centroid and limit feature count
        gdf_points = gdf.copy()
        gdf_points["geometry"] = gdf_points.geometry.centroid
        if len(gdf_points) > 800:
            gdf_points = gdf_points.sample(800, random_state=1)
        pois_by_cat[cat] = gdf_points
        print(f"  → {cat}: {len(gdf_points)} features")
    except Exception as e:
        print(f"  ⚠️ Could not fetch {cat}: {e}")
        pois_by_cat[cat] = None
print("✅ POI fetching attempted (some categories may be empty).")


# ----------------------
# Find up to 5 nearest low-risk routes (Dijkstra)
# ----------------------
def get_five_safest_routes(user_area: str, G, flood_df):
    all_areas = flood_df["areas"].unique().tolist()
    best_match, score = extract_best_match(user_area.lower().strip(), all_areas)
    if not best_match or score < 50:
        return None, score, []

    # origin node
    start_row = flood_df[flood_df["areas"] == best_match].iloc[0]
    start_lat, start_lon = float(start_row["latitude"]), float(start_row["longitude"])
    try:
        orig_node = ox.distance.nearest_nodes(G, start_lon, start_lat)
    except Exception:
        orig_node = ox.nearest_nodes(G, start_lon, start_lat)

    # candidate destinations = low-risk regions
    safe_df = flood_df[flood_df["flood_risk_level"] == "low"].copy()
    if safe_df.empty:
        return best_match, score, []

    # nearest graph node for each low-risk region
    safe_nodes = []
    for _, row in safe_df.iterrows():
        try:
            node = ox.distance.nearest_nodes(G, float(row["longitude"]), float(row["latitude"]))
        except Exception:
            node = ox.nearest_nodes(G, float(row["longitude"]), float(row["latitude"]))
        safe_nodes.append((int(node), row["areas"]))

    # single-source Dijkstra distances (edge weight by length)
    try:
        lengths = nx.single_source_dijkstra_path_length(G, orig_node, weight="length")
    except Exception:
        lengths = {}

    # reachable candidates with distances
    candidates = []
    for node, area in safe_nodes:
        d = lengths.get(node, None)
        if d is not None:
            candidates.append((node, d, area))

    if not candidates:
        return best_match, score, []

    # sort by distance (meters), then pick up to 5 *distinct* destination regions
    candidates.sort(key=lambda x: x[1])
    selected, seen_areas = [], set()
    for node, d, area in candidates:
        if area in seen_areas:
            continue
        selected.append((node, d, area))
        seen_areas.add(area)
        if len(selected) >= 5:
            break

    # build routes
    routes = []
    for node, _, area in selected:
        try:
            path = nx.shortest_path(G, orig_node, node, weight="length")
            length_m = route_length_m(G, path)
            eta_min = (length_m / 1000.0) / 25.0 * 60.0  # assume 25 km/h evac speed
            routes.append({
                "dest_region": area,
                "dest_node": int(node),
                "path": path,
                "distance_km": float(length_m / 1000.0),
                "eta_min": float(eta_min)
            })
        except Exception:
            continue

    return best_match, score, routes


# ----------------------
# Save interactive map
# ----------------------
def save_map(start_region, routes, out_file=OUT_HTML):
    # center map on the selected start region
    idx = int(flood_df[flood_df["areas"] == start_region].index[0])
    center = [float(region_lats[idx]), float(region_lons[idx])]
    m = folium.Map(location=center, zoom_start=12, tiles="cartodbpositron", control_scale=True)

    # 1) Risk-colored road network (sampled)
    GeoJson(
        data=edges_gdf_sampled.__geo_interface__,
        style_function=edge_style,
        name="Road network (risk-colored, sampled)"
    ).add_to(m)

    # 2) Hoverable region markers for all 102 regions
    for i, nm in enumerate(regions):
        CircleMarker(
            location=[float(region_lats[i]), float(region_lons[i])],
            radius=5,
            color=risk_color_map.get(str(region_risks[i]).lower(), "#888888"),
            fill=True,
            fill_opacity=0.9,
            tooltip=f"{nm.title()} — Risk: {str(region_risks[i]).title()}",
        ).add_to(m)

    # 3) POI clusters with distinct icons/colors
    for cat, (tag, icon, color) in POI_CATEGORIES.items():
        gdf = pois_by_cat.get(cat)
        if gdf is None or gdf.empty:
            continue
        cluster = MarkerCluster(name=f"{cat.replace('_',' ').title()} ({len(gdf)})", control=True)
        for _, row in gdf.iterrows():
            try:
                lat = row.geometry.y
                lon = row.geometry.x
            except Exception:
                continue
            popup = str(row.get("name", cat.replace("_", " ").title()))
            folium.Marker(
                location=[lat, lon],
                icon=folium.Icon(color=color, icon=icon, prefix="fa"),
                popup=popup
            ).add_to(cluster)
        m.add_child(cluster)

    # 4) Draw & highlight UP TO FIVE evacuation routes with ETA + distance
    route_colors = ["#0066ff", "#00cc44", "#ff7f00", "#8b00ff", "#009999"]
    for i, r in enumerate(routes):
        coords = [(G.nodes[n]["y"], G.nodes[n]["x"]) for n in r["path"]]
        PolyLine(
            coords,
            color=route_colors[i % len(route_colors)],
            weight=6,
            opacity=0.9,
            tooltip=f"Route {i+1}: {r['distance_km']:.2f} km, ETA {r['eta_min']:.0f} min → {r['dest_region'].title()}"
        ).add_to(m)

        # Start marker (only once, first route)
        if i == 0:
            start_node = r["path"][0]
            folium.CircleMarker(
                location=(G.nodes[start_node]["y"], G.nodes[start_node]["x"]),
                radius=7, color="#000000", fill=True, fill_color="#ffffff",
                tooltip=f"Start: {start_region.title()}"
            ).add_to(m)

        # Destination marker
        dest_node = r["path"][-1]
        folium.CircleMarker(
            location=(G.nodes[dest_node]["y"], G.nodes[dest_node]["x"]),
            radius=7, color="#000000", fill=True, fill_color="#1a9850",
            tooltip=f"Destination (Low risk): {r['dest_region'].title()}"
        ).add_to(m)

    # 5) Floating info panel (lists all routes + totals)
    routes_info = [{
        "dest_region": r["dest_region"].title(),
        "distance_km": round(r["distance_km"], 3),
        "eta_min": round(r["eta_min"], 1),
    } for r in routes]

    panel_html = (
        '<div id="evac-panel" style="'
        'position: fixed; bottom: 18px; left: 18px; z-index:9999;'
        'background: rgba(255,255,255,0.95); padding: 12px; border-radius:8px;'
        'box-shadow: 0 1px 8px rgba(0,0,0,0.2); max-width:330px; font-family: Arial, sans-serif;">'
        '<h4 style="margin:0 0 6px 0;">Evacuation Summary</h4>'
        '<div id="routes-list" style="font-size:13px; line-height:1.4;"></div>'
        '<hr style="margin:8px 0;">'
        '<div style="font-weight:600;">Totals:</div>'
        '<div id="totals" style="font-size:13px;"></div>'
        '<div style="margin-top:8px; font-size:12px; color:#444;">(Est. ETA assumes 25 km/h average)</div>'
        '</div>'
        '<script>'
        'const routes = ' + json.dumps(routes_info) + ';'
        'function renderPanel() {'
        '  const el = document.getElementById("routes-list");'
        '  const t = document.getElementById("totals");'
        '  el.innerHTML = "";'
        '  let totalD = 0, totalT = 0;'
        '  routes.forEach(function(r, i) {'
        '    totalD += r.distance_km; totalT += r.eta_min;'
        '    const div = document.createElement("div");'
        '    div.innerHTML = "<strong>Route " + (i+1) + ":</strong> " + r.distance_km.toFixed(2) + '
        '" km — " + r.eta_min.toFixed(0) + " min → <em>" + r.dest_region + "</em>";'
        '    el.appendChild(div);'
        '  });'
        '  t.innerHTML = "<div>Total distance: <strong>" + totalD.toFixed(2) + " km</strong></div>" + '
        '"<div>Combined ETA: <strong>" + totalT.toFixed(0) + " min</strong></div>";'
        '}'
        'renderPanel();'
        '</script>'
    )
    m.get_root().html.add_child(folium.Element(panel_html))

    folium.LayerControl(collapsed=False).add_to(m)
    m.save(out_file)
    print(f"✅ Map saved to: {out_file}")


# ----------------------
# Main interactive flow
# ----------------------
if __name__ == "__main__":
    try:
        user_region = input("🏠 Enter your region name (area): ").strip()
    except EOFError:
        raise SystemExit("❌ No input provided.")

    if not user_region:
        raise SystemExit("❌ Empty input.")

    matched, score, routes = get_five_safest_routes(user_region, G, flood_df)
    if not matched:
        print(f"❌ Could not match '{user_region}'. Try a different name.")
        raise SystemExit()
    if not routes:
        print("⚠️ No safe evacuation routes found.")
        raise SystemExit()

    print(f"✅ Using region: {matched.title()} (matched score {score}%)")
    for i, r in enumerate(routes, 1):
        print(f"--- Route {i} ---")
        print(f"Destination: {r['dest_region'].title()}")
        print(f"Distance: {r['distance_km']:.2f} km")
        print(f"ETA: {r['eta_min']:.0f} minutes")

    save_map(matched, routes, OUT_HTML)
