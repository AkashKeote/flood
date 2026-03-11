# Flood Prediction System 🌊

A comprehensive Flood Prediction System featuring a Flutter-based mobile application interface with a Python/FastAPI predictive modeling backend. The system allows users to fetch AI-based flood risk predictions for specific areas (e.g., Mumbai Wards) and updates evacuation & risk data in real time.

## 🌟 Key Features

* **Single Area Prediction**: Get real-time AI flood risk predictions for specific areas and wards.
* **Bulk Area Prediction**: Perform bulk predictions across all available areas and automatically log them.
* **CSV Data Management**: Smartly updates local dataset records (`evacuation/mumbai_ward_area_floodrisk_all_102.csv`) with fuzzy logic area matching.
* **Interactive UI**: Progress tracking, real-time result viewing, and notifications built in Flutter.
* **Heatmaps & Routing**: Deep integration with routing capabilities to generate evacuation routes and flood heatmaps.

## 🏗️ Architecture

The project is structured into two main parts:
1. **Frontend**: A Flutter cross-platform mobile app that handles the user interface, routing maps, and data visualization.
2. **Backend**: A FastAPI Python server (`PredictionModel`) hosting the machine learning models and endpoints.

### Main Directories
* `lib/` - Contains the Dart/Flutter application source code (UI, API services, CSV update logic).
* `PredictionModel/src/` - Contains the Python backend API (`api.py`) and ML models.
* `evacuation/` - Stores the targeted CSV datasets outlining risks in specified geographical wards.

## 🚀 Getting Started

### Prerequisites
* **Flutter SDK** (stable)
* **Python 3.8+**
* **Pip** (Python package installer)

### Step 1: Start the Backend API

Start the predictive API model locally. It exposes endpoints to check health and fetch flood predictions.

**Using Windows Batch Script:**
```bash
double-click start_api.bat
```

**Manual Start:**
```bash
cd PredictionModel/src
pip install -r ../requirements.txt
python api.py
```
*The API should now be running locally on `http://127.0.0.1:7860`.*

### Step 2: Test the System Flow

Ensure that the AI model and CSV update functionality are communicating seamlessly.

**Using Windows Batch Script:**
```bash
double-click test_system.bat
```

**Manual Start:**
```bash
python test_flood_system.py
```

### Step 3: Run the Flutter App

Once the backend API is up and running, you can launch the Flutter UI:

```bash
flutter clean
flutter pub get
flutter run
```

## 🔌 API Endpoints

The FastAPI service exposes the following main routes:
* `GET /health` - Checks if the API is online and functional.
* `GET /areas` - Returns a list of supported geographical areas.
* `GET /predict?area=<name>` - Returns the flood prediction risk level for a requested area.

## 📝 Additional Documentation

For more in-depth architectural and implementation specifics, please refer to the documentation files included in the repository:
* `SOLUTION_SUMMARY.md` - Overall architecture, CSV pipeline, and issue fixes.
* `FLOOD_HEATMAP_IMPLEMENTATION.md` - Details on generating visualization heatmaps.
* `ROUTE_MAP_INTEGRATION.md` - Guidelines on routing integrations and evacuation paths.

## 🛡️ Troubleshooting

* **Unsupported operation: _Namespace (Flutter)**: Ensure you are running the app on a supported platform target if performing direct file system updates. The system includes a fixed `csv_update_service.dart` that addresses Dart VM file system operation conflicts.
* **API fails to connect**: Make sure the backend is running on `127.0.0.1:7860` and there are no CORS or firewall restrictions.
