#!/usr/bin/env python3
"""
Test script to validate real-time heatmap functionality
"""
import pandas as pd
import os

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
        
        # Show sample data
        print("\n📋 Sample flood data:")
        for i, (area, risk) in enumerate(list(flood_data.items())[:5]):
            print(f"  {area}: {risk}")
        
        return flood_data
        
    except Exception as e:
        print(f"❌ Error loading CSV: {e}")
        return {}

def test_region_risk_mapping():
    """Test the region risk mapping logic"""
    print("🧪 Testing region risk mapping...")
    
    # Load real-time data
    realtime_flood_data = load_csv_flood_data()
    
    if not realtime_flood_data:
        print("❌ No realtime data available")
        return
    
    # Sample regions to test
    test_regions = ['andheri east', 'bandra', 'mumbai central', 'worli', 'lower parel']
    
    print(f"\n🔍 Testing risk mapping for {len(test_regions)} regions:")
    
    for region in test_regions:
        region_lower = region.lower()
        if region_lower in realtime_flood_data:
            risk = realtime_flood_data[region_lower]
            print(f"  ✅ {region.title()}: {risk}")
        else:
            print(f"  ❌ {region.title()}: NOT FOUND")
    
    # Test color mapping
    print(f"\n🎨 Testing color mapping:")
    risk_colors = {
        'high': 'red',
        'moderate': 'orange', 
        'low': 'green'
    }
    
    for region in test_regions:
        region_lower = region.lower()
        if region_lower in realtime_flood_data:
            risk = realtime_flood_data[region_lower].lower()
            color = risk_colors.get(risk, 'gray')
            print(f"  🎯 {region.title()}: {risk} → {color}")

if __name__ == "__main__":
    print("🌊 Testing Real-time Heatmap Functionality")
    print("=" * 50)
    
    test_region_risk_mapping()
    
    print("\n✅ Test completed!")