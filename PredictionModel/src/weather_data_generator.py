#!/usr/bin/env python3
"""
Mumbai Weather Data Generator - Historical & Forecast
====================================================
This script generates both historical (past 7 days) and forecast (next 7 days) 
weather data for Mumbai areas using Open-Meteo API.
"""

import pandas as pd
import requests
import time
from datetime import datetime, timedelta
import os

# -------------------------------------------------
# CONFIG
# -------------------------------------------------
INPUT_CSV = "data/mumbai_static_data.xlsx"     # Static area data
COMBINED_OUTPUT = "data/mumbai_combined_weather_data.csv"  # Main combined output

# API URLs
ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive"
FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
REQUEST_DELAY = 1.2        # seconds between API calls to avoid rate limit

print("🌦️ MUMBAI WEATHER DATA GENERATOR")
print("=" * 50)
print("📊 Historical: Past 7 days rainfall data")
print("🔮 Forecast: Next 7 days weather predictions")
print("🔄 Combined: All data in mumbai_combined_weather_data.csv")
print("=" * 50)

# -------------------------------------------------
# LOAD STATIC DATA
# -------------------------------------------------
def load_static_data():
    """Load static area data from Excel or CSV"""
    if INPUT_CSV.endswith('.xlsx'):
        try:
            df = pd.read_excel(INPUT_CSV)
            print(f"✅ Loaded {len(df)} areas from {INPUT_CSV}")
        except Exception as e:
            print(f"❌ Failed to load Excel file: {e}")
            return None
    else:
        try:
            df = pd.read_csv(INPUT_CSV)
            print(f"✅ Loaded {len(df)} areas from {INPUT_CSV}")
        except Exception as e:
            print(f"❌ Failed to load CSV file: {e}")
            return None
    
    return df

# -------------------------------------------------
# HISTORICAL DATA FUNCTIONS
# -------------------------------------------------
def get_weather_past7days(lat: float, lon: float):
    """Fetch past 7 complete days of daily rainfall + intensity & hours."""
    # yesterday as end, 7 days back as start (inclusive)
    today_utc = datetime.utcnow().date()
    end = today_utc - timedelta(days=1)
    start = end - timedelta(days=6)

    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "daily": ["precipitation_sum", "precipitation_hours", "temperature_2m_max", "temperature_2m_min"],
        "hourly": "precipitation",
        "timezone": "Asia/Kolkata",
    }

    try:
        r = requests.get(ARCHIVE_URL, params=params, timeout=30)
        r.raise_for_status()
        data = r.json()
    except Exception as e:
        print(f"❌ Historical API error for {lat},{lon}: {e}")
        return None

    if "daily" not in data or "time" not in data["daily"]:
        print(f"⚠️ No historical daily data for {lat},{lon}")
        return None

    daily_dates = data["daily"]["time"]
    daily_precip = data["daily"]["precipitation_sum"]
    daily_hours = data["daily"].get("precipitation_hours", [0]*len(daily_dates))
    daily_temp_max = data["daily"].get("temperature_2m_max", [0]*len(daily_dates))
    daily_temp_min = data["daily"].get("temperature_2m_min", [0]*len(daily_dates))

    # compute daily max hourly intensity (filter None values!)
    intensity_per_day = []
    if "hourly" in data and "precipitation" in data["hourly"]:
        hourly_times = data["hourly"]["time"]
        hourly_precip = data["hourly"]["precipitation"]
        for d in range(len(daily_dates)):
            day_start = datetime.fromisoformat(daily_dates[d])
            day_end = day_start + timedelta(days=1)
            daily_vals = [
                val for t, val in zip(hourly_times, hourly_precip)
                if day_start <= datetime.fromisoformat(t) < day_end and val is not None
            ]
            intensity_per_day.append(max(daily_vals) if daily_vals else 0.0)
    else:
        intensity_per_day = [0.0] * len(daily_dates)

    rainfall_day_flags = [1 if (v is not None and v > 0) else 0 for v in daily_precip]

    return list(zip(daily_dates, daily_precip, intensity_per_day, rainfall_day_flags, 
                   daily_hours, daily_temp_max, daily_temp_min))

