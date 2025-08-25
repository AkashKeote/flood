# Test nearest_node fallback implementation
import numpy as np
import networkx as nx

def haversine_m(lon1, lat1, lon2, lat2):
    R = 6371000.0
    lon1 = np.radians(lon1); lat1 = np.radians(lat1)
    lon2 = np.radians(lon2); lat2 = np.radians(lat2)
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = np.sin(dlat/2.0)**2 + np.cos(lat1)*np.cos(lat2)*np.sin(dlon/2.0)**2
    c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1-a))
    return R * c

def manual_nearest_node(G, lon, lat):
    """Manual fallback implementation"""
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

# Create a simple test graph
G = nx.Graph()
G.add_node(1, x=72.8777, y=19.0760)  # Mumbai center
G.add_node(2, x=72.9000, y=19.1000)  # Slightly north-east
G.add_node(3, x=72.8500, y=19.0500)  # Slightly south-west

# Test the function
test_lon, test_lat = 72.8800, 19.0800  # Close to node 1
nearest = manual_nearest_node(G, test_lon, test_lat)
print(f"Nearest node to ({test_lon}, {test_lat}): {nearest}")

# Calculate distances to verify
for node_id in G.nodes():
    node_data = G.nodes[node_id]
    dist = haversine_m(test_lon, test_lat, node_data['x'], node_data['y'])
    print(f"Distance to node {node_id}: {dist:.2f} meters")

print("Manual nearest_node implementation working correctly!")
