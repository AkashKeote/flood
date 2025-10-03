#!/usr/bin/env python3
"""
FIXED VERSION: Enhanced Mumbai flood prediction data generator with retry and resume logic
"""

import pandas as pd
import numpy as np
import requests
import time
import logging
import os
from datetime import datetime, timedelta

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
INPUT_CSV = os.path.join("data", "mumbai_static_data.xlsx")
OUTPUT_CSV = os.path.join("data", "mumbai_full_compatibility.csv")
REQUEST_DELAY = 1.2

def get_enhanced_weather_data(lat, lon, is_historical=True):
    """Get enhanced weather data from Open-Meteo API with retry logic"""
    
    try:
        if is_historical:
            # Get 7 days of historical data
            end_date = datetime.now()
            start_date = end_date - timedelta(days=7)
            url = "https://archive-api.open-meteo.com/v1/archive"
            params = {
                "latitude": lat,
                "longitude": lon,
                "start_date": start_date.strftime('%Y-%m-%d'),
                "end_date": end_date.strftime('%Y-%m-%d'),
                "hourly": "precipitation,soil_moisture_0_to_10cm",
                "timezone": "Asia/Kolkata"
            }
        else:
            # Get 7 days of forecast data
            url = "https://api.open-meteo.com/v1/forecast"
            params = {
                "latitude": lat,
                "longitude": lon,
                "hourly": "precipitation,soil_moisture_0_to_10cm",
                "forecast_days": 7,
                "timezone": "Asia/Kolkata"
            }

        r = requests.get(url, params=params, timeout=30)
        r.raise_for_status()
        data = r.json()

        if "hourly" not in data:
            return None

        hourly = data["hourly"]
        times = hourly["time"]
        precipitation = hourly["precipitation"]
        soil_moisture = hourly.get("soil_moisture_0_to_10cm", [0.3] * len(times))

        # Group by day
        daily_data = {}
        for i, time_str in enumerate(times):
            day = time_str.split('T')[0]
            if day not in daily_data:
                daily_data[day] = {"precip": [], "soil": [], "hours": 0}
            
            precip_val = precipitation[i] if precipitation[i] is not None else 0
            soil_val = soil_moisture[i] if soil_moisture[i] is not None else 0.3
            
            daily_data[day]["precip"].append(precip_val)
            daily_data[day]["soil"].append(soil_val)
            if precip_val > 0:
                daily_data[day]["hours"] += 1

        # Calculate daily aggregates
        daily_dates = []
        daily_precip = []
        intensity_per_day = []
        daily_hours = []
        daily_soil = []

        for day in sorted(daily_data.keys()):
            daily_dates.append(day)
            
            # Daily total precipitation
            daily_total = sum(daily_data[day]["precip"])
            daily_precip.append(daily_total)
            
            # Daily rainfall hours
            daily_hours.append(daily_data[day]["hours"])
            
            # Average soil moisture
            daily_soil.append(np.mean(daily_data[day]["soil"]))
            
            # Max hourly intensity
            daily_vals = daily_data[day]["precip"]
            valid_vals = [v for v in daily_vals if v is not None]
            intensity_per_day.append(max(valid_vals) if valid_vals else 0)

        # Rainfall days count
        rainfall_day_flags = [1 if v > 0 else 0 for v in daily_precip]

        return list(zip(daily_dates, daily_precip, intensity_per_day, rainfall_day_flags, daily_hours, daily_soil))
        
    except Exception as e:
        logger.error(f"Error getting enhanced weather data: {str(e)}")
        return None

def calculate_derived_features(rainfall_data, area_info):
    """Calculate missing columns from available data"""
    
    # Calculate longest rainfall days from historical data
    longest_rainfall_days = 0
    current_streak = 0
    for _, rain_mm, _, _, _, _ in rainfall_data:
        if rain_mm > 0:
            current_streak += 1
            longest_rainfall_days = max(longest_rainfall_days, current_streak)
        else:
            current_streak = 0
    
    # Calculate runoff equivalent (simplified model)
    avg_rainfall = np.mean([rain for _, rain, _, _, _, _ in rainfall_data if rain > 0])
    if avg_rainfall == 0:
        avg_rainfall = 10  # Default
    
    # Runoff coefficient based on built-up percentage
    built_up = area_info.get('Built_up%', 75)
    runoff_coeff = 0.05 + (built_up / 100) * 0.4  # 0.05 to 0.45
    runoff_equivalent = avg_rainfall * runoff_coeff
    
    # Discharge calculation (simplified)
    area_km2 = 5.0  # Approximate area per region
    discharge_m3s = (runoff_equivalent * area_km2 * 1000000) / (24 * 3600)  # Convert to m3/s
    
    # Soil Wetness Index from soil moisture
    avg_soil_moisture = np.mean([soil for _, _, _, _, _, soil in rainfall_data])
    soil_wetness_index = avg_soil_moisture * 100
    
    # Drainage line ID (based on area hash)
    drainage_line_id = hash(area_info.get('Areas', 'default')) % 1000
    
    return {
        'Discharge_m3s': round(discharge_m3s, 2),
        'Runoff equivalent': round(runoff_equivalent, 2),
        'Soil Wetness Index': round(soil_wetness_index, 2),
        'Longest rainfall _days': longest_rainfall_days,
        'Drainage_line_id': drainage_line_id,
        'Drainage_properties': f"urban_drainage_{drainage_line_id}",
        'true_conditions_count': len([r for r in rainfall_data if r[1] > 0])
    }