# -------------------------------------------------
# FORECAST DATA FUNCTIONS
# -------------------------------------------------
def get_weather_forecast7days(lat: float, lon: float):
    """Fetch next 7 days weather forecast"""
    params = {
        "latitude": lat,
        "longitude": lon,
        "daily": [
            "precipitation_sum", "precipitation_hours", "precipitation_probability_max",
            "temperature_2m_max", "temperature_2m_min", "temperature_2m_mean",
            "wind_speed_10m_max", "wind_gusts_10m_max", "wind_direction_10m_dominant",
            "relative_humidity_2m_max", "relative_humidity_2m_min", "pressure_msl_mean"
        ],
        "hourly": ["precipitation", "precipitation_probability"],
        "timezone": "Asia/Kolkata",
        "forecast_days": 7
    }

    try:
        r = requests.get(FORECAST_URL, params=params, timeout=30)
        r.raise_for_status()
        data = r.json()
    except Exception as e:
        print(f"❌ Forecast API error for {lat},{lon}: {e}")
        return None

    if "daily" not in data or "time" not in data["daily"]:
        print(f"⚠️ No forecast daily data for {lat},{lon}")
        return None

    daily_data = data["daily"]
    
    # Extract all daily parameters safely
    forecast_data = []
    for i in range(len(daily_data["time"])):
        forecast_data.append({
            "date": daily_data["time"][i],
            "precipitation_sum": daily_data.get("precipitation_sum", [None]*7)[i],
            "precipitation_hours": daily_data.get("precipitation_hours", [None]*7)[i],
            "precipitation_probability": daily_data.get("precipitation_probability_max", [None]*7)[i],
            "temp_max": daily_data.get("temperature_2m_max", [None]*7)[i],
            "temp_min": daily_data.get("temperature_2m_min", [None]*7)[i],
            "temp_mean": daily_data.get("temperature_2m_mean", [None]*7)[i],
            "wind_speed_max": daily_data.get("wind_speed_10m_max", [None]*7)[i],
            "wind_gusts_max": daily_data.get("wind_gusts_10m_max", [None]*7)[i],
            "wind_direction": daily_data.get("wind_direction_10m_dominant", [None]*7)[i],
            "humidity_max": daily_data.get("relative_humidity_2m_max", [None]*7)[i],
            "humidity_min": daily_data.get("relative_humidity_2m_min", [None]*7)[i],
            "pressure": daily_data.get("pressure_msl_mean", [None]*7)[i]
        })

    return forecast_data

# -------------------------------------------------
# COMBINE DATA FUNCTIONS
# -------------------------------------------------
def combine_weather_data_by_area(historical_results, forecast_results):
    """Combine data by area: Area1(historical+forecast), Area2(historical+forecast)"""
    print("\n🔄 COMBINING DATA BY AREA")
    print("-" * 40)
    
    # Group historical and forecast by area
    historical_by_area = {}
    forecast_by_area = {}
    
    # Group historical data by area
    for record in historical_results:
        area = record["Areas"]  # Updated to match training data
        if area not in historical_by_area:
            historical_by_area[area] = []
        historical_by_area[area].append(record)
    
    # Group forecast data by area (no need to reprocess since structure matches now)
    for record in forecast_results:
        area = record["Areas"]  # Updated to match training data
        if area not in forecast_by_area:
            forecast_by_area[area] = []
        forecast_by_area[area].append(record)
    
    # Combine by area: Area1(hist+forecast), Area2(hist+forecast)
    combined_data = []
    
    for area in sorted(historical_by_area.keys()):
        print(f"📍 Processing {area}")
        
        # Add historical data for this area
        if area in historical_by_area:
            area_historical = sorted(historical_by_area[area], key=lambda x: x["DATE"])
            combined_data.extend(area_historical)
            print(f"  📈 Added {len(area_historical)} historical records")
        
        # Add forecast data for this area
        if area in forecast_by_area:
            area_forecast = sorted(forecast_by_area[area], key=lambda x: x["DATE"])
            combined_data.extend(area_forecast)
            print(f"  🔮 Added {len(area_forecast)} forecast records")
    
    print(f"✅ Combined {len(historical_results)} historical + {len(forecast_results)} forecast records")
    print(f"📊 Total combined records: {len(combined_data)}")
    
    # Convert to DataFrame and ensure only required columns
    result_df = pd.DataFrame(combined_data)
    
    # Define required columns only
    required_columns = [
        "DATE", "Ward Code", "Areas", "Latitude", "Longitude", 
        "Nearest Station", "Elevation", "Land Use Classes", "Population", 
        "Road Density_m", "Distance_to_water_m", "Soil Type", "Built_up%", 
        "True_nearest_distance_m", "Rainfall_mm", "Rainfall_Intensity_mm_hr", 
        "Rainfall Days Count", "Rainfall_Hours"
    ]
    
    # Select only required columns that exist in the DataFrame
    existing_columns = [col for col in required_columns if col in result_df.columns]
    result_df = result_df[existing_columns]
    
    print(f"📋 Output columns: {list(result_df.columns)}")
    
    return result_df

