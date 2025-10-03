# app.py
from flask import Flask, render_template, request
import requests
import os

app = Flask(__name__)

# Get API key from environment variable or use demo key
API_KEY = 'f215342ef6fb31829da6b26256b5d768'

@app.route('/', methods=['GET', 'POST'])
def index():
    weather_data = {}
    error = None
    
    if request.method == 'POST':
        city = request.form['city']
        url = f'http://api.openweathermap.org/data/2.5/weather?q={city}&appid={API_KEY}&units=metric'
        
        try:
            response = requests.get(url)
            if response.status_code == 200:
                data = response.json()
                weather_data = {
                    'city': data['name'],
                    'temperature': data['main']['temp'],
                    'description': data['weather'][0]['description'],
                    'icon': data['weather'][0]['icon'],
                    'humidity': data['main']['humidity'],
                    'wind_speed': data['wind']['speed']
                }
            else:
                error = "City not found. Please try again."
        except Exception as e:
            error = "Error connecting to weather service. Please try again later."
    
    return render_template('index.html', weather=weather_data, error=error)

if __name__ == '__main__':
    app.run(debug=True)
