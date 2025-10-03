#!/usr/bin/env python3
"""
Enhanced API configuration for full compatibility dataset
"""

import pandas as pd
import os

# File paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "data")

# Updated data files with full compatibility
FULL_COMPATIBILITY_FILE = os.path.join(DATA_DIR, "mumbai_full_compatibility.csv")
ENHANCED_MODEL_FILE = os.path.join(DATA_DIR, "enhanced_flood_model.pkl")

# API Configuration
API_CONFIG = {
    "data_source": FULL_COMPATIBILITY_FILE,
    "model_path": ENHANCED_MODEL_FILE,
    "features_used": [
        # Core geographic features
        "Latitude", "Longitude", "Elevation", "Distance_to_water_m",
        
        # Weather features (from API)
        "Rainfall_mm", "Rainfall_Intensity_mm_hr", "Rainfall Days Count",
        
        # Enhanced weather features (generated)
        "Discharge_m3s", "Runoff equivalent", "Soil Wetness Index",
        "Longest rainfall _days",
        
        # Area characteristics
        "Population", "Built_up%", "Road Density_m",
        
        # Infrastructure features (estimated)
        "Drainage_line_id", "true_conditions_count"
    ],
    "categorical_features": [
        "Ward Code", "Land Use Classes", "Soil Type", "Drainage_properties"
    ],
    "target_variable": "flood_risk_prediction",  # Will be predicted
    "api_endpoints": {
        "predict_single": "/predict/area",
        "predict_bulk": "/predict/bulk",
        "forecast_area": "/forecast_for_area",
        "health_check": "/health"
    }
}

def validate_data_compatibility():
    """Validate that the full compatibility data is ready for API use"""
    
    if not os.path.exists(FULL_COMPATIBILITY_FILE):
        return False, "Full compatibility data file not found"
    
    try:
        df = pd.read_csv(FULL_COMPATIBILITY_FILE)
        
        # Check if we have all required features
        missing_features = []
        for feature in API_CONFIG["features_used"]:
            if feature not in df.columns:
                missing_features.append(feature)
        
        for feature in API_CONFIG["categorical_features"]:
            if feature not in df.columns:
                missing_features.append(feature)
        
        if missing_features:
            return False, f"Missing features: {missing_features}"
        
        # Check data quality
        total_records = len(df)
        areas_covered = df['Areas'].nunique()
        
        return True, {
            "status": "compatible",
            "total_records": total_records,
            "areas_covered": areas_covered,
            "features_available": len(df.columns),
            "date_range": f"{df['DATE'].min()} to {df['DATE'].max()}"
        }
        
    except Exception as e:
        return False, f"Data validation error: {str(e)}"

def get_api_summary():
    """Get summary of API configuration and data status"""
    
    is_valid, result = validate_data_compatibility()
    
    summary = {
        "enhanced_api_ready": is_valid,
        "configuration": API_CONFIG,
        "data_status": result
    }
    
    return summary

if __name__ == "__main__":
    print("🔧 ENHANCED API CONFIGURATION")
    print("=" * 50)
    
    summary = get_api_summary()
    
    if summary["enhanced_api_ready"]:
        print("✅ API Ready for Enhanced Data!")
        print(f"📊 Records: {summary['data_status']['total_records']}")
        print(f"🏢 Areas: {summary['data_status']['areas_covered']}")
        print(f"📋 Features: {summary['data_status']['features_available']}")
        print(f"📅 Date Range: {summary['data_status']['date_range']}")
    else:
        print("❌ API Not Ready")
        print(f"Issue: {summary['data_status']}")
    
    print(f"\n🎯 Features configured: {len(API_CONFIG['features_used'])}")
    print(f"🎯 Categorical features: {len(API_CONFIG['categorical_features'])}")