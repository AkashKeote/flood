import os
import sys
import difflib
import folium
import osmnx as ox
import pandas as pd
import networkx as nx
from shapely.geometry import Point, LineString

# ----------------------------
# Config
# ----------------------------
GRAPH_FILE = "roads_all.graphml"
FLOOD_FILE = "mumbai_ward_area_floodrisk.csv"
OUT_HTML = "evacuation_map.html"

# Walking speed (km/h) for ETA
WALKING_SPEED = 5.0


# ----------------------------
# Helpers
# ----------------------------
def fuzzy_match(name, choices):
    """Return best fuzzy match for region name"""
    match = difflib.get_close_matches(name, choices, n=1, cutoff=0.5)
    return match[0] if match else None


def risk_color(level):
    """Map flood risk level to colors"""
    level = str(level).lower()
    if "low" in level:
        return "green"
    elif "moderate" in level:
        return "orange"
    elif "high" in level:
        return "red"
    else:
        return "gray"


# ----------------------------
# Load data
# ----------------------------
if not os.path.exists(GRAPH_FILE):
    print(f"❌ Missing graph file: {GRAPH_FILE}")
    sys.exit(1)

if not os.path.exists(FLOOD_FILE):
    print(f"❌ Missing flood file: {FLOOD_FILE}")
    sys.exit(1)

print("🚀 Loading saved road network...")
G = ox.load_graphml(GRAPH_FILE)
print(f"✅ Road network loaded: {len(G.nodes)} nodes, {len(G.edges)} edges")

# Ensure DiGraph
if isinstance(G, nx.MultiDiGraph):
    G = nx.DiGraph(G)

# Load flood risk CSV
flood_df = pd.read_csv(FLOOD_FILE)
if "Flood-risk_level" not in flood_df.columns:
    raise ValueError("CSV must contain column: Flood-risk_level")


# ----------------------------
# Map regions to nearest graph nodes
# ----------------------------
region_nodes = {}
for _, row in flood_df.iterrows():
    lat, lon = row["Latitude"], row["Longitude"]
    node = ox.distance.nearest_nodes(G, lon, lat)
    region_nodes[row["Areas"]] = {
        "node": node,
        "risk": row["Flood-risk_level"],
        "lat": lat,
        "lon": lon,
    }


# ----------------------------
# Ask user input
# ----------------------------
user_input = input("🏠 Enter your region name (area): ")
matched_region = fuzzy_match(user_input, flood_df["Areas"].tolist())

if not matched_region:
    print(f"❌ No match found for '{user_input}'")
    sys.exit(1)

print(f"✅ Using start region: {matched_region} (match score 100%)")

start = region_nodes[matched_region]["node"]


# ----------------------------
# Folium map
# ----------------------------
m = folium.Map(
    location=[flood_df["Latitude"].mean(), flood_df["Longitude"].mean()],
    zoom_start=12,
    tiles="cartodbpositron",
)

# Add region markers
for area, info in region_nodes.items():
    folium.CircleMarker(
        location=[info["lat"], info["lon"]],
        radius=6,
        color=risk_color(info["risk"]),
        fill=True,
        fill_opacity=0.8,
        popup=f"{area} ({info['risk']})",
    ).add_to(m)


# ----------------------------
# Compute routes to safe regions
# ----------------------------
safe_regions = [
    (a, info) for a, info in region_nodes.items() if str(info["risk"]).lower() == "low"
]

if not safe_regions:
    print("⚠️ No low-risk regions available.")
    sys.exit(1)

# Compute shortest path distance to each safe region
distances = []
for area, info in safe_regions:
    try:
        dist = nx.shortest_path_length(
            G, start, info["node"], weight="length"
        )
        distances.append((dist, area, info))
    except nx.NetworkXNoPath:
        continue

if not distances:
    print("⚠️ No safe evacuation routes found.")
    sys.exit(1)

# Pick 2 nearest
distances = sorted(distances)[:2]

for idx, (dist, area, info) in enumerate(distances, 1):
    path = nx.shortest_path(G, start, info["node"], weight="length")
    route_line = LineString(
        [(G.nodes[n]["y"], G.nodes[n]["x"]) for n in path]
    )

    km = dist / 1000
    eta = km / WALKING_SPEED * 60

    folium.PolyLine(
        locations=[(G.nodes[n]["y"], G.nodes[n]["x"]) for n in path],
        color="blue" if idx == 1 else "purple",
        weight=5,
        opacity=0.7,
        popup=f"Route {idx}: {km:.2f} km, ETA {eta:.0f} min → {area} (Low risk)",
    ).add_to(m)

    folium.Marker(
        location=[info["lat"], info["lon"]],
        icon=folium.Icon(color="green", icon="flag"),
        popup=f"Destination: {area} (Low risk)",
    ).add_to(m)


# ----------------------------
# Save map
# ----------------------------
m.save(OUT_HTML)
print(f"✅ Map saved as {OUT_HTML}")
