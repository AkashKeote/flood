# Mumbai Flood Evacuation Routes - Deployment Guide

## Recent Fixes (August 2025)
✅ **Fixed map dimming issue** - Removed click event handlers that caused re-rendering  
✅ **Fixed ImportError with OSMnx** - Added robust fallback for nearest_nodes function  
✅ **Fixed deprecated st.experimental_rerun()** - Updated to st.rerun()  
✅ **Fixed geometry CRS warnings** - Proper coordinate projection for POI centroids  
✅ **Enhanced error handling** - Multiple fallback layers for spatial operations  

## Local Development

### Prerequisites
- Python 3.8 or higher
- pip package manager

### Setup
1. Clone the repository
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Run the application:
   ```bash
   streamlit run streamlit_app.py
   ```

## Streamlit Cloud Deployment

### Files Required
- `streamlit_app.py` - Main application
- `requirements.txt` - Python dependencies
- All data files:
  - `roads_all.graphml`
  - `mumbai_ward_area_floodrisk.csv`

### Deployment Steps
1. Push all files to GitHub repository
2. Connect repository to Streamlit Cloud
3. Deploy using `streamlit_app.py` as main file

### Critical Dependencies
The application now includes robust fallbacks, but these packages are recommended:
- `osmnx` - Road network analysis
- `scikit-learn>=1.0.0` - Required by OSMnx for spatial indexing
- `rtree` - Spatial indexing library
- `Fiona` - Geospatial data I/O
- `pyproj` - Coordinate system transformations

### Troubleshooting

#### ImportError with OSMnx (RESOLVED)
The application now includes a robust fallback system:
1. **Primary**: Uses `ox.distance.nearest_nodes()` with scikit-learn
2. **Fallback 1**: Manual distance calculation using haversine formula
3. **Fallback 2**: Tries deprecated OSMnx API 
4. **Fallback 3**: Final manual calculation

#### Geometry CRS Warnings (RESOLVED)
POI centroid calculations now properly:
1. Project to UTM (Universal Transverse Mercator) coordinates
2. Calculate accurate centroids
3. Project back to WGS84 for display

#### Memory Issues
For large datasets, consider:
- Reducing `SAMPLE_FACTOR` (currently 5)
- Limiting `MAX_POIS_PER_CAT` (currently 500)
- Using fewer routes in `ROUTE_COUNT` (currently 5)

## Configuration

### Adjustable Parameters in `streamlit_app.py`:
- `ASSUMED_SPEED_KMPH = 25.0` - Average travel speed
- `SAMPLE_FACTOR = 5` - Road network sampling rate
- `MAX_POIS_PER_CAT = 500` - Maximum POIs per category
- `ROUTE_COUNT = 5` - Number of evacuation routes to find

### Data Files
- `roads_all.graphml` - Mumbai road network (OSM data)
- `mumbai_ward_area_floodrisk.csv` - Flood risk data by area

## Features
- Interactive map with evacuation routes
- Multiple tile layer options (Street, Light, Dark)
- POI (Points of Interest) display with clustering
- Route calculation with ETA
- Responsive design
- Export functionality for routes (JSON/CSV)
- Enhanced map controls (measure, locate, fullscreen)
- Real-time route statistics

## Error Handling
The application includes comprehensive error handling:
- **Spatial Operations**: Multiple fallback methods for nearest node calculations
- **Map Rendering**: Graceful degradation if components fail
- **Data Loading**: Validation and error messages for missing files
- **POI Fetching**: Continues operation even if some POI categories fail

## Performance Optimizations
- Cached data loading using `@st.cache_resource` and `@st.cache_data`
- Sampled road network display to reduce rendering time
- Filtered POI display based on route area
- Efficient spatial indexing with fallbacks
