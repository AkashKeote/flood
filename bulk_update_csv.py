#!/usr/bin/env python3
"""
Bulk CSV Update Script
Automatically updates all areas in CSV with ML predictions
"""

import requests
import time
import csv
import os

# Configuration
API_URL = "http://localhost:7860"
CSV_FILE = "evacuation/mumbai_ward_area_floodrisk_all_102.csv"

def get_prediction(area_name):
    """Get prediction from API"""
    try:
        response = requests.get(f"{API_URL}/predict", params={"area": area_name})
        if response.status_code == 200:
            data = response.json()
            return data.get("flood_risk", "Unknown")
        else:
            print(f"❌ API error for {area_name}: {response.status_code}")
            return None
    except Exception as e:
        print(f"❌ Connection error for {area_name}: {e}")
        return None

def update_csv():
    """Update CSV with predictions for all areas"""
    print("🚀 Starting bulk CSV update...")
    
    # Read CSV
    if not os.path.exists(CSV_FILE):
        print(f"❌ CSV file not found: {CSV_FILE}")
        return
    
    with open(CSV_FILE, 'r', encoding='utf-8') as file:
        lines = file.readlines()
    
    if len(lines) < 2:
        print("❌ CSV file is empty or has no data")
        return
    
    # Parse header
    header = lines[0].strip().split(',')
    risk_index = header.index('Flood-risk_level') if 'Flood-risk_level' in header else -1
    
    if risk_index == -1:
        print("❌ Flood-risk_level column not found")
        return
    
    print(f"📊 Found {len(lines)-1} areas to update")
    
    # Update each area
    updated_count = 0
    for i in range(1, len(lines)):
        columns = lines[i].strip().split(',')
        if len(columns) > 1:
            area_name = columns[1].strip()
            
            print(f"🔍 Processing {area_name}...")
            
            # Get prediction
            prediction = get_prediction(area_name)
            if prediction:
                # Normalize prediction
                if prediction.lower() in ['high', 'critical']:
                    new_risk = 'High'
                elif prediction.lower() in ['moderate', 'medium']:
                    new_risk = 'Moderate'
                elif prediction.lower() == 'low':
                    new_risk = 'Low'
                else:
                    new_risk = 'Moderate'  # Default
                
                # Update CSV
                columns[risk_index] = new_risk
                lines[i] = ','.join(columns) + '\n'
                updated_count += 1
                print(f"✅ Updated {area_name}: {new_risk}")
            else:
                print(f"⚠️ Skipped {area_name}: No prediction")
            
            # Small delay to avoid overwhelming API
            time.sleep(0.5)
    
    # Write updated CSV
    with open(CSV_FILE, 'w', encoding='utf-8') as file:
        file.writelines(lines)
    
    print(f"\n🎉 Bulk update completed!")
    print(f"✅ Updated {updated_count} areas")
    print(f"📄 CSV file saved: {CSV_FILE}")

if __name__ == "__main__":
    print("🧪 BULK CSV UPDATE SCRIPT")
    print("=" * 30)
    print("⚠️ Make sure API server is running on http://localhost:7860")
    print("⚠️ This will update ALL areas in CSV with ML predictions")
    
    response = input("\nContinue? (y/N): ")
    if response.lower() == 'y':
        update_csv()
    else:
        print("❌ Cancelled by user")
