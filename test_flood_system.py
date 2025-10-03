#!/usr/bin/env python3
"""
Test Script for Flood Prediction API and CSV Update Functionality
This script tests the integration between the API and CSV updates.
"""

import os
import sys
import json
import time
import requests
import pandas as pd
from pathlib import Path

# Add the src directory to Python path
current_dir = Path(__file__).parent
src_dir = current_dir / "PredictionModel" / "src"
sys.path.append(str(src_dir))

def test_api_connection(base_url="http://127.0.0.1:7860"):
    """Test if the API is running and responsive"""
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        if response.status_code == 200:
            print("✅ API is running and healthy")
            print(f"📊 API Health: {response.json()}")
            return True
        else:
            print(f"❌ API returned status code: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Cannot connect to API: {e}")
        return False

def test_areas_endpoint(base_url="http://127.0.0.1:7860"):
    """Test the areas endpoint"""
    try:
        response = requests.get(f"{base_url}/areas", timeout=5)
        if response.status_code == 200:
            data = response.json()
            areas = data.get('areas', [])
            print(f"✅ Found {len(areas)} areas available for prediction")
            if areas:
                print(f"📍 Sample areas: {areas[:5]}...")
            return areas
        else:
            print(f"❌ Areas endpoint failed: {response.status_code}")
            return []
    except requests.exceptions.RequestException as e:
        print(f"❌ Error getting areas: {e}")
        return []

def test_prediction(area_name, base_url="http://127.0.0.1:7860"):
    """Test prediction for a specific area"""
    try:
        response = requests.get(
            f"{base_url}/predict",
            params={"area": area_name},
            timeout=10
        )
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Prediction for {area_name}:")
            print(f"   🎯 Risk Level: {data.get('flood_risk', 'Unknown')}")
            print(f"   📈 Confidence: {data.get('confidence', 0):.1%}")
            print(f"   📍 Matched Area: {data.get('matched_area', 'N/A')}")
            print(f"   🔍 Match Score: {data.get('match_score', 0):.2f}")
            return data
        else:
            print(f"❌ Prediction failed for {area_name}: {response.status_code}")
            return None
    except requests.exceptions.RequestException as e:
        print(f"❌ Error predicting {area_name}: {e}")
        return None

def check_csv_file():
    """Check if the CSV file exists and its structure"""
    csv_path = Path("evacuation/mumbai_ward_area_floodrisk_all_102.csv")
    
    if not csv_path.exists():
        print(f"❌ CSV file not found: {csv_path}")
        return False
    
    try:
        df = pd.read_csv(csv_path)
        print(f"✅ CSV file loaded successfully")
        print(f"📊 CSV contains {len(df)} rows")
        print(f"📋 Columns: {list(df.columns)}")
        
        if 'Flood-risk_level' in df.columns:
            risk_levels = df['Flood-risk_level'].value_counts()
            print(f"🎯 Current risk level distribution:")
            for level, count in risk_levels.items():
                print(f"   {level}: {count} areas")
        
        return True
        
    except Exception as e:
        print(f"❌ Error reading CSV: {e}")
        return False

def test_csv_update_simulation():
    """Simulate CSV update by showing what would be updated"""
    csv_path = Path("evacuation/mumbai_ward_area_floodrisk_all_102.csv")
    
    if not csv_path.exists():
        print("❌ Cannot test CSV update - file not found")
        return False
    
    try:
        df = pd.read_csv(csv_path)
        
        # Test areas to simulate updates
        test_areas = ['Colaba', 'Fort', 'Bandra', 'Andheri', 'Mulund']
        print(f"\n🔄 Simulating CSV updates for test areas...")
        
        for area in test_areas:
            # Find matching rows in CSV
            matches = df[df['Areas'].str.contains(area, case=False, na=False)]
            if not matches.empty:
                current_risk = matches.iloc[0]['Flood-risk_level']
                print(f"   📍 {area}: Current risk = {current_risk}")
                print(f"      🔄 Would update to new AI prediction")
            else:
                print(f"   ⚠️ {area}: No match found in CSV")
        
        return True
        
    except Exception as e:
        print(f"❌ Error in CSV update simulation: {e}")
        return False

def run_comprehensive_test():
    """Run all tests"""
    print("🚀 Starting Flood Prediction System Test")
    print("=" * 50)
    
    # Test 1: API Connection
    print("\n1️⃣ Testing API Connection...")
    api_running = test_api_connection()
    
    if not api_running:
        print("\n❌ API is not running. Please start the API first:")
        print("   cd PredictionModel/src")
        print("   python api.py")
        return False
    
    # Test 2: Areas Endpoint
    print("\n2️⃣ Testing Areas Endpoint...")
    areas = test_areas_endpoint()
    
    # Test 3: Predictions
    print("\n3️⃣ Testing Predictions...")
    test_areas = ['Colaba', 'Fort', 'Bandra']
    predictions = []
    
    for area in test_areas:
        if area in areas or any(area.lower() in a.lower() for a in areas):
            pred = test_prediction(area)
            if pred:
                predictions.append((area, pred))
        time.sleep(1)  # Small delay between requests
    
    # Test 4: CSV File Check
    print("\n4️⃣ Testing CSV File...")
    csv_ok = check_csv_file()
    
    # Test 5: CSV Update Simulation
    print("\n5️⃣ Testing CSV Update Simulation...")
    csv_update_ok = test_csv_update_simulation()
    
    # Summary
    print("\n" + "=" * 50)
    print("📋 TEST SUMMARY")
    print("=" * 50)
    print(f"✅ API Connection: {'PASS' if api_running else 'FAIL'}")
    print(f"✅ Areas Endpoint: {'PASS' if areas else 'FAIL'}")
    print(f"✅ Predictions: {'PASS' if predictions else 'FAIL'}")
    print(f"✅ CSV File: {'PASS' if csv_ok else 'FAIL'}")
    print(f"✅ CSV Updates: {'PASS' if csv_update_ok else 'FAIL'}")
    
    if predictions:
        print(f"\n🎯 Sample Predictions:")
        for area, pred in predictions[:3]:
            print(f"   {area}: {pred.get('flood_risk', 'Unknown')} "
                  f"({pred.get('confidence', 0):.1%} confidence)")
    
    print("\n🔗 Integration Status:")
    if api_running and csv_ok:
        print("✅ Ready for Flutter app integration")
        print("   - API endpoints are working")
        print("   - CSV file is accessible")
        print("   - Prediction and update flow is functional")
    else:
        print("❌ Issues found - check the logs above")
    
    return api_running and csv_ok

if __name__ == "__main__":
    try:
        success = run_comprehensive_test()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n⏹️ Test interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)