# -------------------------------------------------
# GENERATE HISTORICAL DATA
# -------------------------------------------------
def generate_historical_data(df, limit_areas=None):
    """Generate historical weather data for areas (limit_areas=2 for testing)"""
    print("\n📈 GENERATING HISTORICAL DATA (Past 7 days)")
    if limit_areas:
        print(f"🧪 TESTING MODE: Processing only first {limit_areas} areas")
    print("-" * 40)
    
    historical_results = []
    processed_count = 0
    
    for idx, row in df.iterrows():
        if limit_areas and processed_count >= limit_areas:
            print(f"✅ Reached limit of {limit_areas} areas for testing")
            break
        lat = float(row["Latitude"]) if "Latitude" in row else None
        lon = float(row["Longitude"]) if "Longitude" in row else None
        
        if lat is None or lon is None:
            print(f"⚠️ Skipping {row.get('Areas', 'Unknown')} - missing coordinates")
            continue
            
        print(f"📡 Fetching historical data for {row.get('Areas', 'Unknown')} ({lat}, {lon})")

        weather_data = get_weather_past7days(lat, lon)

        if weather_data:
            for day, rain_mm, intensity, rain_flag, rain_hours, temp_max, temp_min in weather_data:
                # Calculate additional required fields
                runoff_equiv = (rain_mm * 0.7) if rain_mm else 0.0  # Approximate runoff
                soil_wetness = min(100, (rain_mm + rain_hours) * 2) if rain_mm else 0.0  # Soil wetness index
                longest_rain_days = rain_flag  # For daily data, longest = current flag
                
                historical_results.append({
                    "DATE": day,
                    "Ward Code": row["Ward Code"] if "Ward Code" in df.columns else None,
                    "Areas": row["Areas"] if "Areas" in df.columns else None,
                    "Latitude": lat,
                    "Longitude": lon,
                    "Nearest Station": row["Nearest Station"] if "Nearest Station" in df.columns else None,
                    "Elevation": row["Elevation"] if "Elevation" in df.columns else None,
                    "Land Use Classes": row["Land Use Classes"] if "Land Use Classes" in df.columns else None,
                    "Population": row["Population"] if "Population" in df.columns else None,
                    "Road Density_m": row["Road Density_m"] if "Road Density_m" in df.columns else None,
                    "Distance_to_water_m": row["Distance_to_water_m"] if "Distance_to_water_m" in df.columns else None,
                    "Soil Type": row["Soil Type"] if "Soil Type" in df.columns else None,
                    "Built_up%": row["Built_up%"] if "Built_up%" in df.columns else None,
                    "True_nearest_distance_m": row["True_nearest_distance_m"] if "True_nearest_distance_m" in df.columns else None,
                    "Rainfall_mm": rain_mm if rain_mm is not None else 0.0,
                    "Rainfall_Intensity_mm_hr": intensity,
                    "Rainfall Days Count": rain_flag,
                    "Rainfall_Hours": rain_hours if rain_hours is not None else 0.0,
                })

        print(f"✅ Processed historical data for {row.get('Areas', 'Unknown')}")
        time.sleep(REQUEST_DELAY)
        processed_count += 1
    
    print(f"✅ Historical data generated for {processed_count} areas")
    return historical_results

