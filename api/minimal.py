from flask import Flask, jsonify, request, Response
import json
import math

app = Flask(__name__)

# Simple data for testing
regions = [
    {'name': 'Andheri East', 'lat': 19.1197, 'lon': 72.8697, 'risk': 'Medium'},
    {'name': 'Bandra West', 'lat': 19.0544, 'lon': 72.8267, 'risk': 'Low'},
    {'name': 'Colaba', 'lat': 18.9067, 'lon': 72.8147, 'risk': 'High'},
]

@app.route("/")
def home():
    return jsonify({
        'message': '🗺️ Evacuation Server',
        'status': 'active',
        'regions': len(regions)
    })

@app.route("/health")
def health():
    return jsonify({'status': 'healthy', 'regions': len(regions)})

@app.route("/map")
def get_map():
    region = request.args.get('region', 'Andheri')
    return f"""
    <!DOCTYPE html>
    <html>
    <head><title>Map - {region}</title></head>
    <body>
        <h1>Evacuation Map for {region}</h1>
        <p>Your evacuation route system is working!</p>
    </body>
    </html>
    """

if __name__ == '__main__':
    app.run(debug=True)
