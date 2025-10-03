# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a **hybrid flood management system** consisting of two main components:

1. **Flutter Mobile App** (`/lib/`) - Cross-platform flood prediction and emergency management app
2. **Streamlit Evacuation System** (`/Eva/`) - Advanced Mumbai evacuation routing system with AI-powered optimization

## Architecture Overview

### Flutter App Structure
```
lib/
├── main.dart              # Entry point, theming, navigation
├── SplashScreen.dart      # Loading screen
├── DashboardPage.dart     # Main dashboard with flood status
├── FloodPredictionPage.dart # AI-powered prediction interface
├── FloodPrediction.dart   # Prediction logic (placeholder for ML integration)
├── RoutePage.dart         # Evacuation routing (integrates Eva system features)
├── EmergencyPage.dart     # Emergency contacts and actions
├── ProfilePage.dart       # User settings
└── flood_areas.dart       # Flood zone data structures
```

### Evacuation System Structure
```
Eva/
├── streamlit_app.py       # Main routing application
├── enhanced_app.py        # Advanced version with weather/traffic simulation
├── requirements.txt       # Python dependencies
├── DEPLOYMENT.md          # Deployment guide with fixes
├── ENHANCED_FEATURES.md   # Feature documentation
└── cache/                 # OSM data cache
```

### Data Layer
```
Dataset/                   # Flood prediction datasets
├── elevation/
├── rainfall/
├── drainage/
└── readme.md
```

## Development Commands

### Flutter Development

**Prerequisites**: Flutter SDK must be installed and added to PATH

**Setup and Dependencies**:
```bash
# Install dependencies
flutter pub get

# Check Flutter installation
flutter doctor
```

**Development**:
```bash
# Run on connected device/emulator
flutter run

# Run with hot reload (development)
flutter run --debug

# Run for web
flutter run -d chrome

# Run for specific platform
flutter run -d windows
flutter run -d android
flutter run -d ios
```

**Testing and Analysis**:
```bash
# Run tests
flutter test

# Analyze code quality
flutter analyze

# Format code
flutter format .

# Check for outdated packages
flutter pub outdated
```

**Building**:
```bash
# Build for release (Android)
flutter build apk --release

# Build for web
flutter build web

# Build for Windows
flutter build windows

# Build for iOS (macOS only)
flutter build ios --release
```

### Python/Streamlit Development (Eva System)

**Setup**:
```bash
# Navigate to Eva directory
cd Eva

# Install Python dependencies
pip install -r requirements.txt

# For enhanced version
pip install -r requirements_enhanced.txt
```

**Development**:
```bash
# Run basic evacuation app
streamlit run streamlit_app.py

# Run enhanced version with weather simulation
streamlit run enhanced_app.py

# Test spatial functions
python test_nearest.py
python test_manual_nearest.py
```

**Data Management**:
```bash
# Required data files (must be present):
# - roads_all.graphml (Mumbai road network)
# - mumbai_ward_area_floodrisk.csv (Flood risk data)
```

## Key Technical Details

### Flutter App Architecture

**Theme System**: Uses a pastel color scheme with Google Fonts (Poppins) and Material Design 3. Key colors:
- Primary: `#B5C7F7` (pastel blue)
- Secondary: `#F9E79F` (pastel yellow)  
- Background: `#F7F6F2` (soft off-white)

**Navigation**: Bottom navigation with 5 main sections (Dashboard, Prediction, Map, Emergency, Profile)

**Responsive Design**: Includes `ResponsiveWrapper` for web deployment with mobile-like constraints

### Evacuation System Architecture

**Core Features**:
- OSMnx-based road network analysis
- Multiple fallback implementations for spatial calculations
- Weather and traffic simulation (enhanced version)
- Interactive Folium maps with route optimization
- Fuzzy string matching for location search

**Performance Optimizations**:
- Cached data loading with `@st.cache_resource` and `@st.cache_data`
- Sampled road networks (configurable via `SAMPLE_FACTOR = 5`)
- Efficient spatial indexing with multiple fallbacks

**Configuration Parameters** (in Python files):
```python
ASSUMED_SPEED_KMPH = 25.0    # Average evacuation speed
SAMPLE_FACTOR = 5            # Road network sampling rate
MAX_POIS_PER_CAT = 500       # POI display limit
ROUTE_COUNT = 5              # Number of evacuation routes
```

## Integration Points

### Flutter-Python Integration
The Flutter app includes placeholder prediction logic in `FloodPrediction.dart` that can be extended to:
- Call Python ML models via REST API
- Integrate with the Eva routing system for evacuation planning
- Share geographic data between components

### Data Flow
1. **Flutter app** collects user location and preferences
2. **Eva system** processes evacuation routes using OSM data
3. **Dataset folder** provides ML training data for flood prediction
4. Results flow back to Flutter UI for user interaction

## Development Workflow

### For Flutter Changes:
1. Make changes in `/lib/` directory
2. Test with `flutter run`
3. Use hot reload for rapid iteration
4. Run `flutter analyze` before committing

### For Evacuation System Changes:
1. Work in `/Eva/` directory
2. Test locally with `streamlit run streamlit_app.py`
3. Verify spatial calculations with test scripts
4. Update requirements.txt if adding dependencies

### For Data Updates:
1. Update CSV files in `/Dataset/` 
2. Regenerate GraphML files if road networks change
3. Clear Streamlit cache if data structure changes

## Deployment Considerations

### Flutter Deployment:
- **Web**: Built files ready for static hosting
- **Mobile**: Standard app store deployment process
- **Desktop**: Platform-specific builds available

### Streamlit Deployment:
- **Streamlit Cloud**: Push to GitHub and deploy via streamlit_app.py
- **Self-hosted**: Requires Python environment with all dependencies
- **Docker**: Can be containerized for cloud deployment

## Common Issues & Solutions

### OSMnx Import Errors:
The Eva system includes robust fallback mechanisms for spatial calculations when scikit-learn is unavailable. See `DEPLOYMENT.md` for details.

### Flutter Web Issues:
The responsive wrapper handles different screen sizes. For mobile-like experience on web, constraints are applied automatically.

### Memory Issues (Streamlit):
Reduce `SAMPLE_FACTOR`, `MAX_POIS_PER_CAT`, or `ROUTE_COUNT` in configuration for large datasets.

## File Locations for Common Tasks

**Adding new Flutter screens**: `/lib/` directory, update navigation in `main.dart`

**Modifying flood prediction logic**: `/lib/FloodPrediction.dart`

**Updating evacuation algorithms**: `/Eva/streamlit_app.py` or `/Eva/enhanced_app.py`

**Adding new datasets**: `/Dataset/` directory with corresponding CSV format

**Styling changes**: Theme configuration in `/lib/main.dart`

**Deployment configuration**: Check platform-specific folders (`android/`, `ios/`, `web/`, etc.)
