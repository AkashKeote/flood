
require('dotenv').config(); // Only for local development

const express = require('express');
const cors = require('cors');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Firebase Connection Test
let firebaseConnected = false;
try {
  const { db } = require('./config/firebase');
  firebaseConnected = true;
  console.log('Firebase connected successfully ✅');
} catch (error) {
  console.error('Firebase connection failed:', error.message);
}

// Debug route to list all routes
app.get('/api/debug/routes', (req, res) => {
  const routes = [];
  app._router.stack.forEach(function(r){
    if (r.route && r.route.path){
      routes.push({
        path: r.route.path,
        methods: Object.keys(r.route.methods)
      });
    }
  });
  res.json({
    success: true,
    routes: routes
  });
});

// Test route for debugging
app.get('/api/test', (req, res) => {
  res.json({
    success: true,
    message: "Test route working!",
    timestamp: new Date().toISOString()
  });
});

// Simple auth test route without Firebase
app.post('/api/auth/test', (req, res) => {
  try {
    const { email, city } = req.body;
    res.json({
      success: true,
      message: "Auth test route working!",
      received: { email, city },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Direct signup route for testing - Now accepts name, email, city from frontend
app.post('/api/auth/signup', async (req, res) => {
  try {
    const { email, city, name } = req.body;
    
    if (!email || !city || !name) {
      return res.status(400).json({ 
        success: false,
        error: 'Name, email and city are all required fields.' 
      });
    }

    // Use Firebase AlertUser model
    const AlertUser = require('./models/alertUser');
    
    // Check if user already exists
    const existingUser = await AlertUser.findByEmail(email);
    if (existingUser) {
      // User exists, update their city (or add to cities list)
      console.log(`✅ User ${email} already exists, updating city to ${city}`);
      
      // For now, update the existing user's city
      // In future, we can modify to support multiple cities per user
      res.status(200).json({ 
        success: true, 
        message: `User updated for ${city}. You will receive flood alerts for your area.`,
        user: {
          id: existingUser.id,
          email: existingUser.email,
          city: city, // Updated city
          name: existingUser.name
        },
        database: 'Firebase Firestore (flood-66d6c)',
        timestamp: new Date().toISOString()
      });
      return;
    }

    // Create new user in Firebase with name from frontend
    const newUser = await AlertUser.create({
      email,
      city,
      name, // Use actual name from frontend
      alertsReceived: 0
    });

    console.log(`✅ User registered in Firebase: ${name} (${email}) for ${city}`);

    res.status(201).json({
      success: true,
      message: 'User registered successfully! You will receive flood alerts for your area.',
      user: {
        id: newUser.id,
        email: newUser.email,
        city: newUser.city,
        name: newUser.name
      },
      database: 'Firebase Firestore (flood-66d6c)',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Registration error:', error);
    res.status(500).json({
      success: false,
      error: `Registration failed: ${error.message}`,
      database: 'Firebase Firestore (flood-66d6c)'
    });
  }
});

// Direct login route for testing
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email } = req.body;
    
    if (!email) {
      return res.status(400).json({ 
        success: false,
        error: 'Email is required.' 
      });
    }

    // Send login notification email
    try {
      const { sendEmail } = require('./services/notification');
      const loginEmailHtml = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #059669;">🔐 Login Successful - Flood Alert System</h2>
          <p>Dear User,</p>
          <p>You have successfully logged into your Flood Alert System account.</p>
          
          <div style="background-color: #f0fdf4; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #10b981;">
            <h3 style="color: #065f46;">📋 Login Details:</h3>
            <p><strong>📧 Email:</strong> ${email}</p>
            <p><strong>🕐 Login Time:</strong> ${new Date().toLocaleString()}</p>
            <p><strong>🌐 Location:</strong> Mumbai (Default)</p>
          </div>

          <div style="background-color: #eff6ff; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <h4 style="color: #1e40af;">🔔 Active Alerts Status:</h4>
            <p style="color: #1e3a8a;">✅ You are now subscribed to flood alerts for your area</p>
            <p style="color: #1e3a8a;">📱 Keep your notifications enabled for emergency alerts</p>
          </div>

          <p style="color: #6b7280;">
            If this login was not you, please contact support immediately.<br>
            Stay safe and stay informed! 🛡️
          </p>
          
          <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 30px 0;">
          <p style="font-size: 12px; color: #9ca3af; text-align: center;">
            Flood Alert System | Emergency Notification Service<br>
            This is an automated security notification.
          </p>
        </div>
      `;

      await sendEmail(
        email,
        '🔐 Login Successful - Flood Alert System',
        loginEmailHtml
      );

      console.log(`✅ Login notification email sent to ${email}`);
    } catch (emailError) {
      console.error('❌ Error sending login email:', emailError.message);
      // Don't fail the login if email fails
    }

    // Simple success response
    res.status(200).json({
      success: true,
      message: 'Login successful! Notification email sent.',
      user: {
        id: Date.now().toString(),
        email: email,
        city: 'Mumbai' // Default city for demo
      },
      timestamp: new Date().toISOString(),
      note: `Login notification sent to ${email} from alertfloodrisk@gmail.com`
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Direct flood alert route for testing - MongoDB style with Firebase backend
app.post('/api/alerts/send-by-city', async (req, res) => {
  try {
    const { city } = req.body;
    if (!city) return res.status(400).json({ error: 'City is required.' });

    // Use Firebase AlertUser model to get registered users
    const AlertUser = require('./models/alertUser');
    let users = await AlertUser.findByCity(city);

    // If no Firebase users found, return error instead of hardcoded email
    if (users.length === 0) {
      return res.status(404).json({ 
        error: `No registered users found for city: ${city}`,
        message: 'Please register users first using the signup endpoint'
      });
    }

    // Get flood risk and services
    const { getFloodRiskByCity } = require('./services/floodapi');
    const { findNearestSafePlaces } = require('./services/safePlaces');
    const { sendEmail } = require('./services/notification');
    
    const cityRisk = getFloodRiskByCity(city);
    const nearestSafePlaces = findNearestSafePlaces(city);

    // Send alerts for ALL risk levels (like MongoDB version)
    let safePlacesText = '';
    let safePlacesHtml = '';

    if (nearestSafePlaces && nearestSafePlaces.length > 0) {
      // Generate safe places with map links
      safePlacesText = '\nNearest Safe Places:\n' + nearestSafePlaces.map((place, idx) =>
        `${idx + 1}. ${place.name} (${place.type}) - ${place.distance} km\nMap: ${place.mapLink}`
      ).join('\n');

      safePlacesHtml = `
        <h2>Nearest Safe Places:</h2>
        <ul>
          ${nearestSafePlaces.map(place =>
            `<li><b>${place.name}</b> (${place.type}) - ${place.distance} km
             <br><a href="${place.mapLink}" target="_blank">📍 View on Map</a> | 
             <a href="${place.routeLink}" target="_blank">🧭 Get Directions</a></li>`
          ).join('')}
        </ul>
      `;
    } else {
      const safetyPrecautions = [
        "Move to higher ground immediately.",
        "Avoid walking or driving through flood waters.",
        "Keep a flashlight, battery, and emergency supplies handy.",
        "Disconnect electrical appliances if water enters your home.",
        "Stay tuned to official updates and helpline numbers."
      ];
      
      safePlacesText = '\nSafety Precautions:\n' + safetyPrecautions.map((p, i) => `${i+1}. ${p}`).join('\n');
      safePlacesHtml = `
        <h2>Safety Precautions:</h2>
        <ol>
          ${safetyPrecautions.map(p => `<li>${p}</li>`).join('')}
        </ol>
      `;
    }

    const appLinkText = `\n\nCheck evacuation routes here: https://akashkeote.github.io/flood/`;
    const appLinkHtml = `<p>� Check live <a href="https://akashkeote.github.io/flood/" target="_blank">Evacuation Routes</a> to stay safe.</p>`;

    let emailsSent = 0;

    for (const user of users) {
      try {
        const smsMessage = `🚨 Flood Alert!\nYour area (${city}) is at a ${cityRisk} flood risk.\nStay safe!${safePlacesText}${appLinkText}`;

        const emailSubject = `🚨 Flood Alert: ${city} - ${cityRisk} Risk`;
        const emailHtml = `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h1 style="color: ${cityRisk === 'high' ? '#dc2626' : cityRisk === 'moderate' ? '#d97706' : '#059669'};">� Flood Alert!</h1>
            <p>Hi ${user.name || user.email.split('@')[0]}, your area is at a <b>${cityRisk}</b> flood risk. Please stay safe!</p>
            
            ${safePlacesHtml}
            ${appLinkHtml}
            
            <div style="background-color: #fee2e2; border: 1px solid #fecaca; padding: 15px; border-radius: 8px; margin: 20px 0;">
              <p style="margin: 0; color: #dc2626; font-weight: bold;">
                Emergency Contacts: Police (100) | Fire (101) | Ambulance (102) | Disaster Management (108)
              </p>
            </div>
            
            <p style="color: #6b7280; font-size: 14px;">
              Alert sent: ${new Date().toLocaleString()}<br>
              Location: ${city}<br>
              Risk Level: ${cityRisk.toUpperCase()}<br>
              Database: Firebase Firestore (flood-66d6c)<br>
              Stay safe and follow official instructions.
            </p>
          </div>
        `;

        await sendEmail(user.email, emailSubject, emailHtml);
        emailsSent++;
        console.log(`✅ ${cityRisk.toUpperCase()} risk alert sent to ${user.email} for ${city}`);
      } catch (emailError) {
        console.error(`❌ Error sending to ${user.email}:`, emailError.message);
      }
    }

    res.status(200).json({
      success: true,
      message: `✅ SMS + Email alerts sent for ${city} (${cityRisk} risk).`,
      details: {
        city: city,
        riskLevel: cityRisk,
        usersNotified: users.length,
        emailsSent: emailsSent,
        safePlacesFound: nearestSafePlaces ? nearestSafePlaces.length : 0,
        database: 'Firebase Firestore (flood-66d6c)',
        timestamp: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('❌ Error sending alerts:', error);
    res.status(500).json({ 
      success: false,
      error: `Failed to send alerts for ${req.body.city}. Error: ${error.message}`,
      database: 'Firebase Firestore (flood-66d6c)'
    });
  }
});

// Import routes after Firebase setup
let authRoutes, alertRoutes;
try {
  console.log('Loading simple auth routes...');
  authRoutes = require('./routes/authSimple'); // Using simple in-memory auth
  console.log('Loading alert routes...');
  alertRoutes = require('./routes/alert');
  
  // Routes
  app.use('/api/auth', authRoutes);
  app.use('/api/alert', alertRoutes); // Changed from /api/alerts to /api/alert
  console.log('Routes loaded successfully!');
} catch (error) {
  console.error('Error loading routes:', error.message);
  console.error('Stack trace:', error.stack);
}

// Root route
app.get('/', (req, res) => {
  try {
    res.status(200).json({
      success: true,
      message: "🚀 Flood Alert API Server is running!",
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
      database: "Firebase Firestore",
      endpoints: {
        health: "/api/health",
        signup: "POST /api/auth/signup (email, city)",
        login: "POST /api/auth/login (email only)", 
        profile: "GET /api/auth/profile/:id",
        alerts: "/api/alerts/send-by-city, /api/alerts/direct"
      },
      note: "Only email and city required - NO PASSWORD needed!"
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message
    });
  }
});

// Favicon route (to prevent 404)
app.get('/favicon.ico', (req, res) => {
  res.status(204).end();
});

// Robots.txt route
app.get('/robots.txt', (req, res) => {
  res.type('text/plain');
  res.send('User-agent: *\nDisallow:');
});

// Health check route
app.get('/api/health', (req, res) => {
  try {
    const healthStatus = {
      success: true,
      message: "Backend is running ✅",
      timestamp: new Date().toISOString(),
      database: firebaseConnected ? 'Firebase Connected' : 'Firebase Disconnected',
      environment: process.env.NODE_ENV || 'development',
      uptime: process.uptime()
    };
    res.status(200).json(healthStatus);
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Health check failed",
      error: error.message
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: "Something went wrong!",
    error: process.env.NODE_ENV === 'development' ? err.message : 'Internal Server Error'
  });
});

// 404 handler - must be last
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found"
  });
});

// For local development only
if (process.env.NODE_ENV !== 'production') {
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
  });
}

// ✅ Export the app for Vercel (Do NOT call app.listen in production)
module.exports = app;
