# Flood Management System

A comprehensive Flutter-based flood management application that provides real-time monitoring, alerts, and emergency response features.

## 🌊 Features

- **Real-time Flood Monitoring**: Track water levels and flood risks in real-time
- **Interactive Maps**: View flood-prone areas and evacuation routes
- **Emergency Alerts**: Receive instant notifications about flood warnings
- **Emergency Contacts**: Quick access to emergency services
- **Flood Reporting**: Report flood incidents in your area
- **Dashboard Analytics**: Comprehensive overview of flood status

## 🚀 Live Demo

The web version of this application is deployed on GitHub Pages and can be accessed at:
[Your GitHub Pages URL will appear here after deployment]

## 📱 Screenshots

- Dashboard with real-time flood status
- Interactive map showing flood-prone areas
- Emergency contact interface
- Flood prediction analytics

## 🛠️ Technology Stack

- **Frontend**: Flutter (Dart)
- **Maps**: Google Maps Flutter
- **UI**: Material Design with Google Fonts
- **Deployment**: GitHub Pages with GitHub Actions

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.24.0 or higher)
- Dart SDK
- Git

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/flood-management-system.git
cd flood-management-system
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application:
```bash
flutter run
```

### Building for Web

To build the web version:
```bash
flutter build web --release
```

## 📦 Deployment

This project is automatically deployed to GitHub Pages using GitHub Actions. The deployment workflow:

1. Triggers on push to main/master branch
2. Sets up Flutter environment
3. Builds the web version
4. Deploys to GitHub Pages

### Manual Deployment

If you want to deploy manually:

1. Build the web version:
```bash
flutter build web --release
```

2. Push the `build/web` folder to the `gh-pages` branch

## 🔧 Configuration

### Google Maps API

To use the map features, you'll need to:

1. Get a Google Maps API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Add the API key to your project configuration

### Environment Variables

Create a `.env` file in the root directory:
```
GOOGLE_MAPS_API_KEY=your_api_key_here
```

## 📁 Project Structure

```
lib/
├── main.dart                 # Main application entry point
├── DashboardPage.dart        # Dashboard screen
├── MapPage.dart             # Interactive map screen
├── EmergencyPage.dart       # Emergency contacts
├── ProfilePage.dart         # User profile
├── FloodPrediction.dart     # Flood prediction logic
└── flood_areas.dart         # Flood area data
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Emergency Information

For real emergency situations, always contact your local emergency services:
- Emergency: 911 (US) / 112 (EU) / 100 (India)
- Local flood control authorities
- Weather services

## 📞 Support

If you have any questions or need support, please open an issue on GitHub.

---

**Note**: This is a demonstration project. For real flood management, always rely on official government and emergency services.
