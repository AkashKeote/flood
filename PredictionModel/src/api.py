import os
import json
import time
import datetime
from typing import Optional, Dict, Any

import numpy as np
import pandas as pd
import joblib
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

try:
    from rapidfuzz import process as fuzzy_process
except Exception:
    fuzzy_process = None


# ---------- Paths ----------
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(CURRENT_DIR, "models")
DATA_DIR = os.path.join(CURRENT_DIR, "data")


# ---------- Load Model Artifacts ----------
MODEL = joblib.load(os.path.join(MODELS_DIR, "enhanced_ensemble_model.pkl"))
SCALER = joblib.load(os.path.join(MODELS_DIR, "enhanced_ensemble_scaler.pkl"))
TARGET_ENCODER = joblib.load(os.path.join(MODELS_DIR, "enhanced_ensemble_encoder.pkl"))
REQUIRED_FEATURES = joblib.load(os.path.join(MODELS_DIR, "enhanced_ensemble_features.pkl"))

# Label encoders are optional
LABEL_ENCODERS_PATH = os.path.join(MODELS_DIR, "enhanced_ensemble_label_encoders.pkl")
if os.path.exists(LABEL_ENCODERS_PATH):
    LABEL_ENCODERS: Dict[str, Any] = joblib.load(LABEL_ENCODERS_PATH)
else:
    LABEL_ENCODERS = {}


# ---------- Load Data ----------
TRAIN_CSV = os.path.join(DATA_DIR, "final_flood_classification data.csv")
FORECAST_CSV = os.path.join(DATA_DIR, "mumbai_combined_weather_data.csv")

df_train = pd.read_csv(TRAIN_CSV)
if " Population" in df_train.columns:
    df_train = df_train.rename(columns={" Population": "Population"})

df_forecast = pd.read_csv(FORECAST_CSV)
if "Area" in df_forecast.columns and "Areas" not in df_forecast.columns:
    df_forecast = df_forecast.rename(columns={"Area": "Areas"})

AREAS = sorted(df_forecast["Areas"].astype(str).unique().tolist())
_normalized_forecast = {a.strip().lower(): a for a in AREAS}


# ---------- Precompute medians for missing fill ----------
medians: Dict[str, float] = {}
for col in REQUIRED_FEATURES:
    if col in df_train.columns and df_train[col].dtype in ["int64", "float64"]:
        medians[col] = pd.to_numeric(df_train[col], errors="coerce").median()


# ---------- Helpers ----------
def fuzzy_match_area(name: str) -> Optional[tuple[str, float]]:
    if not name:
        return None
    key = name.strip().lower()
    if key in _normalized_forecast:
        return _normalized_forecast[key], 100.0
    if fuzzy_process is None:
        # simple fallback
        best = None
        for cand in _normalized_forecast.keys():
            if cand in key or key in cand:
                best = ( _normalized_forecast[cand], 80.0 )
                break
        return best
    choices = list(_normalized_forecast.keys())
    res = fuzzy_process.extractOne(key, choices)
    if res is None:
        return None
    return _normalized_forecast[res[0]], float(res[1])


def _encode_categoricals(row: pd.Series) -> pd.Series:
    for col, le in LABEL_ENCODERS.items():
        if col in row.index:
            val = "Unknown" if pd.isna(row[col]) else str(row[col])
            try:
                row[col] = le.transform([val])[0]
            except Exception:
                try:
                    row[col] = le.transform(["Unknown"])[0]
                except Exception:
                    row[col] = 0
    return row


def prepare_features(area_name: str, forecast_row: Dict[str, Any]) -> pd.DataFrame:
    row = pd.Series({c: np.nan for c in REQUIRED_FEATURES})
    
    if "Areas" in REQUIRED_FEATURES:
        row["Areas"] = area_name
    
    # Copy overlapping cols
    for col in REQUIRED_FEATURES:
        if col in forecast_row:
            row[col] = forecast_row.get(col)

    # rainfall alias mapping
    rainfall_target = None
    for candidate in REQUIRED_FEATURES:
        if "rain" in candidate.lower():
            rainfall_target = candidate
            break
    if rainfall_target is not None:
        for rf in ["Rainfall_mm", "Rainfall (mm)", "Rainfall", "rainfall"]:
            if rf in forecast_row:
                row[rainfall_target] = forecast_row.get(rf)
                break
    
    # encode categoricals
    row = _encode_categoricals(row)
    
    # fill and coerce numerics
    for col in REQUIRED_FEATURES:
        if pd.isna(row.get(col)):
            row[col] = medians.get(col, 0)
        if col not in LABEL_ENCODERS:
            try:
                row[col] = pd.to_numeric(row[col])
            except Exception:
                pass

    return pd.DataFrame([[row.get(c, 0) for c in REQUIRED_FEATURES]], columns=REQUIRED_FEATURES)


def predict_risk(df_features: pd.DataFrame) -> tuple[str, float]:
    try:
        Xs = SCALER.transform(df_features)
        pred = MODEL.predict(Xs)
        if hasattr(MODEL, "predict_proba"):
            proba = MODEL.predict_proba(Xs)[0]
            # Use probability margin (top1 - top2) as confidence for better calibration
            sorted_probs = np.sort(proba)[::-1]
            top1 = float(sorted_probs[0]) if len(sorted_probs) > 0 else 0.0
            top2 = float(sorted_probs[1]) if len(sorted_probs) > 1 else 0.0
            conf = max(0.0, min(1.0, top1 - top2))
        else:
            conf = 0.8
        risk = TARGET_ENCODER.inverse_transform(pred)[0]
        return str(risk), conf
    except Exception:
        return "Unknown", 0.0


