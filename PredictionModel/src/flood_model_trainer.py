import pandas as pd
import numpy as np
import joblib
from sklearn.ensemble import VotingClassifier, RandomForestClassifier, GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import train_test_split, cross_val_score, GridSearchCV
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, precision_score, recall_score, f1_score
from sklearn.utils import class_weight
import xgboost as xgb
from xgboost import XGBClassifier
import seaborn as sns
import matplotlib.pyplot as plt
from datetime import datetime
import warnings
import os

# Set the matplotlib backend to Agg to prevent TclError
import matplotlib
matplotlib.use('Agg')

warnings.filterwarnings('ignore')

class EnhancedFloodPredictor:
    def __init__(self):
        self.models = {}
        self.scaler = StandardScaler()
        self.target_encoder = LabelEncoder()
        self.feature_names = []
        self.results = {}
        
    def load_training_data(self):
        """Load final flood classification data for training (REAL flood data)"""
        print("🔄 Loading REAL flood training data...")
        
        # Load the real flood classification data
        training_path = os.path.join("data", "final_flood_classification data.csv")
        if not os.path.exists(training_path):
            print("❌ Final flood classification data not found!")
            return None
            
        print("📊 Loading final_flood_classification data.csv...")
        self.training_df = pd.read_csv(training_path)
        print(f"   Training records: {len(self.training_df)}")
        print(f"   Training columns: {len(self.training_df.columns)}")
        
        # Check target variable
        if 'Flood-risk_level' in self.training_df.columns:
            print("✅ Real flood risk target found!")
            print("📊 Target distribution:")
            print(self.training_df['Flood-risk_level'].value_counts())
        else:
            print("❌ No target variable found!")
            return None
            
        return self.training_df
    
    def load_testing_data(self):
        """Load combined weather data for testing (NEW real weather data)"""
        print("🔄 Loading NEW weather testing data...")
        
        # Load combined weather data  
        testing_path = os.path.join("data", "mumbai_combined_weather_data.csv")
        if not os.path.exists(testing_path):
            print("❌ Combined weather data not found!")
            return None
            
        print("📊 Loading mumbai_combined_weather_data.csv...")
        self.testing_df = pd.read_csv(testing_path)
        print(f"   Testing records: {len(self.testing_df)}")
        print(f"   Testing columns: {len(self.testing_df.columns)}")
        
        return self.testing_df
    
    def prepare_training_features(self):
        """Prepare features with enhanced preprocessing"""
        print("🔧 Enhanced feature preparation from REAL flood data...")
        
        # Make a copy to avoid modifying original
        df = self.training_df.copy()
        
        # Correct column names with leading spaces
        if ' Population' in df.columns:
            df.rename(columns={' Population': 'Population'}, inplace=True)
        if 'Discharge (m³/s)' in df.columns:
            df.rename(columns={'Discharge (m³/s)': 'Discharge_m3s'}, inplace=True)
        
        # Replace '--' with NaN across the dataset
        df = df.replace("--", np.nan)
        
        # Enhanced feature dropping (avoiding data leakage)
        features_to_drop = [
            "Flood-risk_level",      # The target variable itself
            "DATE",                  # Irrelevant for prediction
            "true_conditions_count", # Highly correlated (leaky)
            "Soil Wetness Index",    # Highly correlated (leaky)
            "Runoff equivalent",     # Highly correlated (leaky)
            "Discharge_m3s",         # Highly correlated (leaky)
            "Flood_occured",         # Likely a direct cause of flood-risk
            "Monitoring_required",   # Likely decided based on flood-risk
            "Drainage_properties",
            "Drainage_line_id"
        ]
        
        # Drop unnecessary columns
        # df = df.drop(columns=["Areas", "Nearest Station"], errors='ignore')  # Commented out to use these features
        
        # Get all features except dropped ones
        all_features = [col for col in df.columns if col not in features_to_drop]
        
        print(f"📋 Available features: {len(all_features)} total")
        print(f"🚫 Dropped features: {len(features_to_drop)}")
        
        # Handle categorical variables safely
        cat_cols = ["Ward Code", "Land Use Classes", "Road Density_m", "Soil Type", "Areas", "Nearest Station"]
        self.label_encoders = {}
        
        for col in cat_cols:
            if col in df.columns and col in all_features:
                df[col] = df[col].astype(str).fillna("Unknown")
                le = LabelEncoder()
                df[col] = le.fit_transform(df[col])
                self.label_encoders[col] = le
                print(f"✅ Encoded categorical feature: {col}")
            else:
                if col in cat_cols:
                    print(f"⚠️ Warning: Column '{col}' not found in DataFrame.")
        
        # Note: 'Longest rainfall _days' feature removed as it's not available in dataset
        print("ℹ️ Skipping 'Longest rainfall _days' feature (not available in dataset)")
        
        # Create interaction features for better performance
        if 'Rainfall (mm)' in df.columns and 'Elevation (m)' in df.columns:
            df['Rainfall_Elevation_Interaction'] = df['Rainfall (mm)'] * df['Elevation (m)']
            print("✅ Created Rainfall × Elevation interaction feature")
        
        if 'Rainfall (mm)' in df.columns and 'Population' in df.columns:
            df['Rainfall_Population_Interaction'] = df['Rainfall (mm)'] * df['Population']
            print("✅ Created Rainfall × Population interaction feature")
        
        if 'Rainfall (mm)' in df.columns and 'Distance_to_water (m)' in df.columns:
            df['Rainfall_Distance_Interaction'] = df['Rainfall (mm)'] * df['Distance_to_water (m)']
            print("✅ Created Rainfall × Distance interaction feature")
        
        # Create composite risk indicators
        if 'Built_up%' in df.columns and 'Population' in df.columns:
            df['Urban_Impact_Score'] = (df['Built_up%'] * 0.7) + (df['Population'] / 1000 * 0.3)
            print("✅ Created Urban Impact Score")
        
        if 'Rainfall (mm)' in df.columns and 'Elevation (m)' in df.columns and 'Distance_to_water (m)' in df.columns:
            df['Flood_Hazard_Index'] = (df['Rainfall (mm)'] * 0.5) + ((100 - df['Elevation (m)']) * 0.3) + ((1000 - df['Distance_to_water (m)']) * 0.2)
            print("✅ Created Flood Hazard Index")
        
        # Handle numeric columns (fill missing values)
        numeric_cols = []
        for col in df.select_dtypes(include=['float64', 'int64']).columns:
            if col in all_features:
                df[col] = pd.to_numeric(df[col], errors='coerce').fillna(df[col].median())
                numeric_cols.append(col)
        
        print(f"📊 Processed {len(numeric_cols)} numeric features")
        print(f"📊 Processed {len(self.label_encoders)} categorical features")
        
        # Feature/Target separation
        X_train = df[all_features].copy()
        y_train = self.target_encoder.fit_transform(df["Flood-risk_level"])
        
        # Store feature names
        self.feature_names = list(X_train.columns)
        
        print(f"🎯 Final training features: {len(self.feature_names)} total")
        print(f"📊 Training matrix shape: {X_train.shape}")
        print(f"🏷️ Target classes: {self.target_encoder.classes_}")
        
        return X_train, y_train
    
    def train_enhanced_models(self, X_train, y_train):
        """Train enhanced models with voting ensemble"""
        print("🚀 Training ENHANCED models with ensemble approach...")
        
        # Split data with fixed size for consistency
        X_tr, X_val, y_tr, y_val = train_test_split(
            X_train, y_train, train_size=4500, random_state=42, stratify=y_train
        )
        
        print(f"📊 Training set shape: {X_tr.shape}")
        print(f"📊 Validation set shape: {X_val.shape}")
        
        # Scale numeric features
        num_cols = X_tr.select_dtypes(include=['float64', 'int64']).columns
        scaler = StandardScaler()
        X_tr_scaled = X_tr.copy()
        X_val_scaled = X_val.copy()
        X_tr_scaled[num_cols] = scaler.fit_transform(X_tr[num_cols])
        X_val_scaled[num_cols] = scaler.transform(X_val[num_cols])
        
        # Store scaler
        self.scaler = scaler
        self.X_val = X_val_scaled
        self.y_val = y_val
        
        # Enhanced class weighting implementation
        print("📊 Implementing enhanced class weighting...")
        
        # Calculate class distribution
        class_counts = np.bincount(y_tr)
        total_samples = len(y_tr)
        n_classes = len(np.unique(y_tr))
        
        # Method 1: Balanced sample weights
        balanced_weights = class_weight.compute_sample_weight(class_weight='balanced', y=y_tr)
        
        # Method 2: Enhanced class weights for better balance
        class_weights = {}
        for i in range(n_classes):
            if class_counts[i] > 0:
                # Enhanced weighting: High=1.0, Low=2.5, Moderate=3.5
                if i == 0:  # High class (majority)
                    class_weights[i] = 1.0
                elif i == 1:  # Low class (minority)
                    class_weights[i] = 2.5
                else:  # Moderate class (minority)
                    class_weights[i] = 3.5
            else:
                class_weights[i] = 1.0

        # Method 3: Enhanced focal loss weighting
        focal_weights = np.ones_like(y_tr, dtype=float)
        for i in range(n_classes):
            class_mask = (y_tr == i)
            if class_counts[i] > 0:
                # Enhanced weighting for minority classes
                if i == 0:  # High class
                    weight = 1.0
                elif i == 1:  # Low class
                    weight = 2.0
                else:  # Moderate class
                    weight = 3.0
                focal_weights[class_mask] = weight

        # Use enhanced focal weights for better minority class handling
        sample_weights = focal_weights
        
        print(f"📊 Class distribution: {dict(zip(self.target_encoder.classes_, class_counts))}")
        print(f"📊 Class weights: {class_weights}")
        print(f"📊 Applied enhanced balanced sample weights")
        print(f"📊 Sample weight range: {sample_weights.min():.3f} - {sample_weights.max():.3f}")
        
        # Hyperparameter tuning for XGBoost
        print("🎯 Performing hyperparameter tuning for XGBoost...")
        
        # Define parameter grid for XGBoost
        xgb_param_grid = {
            'n_estimators': [50, 100],           # Reduce complexity
            'max_depth': [4, 5, 6],              # Reduce depth
            'learning_rate': [0.05, 0.1],        # Reduce learning rate
            'subsample': [0.7, 0.8],             # Add regularization
            'colsample_bytree': [0.7, 0.8],      # Add regularization
            'reg_alpha': [0.1, 0.5],             # L1 regularization
            'reg_lambda': [1.0, 2.0]             # L2 regularization
        }
        
        # Create base XGBoost model
        base_xgb = XGBClassifier(
            use_label_encoder=False, 
            eval_metric='mlogloss', 
            random_state=42,
            verbosity=0                  # Reduce output
        )
        
        # Perform grid search
        print("🔄 Running GridSearchCV for XGBoost...")
        grid_search = GridSearchCV(
            base_xgb, 
            xgb_param_grid, 
            cv=3,  # Reduced CV for speed
            scoring='accuracy',
            n_jobs=1,  # Windows compatible
            verbose=0
        )
        
        grid_search.fit(X_tr_scaled, y_tr, sample_weight=sample_weights)
        best_xgb = grid_search.best_estimator_
        
        print(f"✅ XGBoost hyperparameter tuning completed")
        print(f"   Best parameters: {grid_search.best_params_}")
        print(f"   Best CV score: {grid_search.best_score_:.4f}")
        
        # Define enhanced base models with tuned hyperparameters
        base_models = {
            'RandomForest': RandomForestClassifier(
                n_estimators=200,
                max_depth=8,
                min_samples_leaf=5,
                min_samples_split=10,
                class_weight=class_weights,
                random_state=42,
            ),
            'XGBoost': best_xgb,  # Use tuned XGBoost
            'GradientBoosting': GradientBoostingClassifier(
                n_estimators=200,
                max_depth=6,
                learning_rate=0.2,
                random_state=42,
            ),
        }
        
        # Train individual models and evaluate
        trained_models = {}
        for name, model in base_models.items():
            print(f"🔄 Training {name}...")
            
            # Fit with sample weights where supported
            if name == 'XGBoost':
                model.fit(X_tr_scaled, y_tr, sample_weight=sample_weights)
            else:
                model.fit(X_tr_scaled, y_tr)
            
            # Evaluate on validation set
            y_pred = model.predict(X_val_scaled)
            accuracy = accuracy_score(y_val, y_pred)
            
            # Cross-validation score (Windows compatible)
            cv_scores = cross_val_score(model, X_tr_scaled, y_tr, cv=5, n_jobs=1, scoring='accuracy')
            cv_accuracy = np.mean(cv_scores)
            
            trained_models[name] = model
            self.results[name] = {
                'accuracy': accuracy,
                'cv_accuracy': cv_accuracy,
                'predictions': y_pred
            }
            
            print(f"✅ {name} - Val Accuracy: {accuracy:.4f}, CV Accuracy: {cv_accuracy:.4f}")
        
        # Create enhanced voting ensemble
        print("🔄 Creating enhanced voting ensemble...")
        ensemble_estimators = [
            ('rf', trained_models['RandomForest']),
            ('xgb', trained_models['XGBoost']),
            ('gb', trained_models['GradientBoosting'])
        ]
        
        ensemble_model = VotingClassifier(
            estimators=ensemble_estimators,
            voting='soft',
            n_jobs=1
        )
        
        ensemble_model.fit(X_tr_scaled, y_tr)
        ensemble_pred = ensemble_model.predict(X_val_scaled)
        ensemble_accuracy = accuracy_score(y_val, ensemble_pred)
        
        # Ensemble cross-validation (Windows compatible)
        ensemble_cv_scores = cross_val_score(ensemble_model, X_tr_scaled, y_tr, cv=5, n_jobs=1, scoring='accuracy')
        ensemble_cv_accuracy = np.mean(ensemble_cv_scores)
        
        trained_models['Ensemble'] = ensemble_model
        self.results['Ensemble'] = {
            'accuracy': ensemble_accuracy,
            'cv_accuracy': ensemble_cv_accuracy,
            'predictions': ensemble_pred
        }
        
        print(f"✅ Ensemble - Val Accuracy: {ensemble_accuracy:.4f}, CV Accuracy: {ensemble_cv_accuracy:.4f}")
        
        # SHAP Analysis for model interpretability
        try:
            import shap
            print("\n🎨 Performing SHAP analysis for model interpretability...")
            
            # Use XGBoost for SHAP analysis (best model)
            best_model = trained_models['XGBoost']
            
            # Create SHAP explainer
            explainer = shap.TreeExplainer(best_model)
            
            # Fix: Use proper data format for SHAP
            X_val_subset = X_val_scaled[:100]  # Use subset for speed
            
            # For XGBoost, we need to handle the data properly
            if hasattr(X_val_subset, 'values'):
                X_val_subset = X_val_subset.values
            
            # Get SHAP values
            shap_values = explainer.shap_values(X_val_subset)
            
            # Handle multi-class SHAP values (XGBoost returns list for multi-class)
            if isinstance(shap_values, list):
                # For multi-class, use the first class (High risk) for analysis
                shap_values = shap_values[0]
            
            # Save SHAP values
            np.save('models/shap_values.npy', shap_values)
            
            # Feature importance from SHAP
            feature_importance = np.abs(shap_values).mean(0)
            feature_names = self.feature_names
            
            # Create feature importance DataFrame
            importance_df = pd.DataFrame({
                'feature': feature_names,
                'importance': feature_importance
            }).sort_values('importance', ascending=False)
            
            # Save feature importance
            importance_df.to_csv('models/feature_importance_shap.csv', index=False)
            
            print("✅ SHAP analysis completed and saved")
            print("📊 Top 10 most important features:")
            for i, (_, row) in enumerate(importance_df.head(10).iterrows()):
                print(f"   {i+1}. {row['feature']}: {row['importance']:.4f}")
                
        except ImportError:
            print("⚠️ SHAP not available. Install with: pip install shap")
        except Exception as e:
            print(f"⚠️ SHAP analysis failed: {e}")
            print("   This is expected for some XGBoost configurations")
        
        self.models = trained_models
        return trained_models
    
    def evaluate_models(self):
        """Enhanced model evaluation with detailed metrics"""
        print("\n📊 ENHANCED MODEL EVALUATION RESULTS:")
        print("=" * 60)
        
        best_model = None
        best_accuracy = 0
        
        for name, results in self.results.items():
            accuracy = results['accuracy']
            cv_accuracy = results['cv_accuracy']
            predictions = results['predictions']
            
            print(f"\n🤖 {name}:")
            print(f"   Validation Accuracy: {accuracy:.4f}")
            print(f"   Cross-Val Accuracy: {cv_accuracy:.4f}")
            
            # Detailed classification report
            report = classification_report(self.y_val, predictions, 
                                         target_names=self.target_encoder.classes_,
                                         output_dict=True, zero_division=0)
            
            moderate_recall = report.get('Moderate', {}).get('recall', 0)
            print(f"   Moderate Recall: {moderate_recall:.4f}")
            
            if cv_accuracy > best_accuracy:
                best_accuracy = cv_accuracy
                best_model = name
        
        print(f"\n🏆 Best Model: {best_model} (CV Accuracy: {best_accuracy:.4f})")
        
        # Generate confusion matrix for best model
        self.generate_confusion_matrix(best_model)
        
        return best_model
    
    def generate_confusion_matrix(self, model_name):
        """Generate enhanced confusion matrix with detailed metrics"""
        print(f"📊 Generating enhanced confusion matrix for {model_name}...")
        
        predictions = self.results[model_name]['predictions']
        cm = confusion_matrix(self.y_val, predictions)
        
        # Calculate metrics
        accuracy = accuracy_score(self.y_val, predictions)
        precision = precision_score(self.y_val, predictions, average='weighted', zero_division=0)
        recall = recall_score(self.y_val, predictions, average='weighted', zero_division=0)
        f1 = f1_score(self.y_val, predictions, average='weighted', zero_division=0)
        
        # Create enhanced visualization
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
        
        # Confusion Matrix
        sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", 
                   xticklabels=self.target_encoder.classes_, 
                   yticklabels=self.target_encoder.classes_,
                   ax=ax1, cbar_kws={'shrink': 0.8})
        ax1.set_title(f"{model_name} - Enhanced Confusion Matrix", fontsize=14, fontweight='bold')
        ax1.set_xlabel("Predicted", fontsize=12)
        ax1.set_ylabel("Actual", fontsize=12)
        
        # Add metrics text
        metrics_text = f"""
        Accuracy: {accuracy:.4f}
        Precision: {precision:.4f}
        Recall: {recall:.4f}
        F1-Score: {f1:.4f}
        """
        ax1.text(0.02, 0.98, metrics_text, transform=ax1.transAxes, 
                verticalalignment='top', bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))
        
        # Normalized Confusion Matrix
        cm_normalized = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]
        sns.heatmap(cm_normalized, annot=True, fmt=".3f", cmap="Oranges", 
                   xticklabels=self.target_encoder.classes_, 
                   yticklabels=self.target_encoder.classes_,
                   ax=ax2, cbar_kws={'shrink': 0.8})
        ax2.set_title(f"{model_name} - Normalized Confusion Matrix", fontsize=14, fontweight='bold')
        ax2.set_xlabel("Predicted", fontsize=12)
        ax2.set_ylabel("Actual", fontsize=12)
        
        plt.tight_layout()
        plt.savefig(f"models/{model_name}_enhanced_confusion_matrix.png", dpi=300, bbox_inches='tight')
        plt.close()
        
        # Save detailed metrics
        metrics_data = {
            'Model': model_name,
            'Accuracy': accuracy,
            'Precision': precision,
            'Recall': recall,
            'F1_Score': f1,
            'Confusion_Matrix': cm.tolist()
        }
        
        import json
        with open(f"models/{model_name}_detailed_metrics.json", 'w') as f:
            json.dump(metrics_data, f, indent=2)
        
        print(f"✅ Enhanced confusion matrix saved: models/{model_name}_enhanced_confusion_matrix.png")
        print(f"✅ Detailed metrics saved: models/{model_name}_detailed_metrics.json")
        print(f"📊 Model Performance - Accuracy: {accuracy:.4f}, F1: {f1:.4f}")
    
    def test_on_new_weather_data(self):
        """Test enhanced model on new weather data"""
        print("🧪 Testing ENHANCED model on NEW weather data...")
        
        if not hasattr(self, 'testing_df'):
            print("❌ No testing data loaded!")
            return
            
        if not hasattr(self, 'feature_names'):
            print("❌ No feature names available! Train model first.")
            return
        
        # Prepare testing features
        X_test = pd.DataFrame()
        
        print(f"🔧 Preparing test features to match {len(self.feature_names)} training features...")
        
        # Process each feature
        for feature in self.feature_names:
            if feature in self.testing_df.columns:
                if hasattr(self, 'label_encoders') and feature in self.label_encoders:
                    # Categorical feature
                    test_categories = self.testing_df[feature].astype(str)
                    le = self.label_encoders[feature]
                    
                    encoded_values = []
                    for cat in test_categories:
                        try:
                            encoded_values.append(le.transform([cat])[0])
                        except ValueError:
                            encoded_values.append(0)
                    
                    X_test[feature] = encoded_values
                else:
                    # Numeric feature
                    X_test[feature] = pd.to_numeric(self.testing_df[feature], errors='coerce')
                    X_test[feature] = X_test[feature].fillna(X_test[feature].median())
            else:
                X_test[feature] = 0
        
        # Scale numeric features
        num_cols = X_test.select_dtypes(include=['float64', 'int64']).columns
        X_test_scaled = X_test.copy()
        X_test_scaled[num_cols] = self.scaler.transform(X_test[num_cols])
        
        # Get best model
        best_model = max(self.results.keys(), key=lambda x: self.results[x]['cv_accuracy'])
        model = self.models[best_model]
        
        print(f"🏆 Using best model: {best_model}")
        
        # Make predictions
        predictions = model.predict(X_test_scaled)
        probabilities = model.predict_proba(X_test_scaled)
        
        # Convert back to risk levels
        risk_levels = self.target_encoder.inverse_transform(predictions)
        
        # Add predictions to testing dataframe
        test_results = self.testing_df.copy()
        test_results['Predicted_Flood_Risk'] = risk_levels
        test_results['Prediction_Confidence'] = np.max(probabilities, axis=1)
        
        print(f"✅ Predictions completed using {best_model} model")
        print("📊 Prediction distribution:")
        print(pd.Series(risk_levels).value_counts())
        
        # Enhanced monitoring and logging
        print("\n📊 ENHANCED MONITORING & LOGGING:")
        print("=" * 40)
        
        # Model performance metrics
        model_metrics = {
            'timestamp': pd.Timestamp.now().isoformat(),
            'best_model': best_model,
            'model_accuracy': self.results[best_model]['cv_accuracy'],
            'validation_accuracy': self.results[best_model]['accuracy'],
            'total_features': len(self.feature_names),
            'training_samples': len(self.training_df),
            'test_samples': len(self.testing_df),
            'prediction_confidence_mean': np.mean(test_results['Prediction_Confidence']),
            'prediction_confidence_std': np.std(test_results['Prediction_Confidence'])
        }
        
        # Save model metrics
        metrics_df = pd.DataFrame([model_metrics])
        metrics_path = os.path.join("models", "model_performance_metrics.csv")
        
        # Append to existing metrics file or create new
        if os.path.exists(metrics_path):
            existing_metrics = pd.read_csv(metrics_path)
            combined_metrics = pd.concat([existing_metrics, metrics_df], ignore_index=True)
            combined_metrics.to_csv(metrics_path, index=False)
        else:
            metrics_df.to_csv(metrics_path, index=False)
        
        print(f"✅ Model metrics saved to: {metrics_path}")
        
        # Prediction distribution analysis
        prediction_dist = test_results['Predicted_Flood_Risk'].value_counts()
        print(f"📊 Prediction Distribution:")
        for risk_level, count in prediction_dist.items():
            percentage = (count / len(test_results)) * 100
            print(f"   {risk_level}: {count} ({percentage:.1f}%)")
        
        # Confidence analysis
        high_confidence = test_results[test_results['Prediction_Confidence'] > 0.8]
        print(f"🎯 High Confidence Predictions (>80%): {len(high_confidence)} ({len(high_confidence)/len(test_results)*100:.1f}%)")
        
        # Save test results
        results_path = os.path.join("data", "flood_predictions_enhanced_ensemble.csv")
        test_results.to_csv(results_path, index=False)
        print(f"💾 Test results saved to: {results_path}")
        
        return test_results
    
    def save_models(self, best_model_name):
        """Save enhanced models"""
        print(f"💾 Saving ENHANCED models...")
        
        # Create models directory
        models_dir = "models"
        os.makedirs(models_dir, exist_ok=True)
        
        # Save best model
        best_model = self.models[best_model_name]
        model_path = os.path.join(models_dir, "enhanced_ensemble_model.pkl")
        joblib.dump(best_model, model_path)
        
        # Save scaler
        scaler_path = os.path.join(models_dir, "enhanced_ensemble_scaler.pkl")
        joblib.dump(self.scaler, scaler_path)
        
        # Save target encoder
        encoder_path = os.path.join(models_dir, "enhanced_ensemble_encoder.pkl")
        joblib.dump(self.target_encoder, encoder_path)
        
        # Save feature names
        features_path = os.path.join(models_dir, "enhanced_ensemble_features.pkl")
        joblib.dump(self.feature_names, features_path)
        
        # Save label encoders
        if hasattr(self, 'label_encoders'):
            label_encoders_path = os.path.join(models_dir, "enhanced_ensemble_label_encoders.pkl")
            joblib.dump(self.label_encoders, label_encoders_path)
        
        # Save metadata
        metadata = {
            'model_type': best_model_name,
            'feature_names': self.feature_names,
            'feature_count': len(self.feature_names),
            'target_classes': list(self.target_encoder.classes_),
            'accuracy': self.results[best_model_name]['accuracy'],
            'cv_accuracy': self.results[best_model_name]['cv_accuracy'],
            'training_date': datetime.now().isoformat(),
            'training_data_size': len(self.training_df),
            'training_source': 'final_flood_classification_data.csv',
            'testing_source': 'mumbai_combined_weather_data.csv',
            'model_version': 'enhanced_ensemble_with_voting',
            'techniques': ['ensemble_voting', 'cross_validation', 'balanced_weights', 'feature_engineering']
        }
        
        metadata_path = os.path.join(models_dir, "enhanced_ensemble_metadata.pkl")
        joblib.dump(metadata, metadata_path)
        
        print(f"✅ Enhanced models saved:")
        print(f"   Best model: {model_path}")
        print(f"   Accuracy: {self.results[best_model_name]['accuracy']:.4f}")
        print(f"   CV Accuracy: {self.results[best_model_name]['cv_accuracy']:.4f}")
        print(f"   Total features used: {len(self.feature_names)}")
        
        return model_path