def generate_full_compatibility_data():
    """Generate enhanced compatibility data for all 102 Mumbai areas with retry and resume logic."""
    
    # Check if output file exists to resume
    start_from = 0
    existing_results = []
    if os.path.exists(OUTPUT_CSV):
        try:
            existing_df = pd.read_csv(OUTPUT_CSV)
            unique_areas = existing_df['Areas'].unique()
            start_from = len(unique_areas)
            existing_results = existing_df.to_dict('records')
            logger.info(f"📁 Found existing data for {start_from} areas - resuming from area {start_from + 1}")
        except Exception as e:
            logger.info(f"📁 Starting fresh data generation (couldn't read existing: {e})")
    
    logger.info("🚀 Starting/Resuming FULL COMPATIBILITY data generation")
    logger.info("=" * 60)
    
    try:
        # Load input Excel file
        df = pd.read_excel(INPUT_CSV)
        logger.info(f"📊 Loaded {len(df)} areas from input file")
        
        results = existing_results  # Start with existing data
        processed_count = start_from
        
        # Skip already processed areas
        for idx, row in df.iloc[start_from:].iterrows():
            try:
                lat, lon = row["Latitude"], row["Longitude"]
                area_name = row["Areas"]
                
                logger.info(f"🔄 Processing {processed_count + 1}/{len(df)}: {area_name}")
                
                retry_count = 0
                max_retries = 3
                success = False
                all_weather_data = []
                
                while retry_count < max_retries and not success:
                    try:
                        # Get enhanced weather data (historical + forecast) with retry
                        historical_data = get_enhanced_weather_data(lat, lon, is_historical=True)
                        forecast_data = get_enhanced_weather_data(lat, lon, is_historical=False)
                        
                        all_weather_data = []
                        if historical_data:
                            all_weather_data.extend(historical_data)
                        if forecast_data:
                            all_weather_data.extend(forecast_data)
                        
                        if all_weather_data:
                            success = True
                        else:
                            raise ValueError("No weather data received")
                            
                    except Exception as e:
                        retry_count += 1
                        logger.warning(f"⚠️ Retry {retry_count}/{max_retries} for {area_name}: {str(e)[:100]}")
                        if retry_count < max_retries:
                            time.sleep(5)  # Wait before retry
                        else:
                            logger.error(f"❌ Failed after {max_retries} retries for {area_name}")
                            # Create minimal fallback data
                            all_weather_data = [
                                (datetime.now().strftime('%Y-%m-%d'), 10.0, 2.0, 1, 3, 0.3)
                            ]
                            success = True  # Continue with fallback
                
                if all_weather_data:
                    # Calculate derived features from all data
                    derived = calculate_derived_features(all_weather_data, row)
                    
                    for day, rain_mm, intensity, rain_flag, rain_hours, soil_moisture in all_weather_data:
                        record = {
                            # Basic info (matching training format)
                            "DATE": day,
                            "Ward Code": row["Ward Code"],
                            "Areas": area_name,
                            "Latitude": lat,
                            "Longitude": lon,
                            "Nearest Station": row["Nearest Station"],
                            "Elevation": row["Elevation"],
                            "Land Use Classes": row["Land Use Classes"],
                            "Population": row["Population"],
                            "Road Density_m": row["Road Density_m"],
                            "Distance_to_water_m": row["Distance_to_water_m"],
                            "Soil Type": row["Soil Type"],
                            "Built_up%": row["Built_up%"],
                            "True_nearest_distance_m": row["True_nearest_distance_m"],
                            
                            # Weather data
                            "Rainfall_mm": rain_mm,
                            "Rainfall_Intensity_mm_hr": intensity,
                            "Rainfall Days Count": rain_flag,
                            
                            # NEW: Generated missing columns
                            "Discharge_m3s": derived['Discharge_m3s'],
                            "Runoff equivalent": derived['Runoff equivalent'],
                            "Soil Wetness Index": derived['Soil Wetness Index'],
                            "Longest rainfall _days": derived['Longest rainfall _days'],
                            "Drainage_line_id": derived['Drainage_line_id'],
                            "Drainage_properties": derived['Drainage_properties'],
                            "true_conditions_count": derived['true_conditions_count'],
                            
                            # Additional weather features
                            "Rainfall_Hours": rain_hours
                        }
                        results.append(record)
                    
                    logger.info(f"   ✅ Added {len(all_weather_data)} enhanced records (historical + forecast)")
                    
                    # Save intermediate results every 5 areas
                    if (processed_count + 1) % 5 == 0:
                        temp_df = pd.DataFrame(results)
                        temp_df.to_csv(OUTPUT_CSV, index=False)
                        logger.info(f"💾 Intermediate save - {processed_count + 1} areas completed")
                
                processed_count += 1
                time.sleep(REQUEST_DELAY)
                
            except Exception as e:
                logger.error(f"❌ Error processing area {processed_count + 1}: {str(e)}")
                processed_count += 1
                continue  # Skip this area and continue
        
        if results:
            # Create final output dataframe
            out_df = pd.DataFrame(results)
            
            # Save the data
            out_df.to_csv(OUTPUT_CSV, index=False)
            
            logger.info("=" * 60)
            logger.info("✅ FULL COMPATIBILITY data generation completed!")
            logger.info(f"📊 Total records: {len(out_df)}")
            logger.info(f"🏢 Areas covered: {out_df['Areas'].nunique()}")
            logger.info(f"📅 Date range: {out_df['DATE'].min()} to {out_df['DATE'].max()}")
            logger.info(f"📂 Output saved to: {OUTPUT_CSV}")
            logger.info("=" * 60)
            
            return True
        else:
            logger.error("❌ No data generated!")
            return False
    
    except Exception as e:
        logger.error(f"❌ Error in generation: {str(e)}")
        return False

def main():
    """Main function"""
    success = generate_full_compatibility_data()
    if success:
        logger.info("🎉 Success! Enhanced compatibility data generated.")
    else:
        logger.error("❌ Generation failed")

if __name__ == "__main__":
    main()