# ---------- FastAPI ----------
app = FastAPI(title="Flood Prediction API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)


class PredictionResponse(BaseModel):
    area: str
    date: str
    flood_risk: str
    confidence: float
    matched_area: str | None = None
    match_score: float | None = None


@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "status": "healthy",
        "timestamp": datetime.datetime.now().isoformat(),
        "model_features": len(REQUIRED_FEATURES),
        "areas": len(AREAS),
    }


@app.get("/areas")
def get_areas() -> Dict[str, Any]:
    return {"areas": AREAS, "total": len(AREAS)}


@app.get("/predict", response_model=PredictionResponse)
def predict(area: str = Query(...)):
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    match = fuzzy_match_area(area)
    if not match:
        return PredictionResponse(
            area=area, 
            date=today,
            flood_risk="Unknown",
            confidence=0.0,
            matched_area=None, 
            match_score=0.0,
        )

    matched_area, score = match
    rows = df_forecast[df_forecast["Areas"].astype(str).str.strip().str.lower() == matched_area.strip().lower()]
    if rows.empty:
        return PredictionResponse(
            area=area, 
            date=today,
            flood_risk="Unknown",
            confidence=0.0,
            matched_area=matched_area, 
            match_score=score,
        )
    
    forecast_row = rows.iloc[-1].to_dict()
    feats = prepare_features(matched_area, forecast_row)
    risk, conf = predict_risk(feats)

    return PredictionResponse(
            area=area, 
        date=today,
            flood_risk=risk,
        confidence=round(float(conf), 3),
            matched_area=matched_area, 
        match_score=float(score),
    )


@app.post("/update-csv")
def update_csv(area: str = Query(...), risk_level: str = Query(...)):
    """Update CSV file with new flood risk level for an area"""
    try:
        # Path to the CSV file
        csv_path = os.path.join(CURRENT_DIR, "..", "..", "evacuation", "mumbai_ward_area_floodrisk_all_102.csv")
        
        if not os.path.exists(csv_path):
            return {"success": False, "error": f"CSV file not found at {csv_path}"}
        
        # Read CSV
        df = pd.read_csv(csv_path)
        
        # Normalize risk level - keep Moderate as Moderate
        if risk_level.lower() == 'moderate':
            risk_level = 'Moderate'
        else:
            risk_level = risk_level.capitalize()
            if risk_level not in ['Low', 'Moderate', 'High']:
                risk_level = 'Moderate'
        
        # Find and update the area - prioritize exact matches
        updated = False
        print(f"DEBUG: Looking for area: '{area}'")
        
        # First, try exact match
        for idx, row in df.iterrows():
            csv_area = str(row.get('Areas', '')).strip()
            if csv_area.lower() == area.lower():
                old_risk = row.get('Flood-risk_level', 'Unknown')
                df.at[idx, 'Flood-risk_level'] = risk_level
                updated = True
                print(f"Updated {csv_area}: {old_risk} -> {risk_level}")
                break
        
        # If no exact match, try partial matches with fuzzy logic
        if not updated:
            best_match = None
            best_score = 0
            
            for idx, row in df.iterrows():
                csv_area = str(row.get('Areas', '')).strip()
                
                # Basic contains matching
                if (area.lower() in csv_area.lower() or 
                    csv_area.lower() in area.lower()):
                    score = max(len(area.lower()) / len(csv_area.lower()), 
                               len(csv_area.lower()) / len(area.lower()))
                    if score > best_score:
                        best_match = (idx, csv_area, score)
                        best_score = score
                
                # Handle common word substitutions (Highway/Lowway, etc.)
                area_normalized = area.lower().replace('highway', 'lowway').replace('lowway', 'highway')
                if (area_normalized in csv_area.lower() or 
                    csv_area.lower() in area_normalized):
                    score = 0.9  # High score for word substitution matches
                    if score > best_score:
                        best_match = (idx, csv_area, score)
                        best_score = score
                
                # Fuzzy matching if available
                if fuzzy_process:
                    try:
                        match_result = fuzzy_process.extractOne(area, [csv_area])
                        if match_result:
                            _, fuzzy_score = match_result
                            if fuzzy_score > 80 and (fuzzy_score / 100) > best_score:
                                best_match = (idx, csv_area, fuzzy_score / 100)
                                best_score = fuzzy_score / 100
                    except:
                        pass  # Skip fuzzy matching if it fails
            
            if best_match and best_score > 0.5:  # At least 50% similarity required
                idx, csv_area, score = best_match
                old_risk = df.iloc[idx].get('Flood-risk_level', 'Unknown')
                df.at[idx, 'Flood-risk_level'] = risk_level
                updated = True
                print(f"Updated {csv_area}: {old_risk} -> {risk_level} (match score: {score:.2f})")
        
        if updated:
            # Save the CSV
            df.to_csv(csv_path, index=False)
            return {
                "success": True, 
                "message": f"Updated {area} to {risk_level}",
                "csv_path": csv_path
            }
        else:
            return {
                "success": False, 
                "error": f"Area '{area}' not found in CSV"
            }
            
    except Exception as e:
        return {"success": False, "error": str(e)}


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", "7860"))
    uvicorn.run(app, host="127.0.0.1", port=port)


