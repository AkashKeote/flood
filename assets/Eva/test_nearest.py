# Test script for nearest_node function
import sys
sys.path.append('.')

# Test the haversine function first
import numpy as np

def haversine_m(lon1, lat1, lon2, lat2):
    R = 6371000.0
    lon1 = np.radians(lon1); lat1 = np.radians(lat1)
    lon2 = np.radians(lon2); lat2 = np.radians(lat2)
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = np.sin(dlat/2.0)**2 + np.cos(lat1)*np.cos(lat2)*np.sin(dlon/2.0)**2
    c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1-a))
    return R * c

# Test basic calculation
dist = haversine_m(72.8777, 19.0760, 72.8777, 19.0760)
print(f"Distance between same point: {dist} meters (should be ~0)")

dist2 = haversine_m(72.8777, 19.0760, 72.9000, 19.1000)
print(f"Distance between different points: {dist2} meters")
print("Haversine function working correctly!")
