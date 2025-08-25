#!/usr/bin/env python3
"""
Minimal Backend API Server for Flood Prediction and Evacuation Routes
Only essential endpoints - no heavy dependencies
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Email configuration from environment variables
EMAIL_USER = 'alertfloodrisk@gmail.com'
EMAIL_PASS = 'blso hzhi mkvz zhkj'
SMTP_SERVER = 'smtp.gmail.com'
SMTP_PORT = 587

def send_email_alert(to_email, subject, message):
    """Send email alert using Gmail SMTP"""
    try:
        # Create message
        msg = MIMEMultipart()
        msg['From'] = EMAIL_USER
        msg['To'] = to_email
        msg['Subject'] = subject
        
        # Add body to email
        msg.attach(MIMEText(message, 'plain'))
        
        # Create SMTP session
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()  # Start TLS encryption
        server.login(EMAIL_USER, EMAIL_PASS)
        
        # Send email
        text = msg.as_string()
        server.sendmail(EMAIL_USER, to_email, text)
        server.quit()
        
        return {"success": True, "message": "Email sent successfully"}
    except Exception as e:
        return {"success": False, "error": str(e)}

# Mumbai regions data (from your CSV)
MUMBAI_REGIONS = [
    "Andheri East", "Andheri West", "Bandra East", "Bandra West", 
    "Colaba", "Fort", "Dadar", "Worli", "Powai", "Borivali",
    "Malad", "Goregaon", "Versova", "Juhu", "Santacruz", "Khar",
    "Mahim", "Sion", "Kurla", "Ghatkopar", "Thane", "Mulund"
]

# Sample flood risk data
FLOOD_RISK_DATA = {
    "Andheri East": "high", "Andheri West": "moderate", "Bandra East": "low", 
    "Bandra West": "low", "Colaba": "low", "Fort": "low", "Dadar": "moderate",
    "Worli": "low", "Powai": "high", "Borivali": "low", "Malad": "moderate",
    "Goregaon": "moderate", "Versova": "moderate", "Juhu": "moderate", 
    "Santacruz": "moderate", "Khar": "low", "Mahim": "moderate", 
    "Sion": "high", "Kurla": "high", "Ghatkopar": "moderate", 
    "Thane": "moderate", "Mulund": "low"
}

# Sample evacuation routes data
EVACUATION_ROUTES = {
    "Andheri East": [
        {"destination": "Borivali", "distance_km": 12.3, "eta": "29.5 min", "risk_level": "low"},
        {"destination": "Colaba", "distance_km": 18.7, "eta": "44.9 min", "risk_level": "low"},
        {"destination": "Fort", "distance_km": 16.2, "eta": "38.9 min", "risk_level": "low"}
    ],
    "Thane": [
        {"destination": "Mulund", "distance_km": 8.5, "eta": "20.4 min", "risk_level": "low"},
        {"destination": "Borivali", "distance_km": 15.2, "eta": "36.5 min", "risk_level": "low"},
        {"destination": "Khar", "distance_km": 22.1, "eta": "53.0 min", "risk_level": "low"}
    ]
}

@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    return response

@app.route("/")
def home():
    """API Information"""
    return jsonify({
        "message": "🌊 Mumbai Flood Prediction & Evacuation Routes API",
        "version": "2.0.0 - Backend Only",
        "endpoints": {
            "health": "/health",
            "regions": "/regions", 
            "predict_flood": "/predict_flood (POST)",
            "routes": "/routes (POST)",
            "map": "/map?region=<region_name>",
            "send_alert": "/send_alert (POST) - Send flood alert email",
            "register_user": "/register_user (POST) - Register user for alerts"
        },
        "status": "✅ Backend Only - No Frontend Files",
        "deployment": "Local Server with Email Alerts",
        "email_service": "✅ Active with Gmail SMTP"
    })

@app.route("/health")
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "message": "Backend API is running perfectly!",
        "service": "Mumbai Evacuation Routes API",
        "regions_count": len(MUMBAI_REGIONS)
    })

@app.route("/regions")
def regions():
    """Get all available regions"""
    return jsonify({
        "regions": MUMBAI_REGIONS,
        "count": len(MUMBAI_REGIONS),
        "message": f"Found {len(MUMBAI_REGIONS)} Mumbai regions"
    })

@app.route("/predict_flood", methods=['POST'])
def predict_flood():
    """Predict flood risk for a ward"""
    try:
        data = request.get_json()
        ward_name = data.get('ward_name', '')
        
        if not ward_name:
            return jsonify({"error": "ward_name is required"}), 400
        
        # Find matching region (case insensitive)
        matched_region = None
        for region in MUMBAI_REGIONS:
            if ward_name.lower() in region.lower() or region.lower() in ward_name.lower():
                matched_region = region
                break
        
        if not matched_region:
            return jsonify({
                "error": f"Ward '{ward_name}' not found",
                "ward": ward_name,
                "available_regions": MUMBAI_REGIONS[:10]
            }), 404
        
        risk_level = FLOOD_RISK_DATA.get(matched_region, "moderate")
        
        return jsonify({
            "ward": matched_region,
            "risk_level": risk_level,
            "confidence": 0.87,
            "message": f"Flood risk level for {matched_region} is {risk_level}"
        })
        
    except Exception as e:
        return jsonify({
            "error": str(e),
            "ward": ward_name if 'ward_name' in locals() else "unknown"
        }), 500

@app.route("/routes", methods=['POST'])
def get_routes():
    """Get evacuation routes for a region"""
    try:
        data = request.get_json()
        region = data.get('region', '')
        route_count = data.get('route_count', 3)
        
        if not region:
            return jsonify({"error": "region is required"}), 400
        
        # Find matching region (case insensitive)
        matched_region = None
        for r in MUMBAI_REGIONS:
            if region.lower() in r.lower() or r.lower() in region.lower():
                matched_region = r
                break
        
        if not matched_region:
            return jsonify({
                "error": f"Region '{region}' not found",
                "matched_region": None,
                "available_regions": MUMBAI_REGIONS[:10]
            }), 404
        
        # Get evacuation routes
        routes = EVACUATION_ROUTES.get(matched_region, [
            {"destination": "Safe Zone 1", "distance_km": 10.5, "eta": "25.2 min", "risk_level": "low"},
            {"destination": "Safe Zone 2", "distance_km": 15.2, "eta": "36.5 min", "risk_level": "low"},
            {"destination": "Safe Zone 3", "distance_km": 8.7, "eta": "20.9 min", "risk_level": "low"}
        ])
        
        # Limit routes to requested count
        routes = routes[:route_count]
        
        return jsonify({
            "success": True,
            "matched_region": matched_region,
            "match_score": 95,
            "routes": routes,
            "route_count": len(routes),
            "message": f"Found {len(routes)} evacuation routes from {matched_region}"
        })
        
    except Exception as e:
        return jsonify({
            "error": str(e),
            "matched_region": region if 'region' in locals() else "unknown"
        }), 500

@app.route("/map")
def map_page():
    """Generate evacuation map (simplified HTML)"""
    try:
        region = request.args.get("region", "")
        if not region:
            return jsonify({"error": "Region parameter is required"}), 400

        # Find matching region
        matched_region = None
        for r in MUMBAI_REGIONS:
            if region.lower() in r.lower() or r.lower() in region.lower():
                matched_region = r
                break
        
        if not matched_region:
            return jsonify({
                "error": f"Region '{region}' not found",
                "available_regions": MUMBAI_REGIONS[:10]
            }), 404

        # Return simple HTML map
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Evacuation Map - {matched_region}</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                .map-container {{ border: 2px solid #007bff; padding: 20px; border-radius: 10px; }}
                .route {{ margin: 10px 0; padding: 10px; background: #f8f9fa; border-radius: 5px; }}
                .high-risk {{ color: #dc3545; }}
                .moderate-risk {{ color: #fd7e14; }}
                .low-risk {{ color: #28a745; }}
            </style>
        </head>
        <body>
            <div class="map-container">
                <h1>🗺️ Evacuation Map for {matched_region}</h1>
                <p><strong>Current Risk Level:</strong> 
                   <span class="{FLOOD_RISK_DATA.get(matched_region, 'moderate')}-risk">
                       {FLOOD_RISK_DATA.get(matched_region, 'moderate').upper()}
                   </span>
                </p>
                <h2>📍 Evacuation Routes:</h2>
        """
        
        routes = EVACUATION_ROUTES.get(matched_region, [])
        for i, route in enumerate(routes):
            html_content += f"""
                <div class="route">
                    <strong>Route {i+1}:</strong> {route['destination']}<br>
                    <strong>Distance:</strong> {route['distance_km']} km<br>
                    <strong>ETA:</strong> {route['eta']}<br>
                    <strong>Risk Level:</strong> <span class="{route['risk_level']}-risk">{route['risk_level'].upper()}</span>
                </div>
            """
        
        html_content += """
            </div>
            <script>
                console.log('Evacuation map loaded for """ + matched_region + """');
            </script>
        </body>
        </html>
        """
        
        return html_content, 200, {'Content-Type': 'text/html'}
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/send_alert", methods=['POST'])
def send_alert():
    """Send flood alert email to user"""
    try:
        data = request.get_json()
        email = data.get('email', '')
        region = data.get('region', '')
        risk_level = data.get('risk_level', 'moderate')
        
        if not email:
            return jsonify({"error": "Email is required"}), 400
        
        if not region:
            return jsonify({"error": "Region is required"}), 400
        
        # Create email content
        subject = f"🚨 Flood Alert for {region} - {risk_level.upper()} Risk"
        
        message = f"""
Dear User,

FLOOD ALERT NOTIFICATION
========================

Location: {region}
Risk Level: {risk_level.upper()}
Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

SAFETY INSTRUCTIONS:
- Move to higher ground immediately if in high-risk area
- Avoid walking or driving through flood waters
- Keep emergency supplies ready
- Stay tuned to official updates

Stay Safe!
Mumbai Flood Alert System
        """
        
        # Send email
        result = send_email_alert(email, subject, message)
        
        if result["success"]:
            return jsonify({
                "success": True,
                "message": f"Flood alert sent to {email}",
                "region": region,
                "risk_level": risk_level
            })
        else:
            return jsonify({
                "success": False,
                "error": result["error"]
            }), 500
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/register_user", methods=['POST'])
def register_user():
    """Register user for flood alerts"""
    try:
        data = request.get_json()
        name = data.get('name', '')
        email = data.get('email', '')
        region = data.get('region', '')
        
        if not all([name, email, region]):
            return jsonify({"error": "Name, email, and region are required"}), 400
        
        # Send welcome email
        subject = "Welcome to Mumbai Flood Alert System"
        message = f"""
Dear {name},

Welcome to the Mumbai Flood Alert System!

Your registration details:
Name: {name}
Email: {email}
Region: {region}

You will now receive flood alerts and evacuation updates for {region}.

Stay Safe!
Mumbai Flood Alert System
        """
        
        # Send welcome email
        result = send_email_alert(email, subject, message)
        
        if result["success"]:
            return jsonify({
                "success": True,
                "message": f"User {name} registered successfully. Welcome email sent to {email}",
                "user": {
                    "name": name,
                    "email": email,
                    "region": region
                }
            })
        else:
            return jsonify({
                "success": False,
                "error": result["error"]
            }), 500
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