# -------------------------------------------------
# GENERATE FORECAST DATA
# -------------------------------------------------
def generate_forecast_data(df, limit_areas=None):
    """Generate forecast weather data for areas (limit_areas=2 for testing)"""
    print("\n🔮 GENERATING FORECAST DATA (Next 7 days)")
    if limit_areas:
        print(f"🧪 TESTING MODE: Processing only first {limit_areas} areas")
    print("-" * 40)
    
    forecast_results = []
    regions_forecast = []
    processed_count = 0
    
    for idx, row in df.iterrows():
        if limit_areas and processed_count >= limit_areas:
            print(f"✅ Reached limit of {limit_areas} areas for testing")
            break
        lat = float(row["Latitude"]) if "Latitude" in row else None
        lon = float(row["Longitude"]) if "Longitude" in row else None
        
        if lat is None or lon is None:
            print(f"⚠️ Skipping {row.get('Areas', 'Unknown')} - missing coordinates")
            continue
            
        print(f"🔮 Fetching forecast data for {row.get('Areas', 'Unknown')} ({lat}, {lon})")

        forecast_data = get_weather_forecast7days(lat, lon)

        if forecast_data:
            for day_data in forecast_data:
                # Calculate additional required fields for forecast
                rain_mm = day_data["precipitation_sum"] or 0.0
                rain_hours = day_data["precipitation_hours"] or 0.0
                intensity = rain_mm / rain_hours if rain_hours > 0 else 0.0
                runoff_equiv = rain_mm * 0.7  # Approximate runoff
                soil_wetness = min(100, (rain_mm + rain_hours) * 2)  # Soil wetness index
                rain_flag = 1 if rain_mm > 0 else 0
                
                # Comprehensive forecast with required columns only
                forecast_results.append({
                    "DATE": day_data["date"],
                    "Ward Code": row["Ward Code"] if "Ward Code" in df.columns else None,
                    "Areas": row["Areas"] if "Areas" in df.columns else None,
                    "Latitude": lat,
                    "Longitude": lon,
                    "Nearest Station": row["Nearest Station"] if "Nearest Station" in df.columns else None,
                    "Elevation": row["Elevation"] if "Elevation" in df.columns else None,
                    "Land Use Classes": row["Land Use Classes"] if "Land Use Classes" in df.columns else None,
                    "Population": row["Population"] if "Population" in df.columns else None,
                    "Road Density_m": row["Road Density_m"] if "Road Density_m" in df.columns else None,
                    "Distance_to_water_m": row["Distance_to_water_m"] if "Distance_to_water_m" in df.columns else None,
                    "Soil Type": row["Soil Type"] if "Soil Type" in df.columns else None,
                    "Built_up%": row["Built_up%"] if "Built_up%" in df.columns else None,
                    "True_nearest_distance_m": row["True_nearest_distance_m"] if "True_nearest_distance_m" in df.columns else None,
                    "Rainfall_mm": rain_mm,
                    "Rainfall_Intensity_mm_hr": intensity,
                    "Rainfall Days Count": rain_flag,
                    "Rainfall_Hours": rain_hours,
                })
                
                # Regional forecast (simplified)
                regions_forecast.append({
                    "Date": day_data["date"],
                    "Region": row["Areas"] if "Areas" in df.columns else None,
                    "Ward_Code": row["Ward Code"] if "Ward Code" in df.columns else None,
                    "Rainfall_Forecast_mm": day_data["precipitation_sum"] or 0.0,
                    "Rain_Probability_%": day_data["precipitation_probability"] or 0.0,

                })

        print(f"✅ Processed forecast data for {row.get('Areas', 'Unknown')}")
        time.sleep(REQUEST_DELAY)
        processed_count += 1
    
    print(f"✅ Forecast data generated for {processed_count} areas")
    return forecast_results, regions_forecast

# -------------------------------------------------
# MAIN EXECUTION
# -------------------------------------------------
def main():
    """Main function to generate both historical and forecast data"""
    
    # Load static data
    df = load_static_data()
    if df is None:
        print("❌ Failed to load static data. Exiting.")
        return
    
    # Create data directory if it doesn't exist
    os.makedirs("data", exist_ok=True)
    
    # Set limit for testing (change to None for all areas)
    LIMIT_AREAS = 2  # Test with 2 areas first to verify column structure
    
    print(f"\n🚀 FULL GENERATION MODE: Processing all areas")
    print("⏰ This will take approximately 4-5 minutes (102 areas × 2 API calls each)")
    print("-" * 50)
    
    # Generate historical data
    historical_results = generate_historical_data(df, limit_areas=LIMIT_AREAS)
    
    # Generate forecast data
    forecast_results, regions_forecast = generate_forecast_data(df, limit_areas=LIMIT_AREAS)
    
    # Combine historical and forecast data BY AREA
    if historical_results and forecast_results:
        combined_df = combine_weather_data_by_area(historical_results, forecast_results)
        
        # Save combined data to main output file
        output_file = "data/mumbai_combined_weather_data.csv"
        combined_df.to_csv(output_file, index=False)
        print(f"\n✅ COMBINED weather data saved to {output_file}")
        print(f"📊 Total records: {len(combined_df)}")
        print(f"📈 Historical records: {len(historical_results)}")
        print(f"🔮 Forecast records: {len(forecast_results)}")
    else:
        print("❌ Failed to generate combined data - missing historical or forecast data")
    
    print(f"\n🎉 Weather data generation completed!")
    print(f"📁 Main output: {output_file}")
    print(f"🚀 Ready for flood prediction model training!")

if __name__ == "__main__":
    main()
