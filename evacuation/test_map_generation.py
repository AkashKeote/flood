#!/usr/bin/env python3
"""
Test the build_and_save_map function with real-time data
"""
import pandas as pd
import os
import sys

def load_csv_flood_data():
    """Load flood data from CSV and return as dict for fast lookup"""
    csv_path = "mumbai_ward_area_floodrisk_all_102.csv"
    
    if not os.path.exists(csv_path):
        print(f"❌ CSV file not found: {csv_path}")
        return {}
    
    try:
        df = pd.read_csv(csv_path)
        print(f"✅ Loaded CSV with {len(df)} rows")
        
        # Create dict mapping area name (lowercase) to risk level
        flood_data = {}
        for _, row in df.iterrows():
            area_name = str(row['Areas']).strip().lower()
            risk_level = str(row['Flood-risk_level']).strip()
            flood_data[area_name] = risk_level
            
        print(f"✅ Created flood data dict with {len(flood_data)} entries")
        return flood_data
        
    except Exception as e:
        print(f"❌ Error loading CSV: {e}")
        return {}

def test_map_generation():
    """Test the map generation with real-time data"""
    print("🗺️  Testing map generation with real-time data...")
    
    # Load real-time data
    realtime_flood_data = load_csv_flood_data()
    
    if not realtime_flood_data:
        print("❌ No realtime data available for testing")
        return
    
    # Show some sample realtime data
    print(f"\n📋 Sample realtime data:")
    sample_areas = list(realtime_flood_data.items())[:10]
    for area, risk in sample_areas:
        print(f"  {area}: {risk}")
    
    # Simulate what would happen in build_and_save_map
    print(f"\n🧪 Simulating region risk assignment:")
    
    # Sample regions that might be in the map
    test_regions = ['andheri east', 'worli', 'colaba causeway', 'fort', 'bandra']
    
    for region in test_regions:
        region_lower = region.lower()
        
        # This mimics the logic in build_and_save_map
        if realtime_flood_data and region_lower in realtime_flood_data:
            risk_level = realtime_flood_data[region_lower].strip().lower()
            print(f"  ✅ {region.title()}: Using realtime data → {risk_level}")
        else:
            risk_level = 'low'  # Default fallback
            print(f"  ⚠️  {region.title()}: Using fallback → {risk_level}")
        
        # Color assignment (as in build_and_save_map)
        if risk_level == 'high':
            color = 'red'
            fillColor = 'red'
            fill_opacity = 0.7
        elif risk_level == 'moderate':
            color = 'orange'
            fillColor = 'orange'
            fill_opacity = 0.6
        else:  # low
            color = 'green'
            fillColor = 'green'
            fill_opacity = 0.5
        
        print(f"    🎨 Color: {color} (opacity: {fill_opacity})")

if __name__ == "__main__":
    print("🌊 Testing Map Generation with Real-time Data")
    print("=" * 60)
    
    test_map_generation()
    
    print("\n✅ Test completed!")