def main():
    """Main enhanced training and testing function"""
    print("🚀 ENHANCED ENSEMBLE FLOOD PREDICTION MODEL TRAINING")
    print("=" * 70)
    print("📊 TRAIN: final_flood_classification data.csv (REAL flood data)")
    print("🧪 TEST: mumbai_combined_weather_data.csv (NEW weather data)")
    print("🔧 ENHANCED: Ensemble Voting + Feature Engineering + Cross-Validation")
    print("=" * 70)
    
    # Initialize predictor
    predictor = EnhancedFloodPredictor()
    
    # Load training data
    training_data = predictor.load_training_data()
    if training_data is None:
        print("❌ Failed to load training data. Exiting.")
        return
    
    # Load testing data
    testing_data = predictor.load_testing_data()
    if testing_data is None:
        print("❌ Failed to load testing data. Exiting.")
        return
    
    # Prepare training features
    X_train, y_train = predictor.prepare_training_features()
    
    # Train enhanced models
    models = predictor.train_enhanced_models(X_train, y_train)
    
    # Evaluate models
    best_model = predictor.evaluate_models()
    
    # Test on new weather data
    test_results = predictor.test_on_new_weather_data()
    
    # Save models
    model_path = predictor.save_models(best_model)
    
    print(f"\n🎉 Enhanced ensemble training completed successfully!")
    print(f"📁 Enhanced model saved to: {model_path}")
    print(f"🎯 Model uses ensemble voting with cross-validation!")
    print(f"🔧 Enhanced feature engineering and balanced weights applied!")

if __name__ == "__main__":
    main()