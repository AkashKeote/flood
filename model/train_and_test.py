"""
Simple Training and Testing Script
================================
Run this after installing required packages to train and test the model
"""

import sys
import os

try:
    # Import required libraries
    import pandas as pd
    import numpy as np
    from sklearn.preprocessing import LabelEncoder, RobustScaler
    from sklearn.model_selection import train_test_split, cross_val_score, StratifiedKFold
    from sklearn.ensemble import RandomForestClassifier, VotingClassifier, ExtraTreesClassifier
    from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score
    from sklearn.feature_selection import RFECV
    import matplotlib.pyplot as plt
    import seaborn as sns
    import joblib
    import warnings
    
    print("✅ All required libraries imported successfully!")
    
except ImportError as e:
    print(f"❌ Missing required library: {e}")
    print("\nPlease install required packages:")
    print("pip install pandas numpy scikit-learn matplotlib seaborn joblib")
    sys.exit(1)

warnings.filterwarnings('ignore')

class SimpleFloodPredictor:
    """Simplified version for easy training and testing"""
    
    def __init__(self):
        self.model = None
        self.scaler = None
        self.target_encoder = None
        self.feature_names = None
    
    def load_data(self):
        """Load and preprocess the dataset"""
        print("📊 Loading dataset...")
        
        try:
            df = pd.read_csv("final_flood_classification data.csv")
            print(f"Dataset loaded: {df.shape}")
            
            # Clean column names
            df.columns = df.columns.str.strip()
            
            # Basic preprocessing
            df = df.replace(["--", "", " ", "nan", "NaN"], np.nan)
            
            return df
            
        except FileNotFoundError:
            print("❌ Dataset file 'final_flood_classification data.csv' not found!")
            print("Please ensure the CSV file is in the model directory.")
            return None
    
    def prepare_data(self, df):
        """Prepare features and target"""
        print("🔧 Preparing features and target...")
        
        # Define features to drop
        features_to_drop = [
            "Flood-risk_level", "DATE", "Areas", "Nearest Station", 
            "Drainage_properties", "Drainage_line_id",
            "true_conditions_count", "Flood_occured", "Monitoring_required"
        ]
        
        # Separate features and target
        X = df.drop(columns=features_to_drop, errors='ignore')
        y = df["Flood-risk_level"]
        
        # Handle categorical variables
        categorical_columns = ['Ward Code', 'Land Use Classes', 'Soil Type']
        
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
        print(f"Target classes: {self.target_encoder.classes_}")
        
        return X, y_encoded
    
    def train_model(self, X, y):
        """Train the model"""
        print("🤖 Training model...")
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        # Scale features
        self.scaler = RobustScaler()
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        # Create ensemble model
        models = [
            ('rf', RandomForestClassifier(n_estimators=100, max_depth=15, 
                                        class_weight='balanced', random_state=42)),
            ('et', ExtraTreesClassifier(n_estimators=100, max_depth=15, 
                                      class_weight='balanced', random_state=42))
        ]
        
        self.model = VotingClassifier(estimators=models, voting='soft')
        
        # Train model
        self.model.fit(X_train_scaled, y_train)
        
        # Evaluate
        y_pred = self.model.predict(X_test_scaled)
        accuracy = accuracy_score(y_test, y_pred)
        f1 = f1_score(y_test, y_pred, average='macro')
        
        print(f"✅ Model trained!")
        print(f"Test Accuracy: {accuracy:.4f}")
        print(f"Test F1 Score: {f1:.4f}")
        
        # Classification report
        print("\nClassification Report:")
        print(classification_report(y_test, y_pred, target_names=self.target_encoder.classes_))
        
        # Save feature names
        self.feature_names = X.columns
        
        return accuracy, f1
    
    def save_model(self):
        """Save the trained model"""
        print("💾 Saving model...")
        
        os.makedirs("model_files", exist_ok=True)
        
        joblib.dump(self.model, "model_files/flood_model.joblib")
        joblib.dump(self.scaler, "model_files/scaler.joblib")
        joblib.dump(self.target_encoder, "model_files/target_encoder.joblib")
        joblib.dump(self.feature_names, "model_files/feature_names.joblib")
        
        print("✅ Model saved to model_files/")
    
    def test_prediction(self):
        """Test prediction with sample data"""
        print("\n🔮 Testing prediction...")
        
        # Sample weather data for testing
        sample_data = {
            'Ward Code': 1,
            'Latitude': 19.0760,
            'Longitude': 72.8777,
            'Rainfall_mm': 25.5,  # Heavy rain
            'Elevation': 10,
            'Land Use Classes': 1,
            'Population': 185000,
            'Road Density_m': 15.0,
            'Built_up%': 85,
            'Rainfall_Intensity_mm_hr': 8.5,
            'Rainfall Days Count': 2,
            'Longest rainfall _days': 2,
            'Distance_to_water_m': 500,
            'Soil Type': 1,
            'True_nearest_distance_m': 2000
        }
        
        # Create DataFrame
        test_df = pd.DataFrame([sample_data])
        
        # Process same as training
        for col in ['Ward Code', 'Land Use Classes', 'Soil Type']:
            if col in test_df.columns:
                test_df[col] = test_df[col].astype(str)
        
        # Select features used in training
        test_features = test_df[self.feature_names]
        
        # Scale and predict
        test_scaled = self.scaler.transform(test_features)
        prediction = self.model.predict(test_scaled)[0]
        probabilities = self.model.predict_proba(test_scaled)[0]
        
        # Convert prediction
        risk_level = self.target_encoder.inverse_transform([prediction])[0]
        confidence = max(probabilities)
        
        print(f"Sample Prediction:")
        print(f"  Input: Heavy rain (25.5mm) in Mumbai")
        print(f"  Predicted Risk Level: {risk_level}")
        print(f"  Confidence: {confidence:.4f}")
        
        # Show probabilities for all classes
        prob_dict = {}
        for i, class_name in enumerate(self.target_encoder.classes_):
            prob_dict[class_name] = round(probabilities[i], 4)
        print(f"  All Probabilities: {prob_dict}")

def main():
    """Main function"""
    print("🌊 Simple Flood Prediction Model Training")
    print("=" * 50)
    
    # Initialize predictor
    predictor = SimpleFloodPredictor()
    
    # Load data
    df = predictor.load_data()
    if df is None:
        return
    
    # Prepare data
    X, y = predictor.prepare_data(df)
    
    # Train model
    accuracy, f1 = predictor.train_model(X, y)
    
    # Save model
    predictor.save_model()
    
    # Test prediction
    predictor.test_prediction()
    
    print("\n🎉 Training completed successfully!")
    print(f"Final Accuracy: {accuracy:.4f}")
    print(f"Final F1 Score: {f1:.4f}")
    
    print("\n📋 Next Steps:")
    print("1. Model files are saved in 'model_files/' directory")
    print("2. You can now run the API server: python flood_prediction_api.py")
    print("3. For Flutter integration, use the API endpoints")

if __name__ == "__main__":
    main()
