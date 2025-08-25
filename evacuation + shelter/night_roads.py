import streamlit as st
import osmnx as ox
import matplotlib.pyplot as plt
import numpy as np
from scipy.ndimage import gaussian_filter
from matplotlib.colors import LinearSegmentedColormap

# --- Streamlit Sidebar Controls ---
st.title("🌃 Night Lights Road Map")
st.write("Generate a glowing road network map (night-lights style) using OSM data.")

city = st.text_input("Enter city name:", "Mumbai, India")
point_density = st.slider("Point density per road segment", 10, 100, 40)
img_size = st.slider("Image resolution (px)", 1000, 6000, 3000, step=500)
glow_sigma = st.slider("Glow blur radius (sigma)", 1, 10, 3)

# --- Load Road Network ---
ox.config(use_cache=True, log_console=False)
custom_filter = '["highway"~"residential|living_street|service|footway|track|unclassified|pedestrian"]'

st.info(f"Downloading road network for **{city}**...")
try:
    G = ox.graph_from_place(city, network_type="walk", custom_filter=custom_filter, simplify=True)
except Exception as e:
    st.error(f"Could not load city: {e}")
    st.stop()

G_proj = ox.project_graph(G)
gdf_edges = ox.graph_to_gdfs(G_proj, nodes=False, edges=True)

# --- Bounds ---
minx, miny, maxx, maxy = gdf_edges.total_bounds

# --- Create raster image ---
img = np.zeros((img_size, img_size))

for _, row in gdf_edges.iterrows():
    coords = np.array(row.geometry.coords)
    if len(coords) < 2:
        continue
    for i in range(len(coords) - 1):
        x0, y0 = coords[i]
        x1, y1 = coords[i + 1]
        for t in np.linspace(0, 1, point_density):
            x = x0 + t * (x1 - x0)
            y = y0 + t * (y1 - y0)
            px = int((x - minx) / (maxx - minx) * (img_size - 1))
            py = int((y - miny) / (maxy - miny) * (img_size - 1))
            if 0 <= px < img_size and 0 <= py < img_size:
                img[img_size - 1 - py, px] += 1

# --- Glow Effect ---
glow = gaussian_filter(img, sigma=glow_sigma)

# --- Auto contrast ---
low, high = np.percentile(glow, (1, 99.5))
glow = np.clip((glow - low) / (high - low), 0, 1)

# --- Colormap (black → orange → yellow → white) ---
night_cmap = LinearSegmentedColormap.from_list(
    "nightlights",
    [
        (0, "black"),
        (0.3, "#ff6600"),
        (0.6, "yellow"),
        (1.0, "white")
    ]
)

# --- Plot ---
fig, ax = plt.subplots(figsize=(10, 10), facecolor="black")
ax.imshow(glow, cmap=night_cmap, interpolation="bilinear")
ax.axis("off")
plt.tight_layout()

st.pyplot(fig)
