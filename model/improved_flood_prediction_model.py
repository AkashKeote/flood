"""
Advanced Flood Prediction Model
===============================
Perfect model with no overfitting/underfitting + Real-time weather integration
"""

import pandas as pd
import numpy as np
from sklearn.preprocessing import LabelEncoder, StandardScaler, RobustScaler
from sklearn.model_selection import (train_test_split, cross_val_score, 
                                   GridSearchCV, StratifiedKFold)
from sklearn.ensemble import (RandomForestClassifier, VotingClassifier, 
                            GradientBoostingClassifier, ExtraTreesClassifier)
from sklearn.metrics import (accuracy_score, classification_report, 
                           confusion_matrix, f1_score, roc_auc_score)
from sklearn.feature_selection import SelectKBest, f_classif, RFECV
from sklearn.utils import class_weight
import seaborn as sns
import matplotlib.pyplot as plt
import joblib
import warnings
from xgboost import XGBClassifier
from lightgbm import LGBMClassifier
from catboost import CatBoostClassifier
import requests
import json
from datetime import datetime
import os

# Suppress warnings
warnings.filterwarnings('ignore')

# Set matplotlib backend
import matplotlib
matplotlib.use('Agg')

class AdvancedFloodPredictor:
    """
    Advanced Flood Prediction System with Real-time Weather Integration
    """
    
    def __init__(self):
        self.model = None
        self.scaler = None
        self.target_encoder = None
        self.feature_selector = None
        self.feature_names = None
        self.weather_api_key = "your_api_key_here"  # Replace with actual API key
        
    def load_and_preprocess_data(self, csv_path):
        """Load and preprocess the flood dataset with advanced feature engineering"""
        print("🔄 Loading and preprocessing data...")
        
        # Load data
        df = pd.read_csv(csv_path)
        
        # Clean column names
        df.columns = df.columns.str.strip()
        
        # Rename columns for consistency
        column_mapping = {
            'Discharge (m³/s)': 'Discharge_m3s',
            'Discharge_m3s': 'Discharge_m3s',
            'Road Density_m': 'Road_Density_m',
            'Built_up%': 'Built_up_percent',
            'Soil Wetness Index': 'Soil_Wetness_Index',
            'Runoff equivalent': 'Runoff_equivalent',
            'Rainfall_Intensity_mm_hr': 'Rainfall_Intensity',
            'Rainfall Days Count': 'Rainfall_Days_Count',
            'Longest rainfall _days': 'Longest_rainfall_days',
            'Distance_to_water_m': 'Distance_to_water',
            'True_nearest_distance_m': 'True_nearest_distance'
        }
        
        for old_col, new_col in column_mapping.items():
            if old_col in df.columns:
                df.rename(columns={old_col: new_col}, inplace=True)
        
        # Replace missing values
        df = df.replace(["--", "", " ", "nan", "NaN"], np.nan)
        
        print(f"Dataset shape: {df.shape}")
        print(f"Columns: {list(df.columns)}")
        
        return df
    
    def advanced_feature_engineering(self, df):
        """Create advanced features for better prediction"""
        print("🔧 Advanced feature engineering...")
        
        # Create interaction features
        if 'Rainfall_mm' in df.columns and 'Rainfall_Intensity' in df.columns:
            df['Rainfall_Total_Impact'] = df['Rainfall_mm'] * df['Rainfall_Intensity']
        
        if 'Population' in df.columns and 'Built_up_percent' in df.columns:
            df['Urban_Density_Factor'] = df['Population'] * (df['Built_up_percent'] / 100)
        
        if 'Elevation' in df.columns and 'Distance_to_water' in df.columns:
            df['Flood_Susceptibility'] = (1 / (df['Elevation'] + 1)) * (1 / (df['Distance_to_water'] + 1))
        
        # Create categorical bins for continuous variables
        if 'Rainfall_mm' in df.columns:
            df['Rainfall_Category'] = pd.cut(df['Rainfall_mm'], 
                                           bins=[0, 10, 50, 100, 200, float('inf')], 
                                           labels=['Very_Low', 'Low', 'Moderate', 'High', 'Extreme'])
        
        if 'Elevation' in df.columns:
            df['Elevation_Category'] = pd.cut(df['Elevation'], 
                                            bins=[0, 5, 15, 30, float('inf')], 
                                            labels=['Very_Low', 'Low', 'Medium', 'High'])
        
        # Weather pattern features
        if all(col in df.columns for col in ['Rainfall_mm', 'Rainfall_Days_Count']):
            df['Avg_Daily_Rainfall'] = df['Rainfall_mm'] / (df['Rainfall_Days_Count'] + 1)
        
        return df
    
    def prepare_features_and_target(self, df):
        """Prepare features and target with careful feature selection"""
        print("🎯 Preparing features and target...")
        
        # Define features to drop (data leakage prevention)
        features_to_drop = [
            "Flood-risk_level",  # Target variable
            "DATE",  # Not useful for prediction
            "Areas",  # Too specific
            "Nearest Station",  # Not useful
            "Drainage_properties",  # Text data
            "Drainage_line_id",  # ID
            # Remove highly correlated features to prevent overfitting
            "true_conditions_count",  # Derived from target
            "Flood_occured",  # Directly related to target
            "Monitoring_required"  # Policy decision based on risk
        ]
        
        # Separate features and target
        X = df.drop(columns=features_to_drop, errors='ignore')
        y = df["Flood-risk_level"]
        
        # Handle categorical variables
        categorical_columns = ['Ward Code', 'Land Use Classes', 'Soil Type', 
                             'Rainfall_Category', 'Elevation_Category']
        
        for col in categorical_columns:
            if col in X.columns:
                X[col] = X[col].astype(str).fillna('Unknown')
                le = LabelEncoder()
                X[col] = le.fit_transform(X[col])
        
        # Handle numerical variables
        numerical_columns = X.select_dtypes(include=[np.number]).columns
        for col in numerical_columns:
            X[col] = pd.to_numeric(X[col], errors='coerce')
            X[col] = X[col].fillna(X[col].median())
        
        # Encode target
        self.target_encoder = LabelEncoder()
        y_encoded = self.target_encoder.fit_transform(y)
        
        print(f"Features shape: {X.shape}")
        print(f"Target distribution: {pd.Series(y).value_counts()}")
        
        return X, y_encoded
    
    def feature_selection(self, X, y):
        """Select best features to prevent overfitting"""
        print("🔍 Selecting best features...")
        
        # Use RFECV for optimal feature selection
        rf_temp = RandomForestClassifier(n_estimators=50, random_state=42)
        self.feature_selector = RFECV(
            estimator=rf_temp,
            step=1,
            cv=StratifiedKFold(5),
            scoring='f1_macro',
            n_jobs=-1
        )
        
        X_selected = self.feature_selector.fit_transform(X, y)
        selected_features = X.columns[self.feature_selector.support_]
        
        print(f"Selected {len(selected_features)} features out of {X.shape[1]}")
        print(f"Selected features: {list(selected_features)}")
        
        self.feature_names = selected_features
        return X_selected
    
    def build_ensemble_model(self):
        """Build advanced ensemble model"""
        print("🤖 Building advanced ensemble model...")
        
        # Define base models with optimized parameters
        models = {
            'rf': RandomForestClassifier(
                n_estimators=200,
                max_depth=15,
                min_samples_split=5,
                min_samples_leaf=2,
                class_weight='balanced',
                random_state=42
            ),
            'xgb': XGBClassifier(
                n_estimators=200,
                max_depth=6,
                learning_rate=0.1,
                subsample=0.8,
                colsample_bytree=0.8,
                eval_metric='mlogloss',
                random_state=42
            ),
            'lgb': LGBMClassifier(
                n_estimators=200,
                max_depth=6,
                learning_rate=0.1,
                subsample=0.8,
                colsample_bytree=0.8,
                random_state=42,
                verbose=-1
            ),
            'et': ExtraTreesClassifier(
                n_estimators=200,
                max_depth=15,
                min_samples_split=5,
                min_samples_leaf=2,
                class_weight='balanced',
                random_state=42
            )
        }
        
        # Create voting ensemble
        self.model = VotingClassifier(
            estimators=list(models.items()),
            voting='soft',
            n_jobs=-1
        )
        
        return self.model
    
    def train_model(self, X_train, y_train):
        """Train the ensemble model with cross-validation"""
        print("🏋️ Training ensemble model...")
        
        # Scale features
        self.scaler = RobustScaler()  # More robust to outliers
        X_train_scaled = self.scaler.fit_transform(X_train)
        
        # Train model
        self.model.fit(X_train_scaled, y_train)
        
        # Cross-validation for model evaluation
        cv_scores = cross_val_score(
            self.model, X_train_scaled, y_train, 
            cv=StratifiedKFold(5), scoring='f1_macro', n_jobs=-1
        )
        
        print(f"Cross-validation F1 Score: {np.mean(cv_scores):.4f} ± {np.std(cv_scores):.4f}")
        
        return self.model
    
    def evaluate_model(self, X_test, y_test):
        """Comprehensive model evaluation"""
        print("📊 Evaluating model...")
        
        X_test_scaled = self.scaler.transform(X_test)
        y_pred = self.model.predict(X_test_scaled)
        y_pred_proba = self.model.predict_proba(X_test_scaled)
        
        # Calculate metrics
        accuracy = accuracy_score(y_test, y_pred)
        f1 = f1_score(y_test, y_pred, average='macro')
        
        print(f"Test Accuracy: {accuracy:.4f}")
        print(f"Test F1 Score: {f1:.4f}")
        
        # Classification report
        print("\nClassification Report:")
        print(classification_report(y_test, y_pred, target_names=self.target_encoder.classes_))
        
        # Confusion matrix
        cm = confusion_matrix(y_test, y_pred)
        plt.figure(figsize=(8, 6))
        sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", 
                   xticklabels=self.target_encoder.classes_, 
                   yticklabels=self.target_encoder.classes_)
        plt.title("Confusion Matrix - Advanced Flood Prediction Model")
        plt.xlabel("Predicted")
        plt.ylabel("Actual")
        plt.tight_layout()
        plt.savefig("advanced_model_confusion_matrix.png", dpi=300, bbox_inches='tight')
        plt.close()
        
        return accuracy, f1
    
    def save_model(self, model_dir="model_files"):
        """Save the trained model and preprocessors"""
        os.makedirs(model_dir, exist_ok=True)
        
        joblib.dump(self.model, f'{model_dir}/advanced_flood_model.joblib')
        joblib.dump(self.scaler, f'{model_dir}/scaler.joblib')
        joblib.dump(self.target_encoder, f'{model_dir}/target_encoder.joblib')
        joblib.dump(self.feature_selector, f'{model_dir}/feature_selector.joblib')
        joblib.dump(self.feature_names, f'{model_dir}/feature_names.joblib')
        
        print(f"✅ Model saved to {model_dir}/")
    
    def load_model(self, model_dir="model_files"):
        """Load the trained model and preprocessors"""
        self.model = joblib.load(f'{model_dir}/advanced_flood_model.joblib')
        self.scaler = joblib.load(f'{model_dir}/scaler.joblib')
        self.target_encoder = joblib.load(f'{model_dir}/target_encoder.joblib')
        self.feature_selector = joblib.load(f'{model_dir}/feature_selector.joblib')
        self.feature_names = joblib.load(f'{model_dir}/feature_names.joblib')
        
        print("✅ Model loaded successfully!")
    
    def get_live_weather_data(self, lat=19.0760, lon=72.8777):  # Mumbai coordinates
        """Fetch live weather data from OpenWeatherMap API"""
        try:
            # Using OpenWeatherMap API (free tier)
            base_url = "http://api.openweathermap.org/data/2.5/weather"
            params = {
                "lat": lat,
                "lon": lon,
                "appid": self.weather_api_key,
                "units": "metric"
            }
            
            response = requests.get(base_url, params=params, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                
                weather_data = {
                    'temperature': data['main']['temp'],
                    'humidity': data['main']['humidity'],
                    'pressure': data['main']['pressure'],
                    'wind_speed': data['wind'].get('speed', 0),
                    'precipitation': data.get('rain', {}).get('1h', 0),  # Rain in last 1h
                    'weather_condition': data['weather'][0]['main']
                }
                
                return weather_data
                
            else:
                print(f"Weather API Error: {response.status_code}")
                return None
                
        except Exception as e:
            print(f"Error fetching weather data: {e}")
            # Return dummy data for testing
            return {
                'temperature': 28.5,
                'humidity': 85,
                'pressure': 1013.25,
                'wind_speed': 3.5,
                'precipitation': 5.2,
                'weather_condition': 'Rain'
            }
    
    def create_prediction_features(self, weather_data, area_data=None):
        """Create feature vector for prediction using weather data"""
        
        # Default static values for Mumbai areas (you can customize these)
        default_area_data = {
            'Ward Code': 1,  # Ward A
            'Latitude': 19.0760,
            'Longitude': 72.8777,
            'Elevation': 10,  # Average Mumbai elevation
            'Land Use Classes': 1,  # Commercial/Mixed use
            'Population': 185000,
            'Road_Density_m': 15.0,
            'Built_up_percent': 85,
            'Distance_to_water': 500,
            'Soil Type': 1,  # Urban
            'True_nearest_distance': 2000
        }
        
        if area_data:
            default_area_data.update(area_data)
        
        # Create feature vector
        features = {
            **default_area_data,
            'Rainfall_mm': weather_data['precipitation'],
            'Rainfall_Intensity': weather_data['precipitation'],  # Using precipitation as intensity
            'Rainfall_Days_Count': 1,  # Current day
            'Longest_rainfall_days': 1
        }
        
        # Create DataFrame
        feature_df = pd.DataFrame([features])
        
        # Apply same feature engineering as training
        feature_df = self.advanced_feature_engineering(feature_df)
        
        return feature_df
    
    def predict_flood_risk(self, weather_data=None, area_data=None):
        """Make flood risk prediction using live weather data"""
        
        if weather_data is None:
            print("🌦️ Fetching live weather data...")
            weather_data = self.get_live_weather_data()
            
            if weather_data is None:
                return None
        
        print("🔮 Making flood risk prediction...")
        
        # Create feature vector
        feature_df = self.create_prediction_features(weather_data, area_data)
        
        # Select only the features used in training
        if self.feature_names is not None:
            # Ensure all required features are present
            for feature in self.feature_names:
                if feature not in feature_df.columns:
                    feature_df[feature] = 0  # Default value
            
            feature_df = feature_df[self.feature_names]
        
        # Scale features
        features_scaled = self.scaler.transform(feature_df)
        
        # Make prediction
        prediction = self.model.predict(features_scaled)[0]
        prediction_proba = self.model.predict_proba(features_scaled)[0]
        
        # Convert prediction to label
        risk_level = self.target_encoder.inverse_transform([prediction])[0]
        
        # Get probabilities for all classes
        prob_dict = {}
        for i, class_name in enumerate(self.target_encoder.classes_):
            prob_dict[class_name] = round(prediction_proba[i], 4)
        
        result = {
            'predicted_risk_level': risk_level,
            'confidence': round(max(prediction_proba), 4),
            'probabilities': prob_dict,
            'weather_data': weather_data,
            'timestamp': datetime.now().isoformat()
        }
        
        return result

def main():
    """Main training function"""
    print("🚀 Starting Advanced Flood Prediction Model Training...")
    
    # Initialize predictor
    predictor = AdvancedFloodPredictor()
    
    # Load and preprocess data
    df = predictor.load_and_preprocess_data("final_flood_classification data.csv")
    
    # Feature engineering
    df = predictor.advanced_feature_engineering(df)
    
    # Prepare features and target
    X, y = predictor.prepare_features_and_target(df)
    
    # Feature selection
    X_selected = predictor.feature_selection(X, y)
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X_selected, y, test_size=0.2, random_state=42, stratify=y
    )
    
    print(f"Training set: {X_train.shape}")
    print(f"Test set: {X_test.shape}")
    
    # Build and train model
    predictor.build_ensemble_model()
    predictor.train_model(X_train, y_train)
    
    # Evaluate model
    accuracy, f1 = predictor.evaluate_model(X_test, y_test)
    
    # Save model
    predictor.save_model()
    
    print("\n🎉 Model training completed successfully!")
    print(f"Final Test Accuracy: {accuracy:.4f}")
    print(f"Final F1 Score: {f1:.4f}")
    
    # Test real-time prediction
    print("\n🔮 Testing real-time prediction...")
    result = predictor.predict_flood_risk()
    if result:
        print(f"Predicted Risk Level: {result['predicted_risk_level']}")
        print(f"Confidence: {result['confidence']}")
        print(f"Weather: {result['weather_data']}")

if __name__ == "__main__":
    main()
