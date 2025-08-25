const express = require('express');
const AlertUser = require('../models/alertUser'); // Firebase model instead of MongoDB
const { sendSMS, sendEmail } = require('../services/notification');
const { getFloodRiskByCity } = require('../services/floodapi'); // Note: lowercase 'a'
const { findNearestSafePlaces } = require('../services/safePlaces');

const router = express.Router();

const safetyPrecautions = [
    "Move to higher ground immediately.",
    "Avoid walking or driving through flood waters.",
    "Keep a flashlight, battery, and emergency supplies handy.",
    "Disconnect electrical appliances if water enters your home.",
    "Stay tuned to official updates and helpline numbers."
];

router.post('/send-by-city', async (req, res) => {
    try {
        const { city } = req.body;
        if (!city) return res.status(400).json({ error: 'City is required.' });

        // Use Firebase AlertUser model instead of MongoDB User model
        const users = await AlertUser.findByCity(city);
        if (users.length === 0) {
            return res.status(200).json({ 
                message: 'No users found for this city.',
                database: 'Firebase Firestore (flood-66d6c)',
                city: city
            });
        }

        const cityRisk = getFloodRiskByCity(city);

        if (cityRisk === 'high' || cityRisk === 'moderate') {
            let nearestSafePlaces = findNearestSafePlaces(city);

            let safePlacesText = '';
            let safePlacesHtml = '';

            if (nearestSafePlaces && nearestSafePlaces.length > 0) {
                // Modified safePlacesText generation to show place name and a direct map link
                safePlacesText = '\nNearest Safe Places:\n' + nearestSafePlaces.map((place, idx) =>
                    `${idx + 1}. ${place.name} (${place.type}) - ${place.distance} km\nMap: ${place.mapLink}`
                ).join('\n');

                safePlacesHtml = `
                    <h2>Nearest Safe Places:</h2>
                    <ul>
                        ${nearestSafePlaces.map(place =>
                            `<li><b>${place.name}</b> (${place.type}) - ${place.distance} km
                             <br><a href="${place.mapLink}">View on Map</a></li>`
                        ).join('')}
                    </ul>
                `;
            } else {
                safePlacesText = '\nSafety Precautions:\n' + safetyPrecautions.map((p, i) => `${i+1}. ${p}`).join('\n');
                safePlacesHtml = `
                    <h2>Safety Precautions:</h2>
                    <ol>
                        ${safetyPrecautions.map(p => `<li>${p}</li>`).join('')}
                    </ol>
                `;
            }

            const appLinkText = `\n\nCheck evacuation routes here: https://akashkeote.github.io/flood/`;
            const appLinkHtml = `<p>🚧 Check live <a href="https://akashkeote.github.io/flood/">Evacuation Routes</a> to stay safe.</p>`;

            for (const user of users) {
                const smsMessage = `🚨 Flood Alert!\nYour area (${city}) is at a ${cityRisk} flood risk.\nStay safe!${safePlacesText}${appLinkText}`;

                const emailSubject = `🚨 Flood Alert: ${city} - ${cityRisk} Risk`;
                const emailHtml = `
                    <h1>🚨 Flood Alert!</h1>
                    <p>Hi ${user.name || user.email.split('@')[0]}, your area is at a <b>${cityRisk}</b> flood risk. Please stay safe!</p>
                    ${safePlacesHtml}
                    ${appLinkHtml}
                    <p style="color: #6b7280; font-size: 14px;">
                        Alert sent: ${new Date().toLocaleString()}<br>
                        Database: Firebase Firestore (flood-66d6c)<br>
                        User ID: ${user.id}
                    </p>
                `;

                // Send SMS if contact/phone available
                if (user.contact || user.phone) {
                    await sendSMS(user.contact || user.phone, smsMessage);
                }

                // Send email
                if (user.email) {
                    await sendEmail(user.email, emailSubject, emailHtml);
                }

                // Increment alert count in Firebase
                try {
                    await AlertUser.incrementAlertCount(user.id);
                } catch (incrementError) {
                    console.log('Could not increment alert count:', incrementError.message);
                }
            }

            return res.status(200).json({
                success: true,
                message: `✅ SMS + Email alerts sent for ${city} (${cityRisk} risk).`,
                details: {
                    city: city,
                    riskLevel: cityRisk,
                    usersNotified: users.length,
                    database: 'Firebase Firestore (flood-66d6c)',
                    timestamp: new Date().toISOString()
                }
            });
        }

        res.status(200).json({ 
            message: `No alerts sent. Risk level for ${city} is ${cityRisk}.`,
            riskLevel: cityRisk,
            city: city,
            database: 'Firebase Firestore (flood-66d6c)'
        });

    } catch (error) {
        console.error('❌ Error sending alerts:', error);
        res.status(500).json({ 
            error: `Failed to send alerts for ${req.body.city}. Error: ${error.message}`,
            database: 'Firebase Firestore (flood-66d6c)'
        });
    }
});

// Register for flood alerts - Store in Firebase
router.post('/register', async (req, res) => {
  try {
    const { email, city, phone } = req.body;
    
    if (!email || !city) {
      return res.status(400).json({ 
        success: false,
        error: 'Email and city are required' 
      });
    }

    // Register user for alerts in Firebase
    const user = await AlertUser.registerForAlerts(email, city, phone);
    
    console.log(`✅ User ${email} registered for ${city} flood alerts in Firebase`);
    
    res.json({
      success: true,
      message: `Successfully registered for flood alerts in ${city}`,
      user: user,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error registering for alerts:', error.message);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get all registered users for a city - From Firebase
router.get('/users/:city', async (req, res) => {
  try {
    const city = req.params.city;
    const users = await AlertUser.findByCity(city);
    
    res.json({
      success: true,
      city: city,
      usersCount: users.length,
      users: users.map(user => ({
        email: user.email,
        city: user.city,
        registeredAt: user.registeredAt,
        alertsReceived: user.alertsReceived || 0
      })),
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error getting users:', error.message);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;

// Send flood alert to all users in a city - From Firebase
router.post('/send', async (req, res) => {
  try {
    const { city, message, alertLevel = 'medium' } = req.body;
    
    if (!city || !message) {
      return res.status(400).json({ 
        success: false,
        error: 'City and message are required' 
      });
    }

    // Get all users registered for this city from Firebase
    const users = await AlertUser.findByCity(city);
    
    if (users.length === 0) {
      return res.json({
        success: true,
        message: `No users registered for alerts in ${city}`,
        alertsSent: 0,
        timestamp: new Date().toISOString()
      });
    }

    let emailsSent = 0;
    let smsSent = 0;
    let errors = [];

    // Send alerts to all registered users
    for (const user of users) {
      try {
        // Send email alert
        const alertEmailHtml = `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background-color: ${alertLevel === 'high' ? '#dc2626' : alertLevel === 'medium' ? '#d97706' : '#059669'}; color: white; padding: 20px; text-align: center;">
              <h1 style="margin: 0;">🚨 FLOOD ALERT - ${city.toUpperCase()}</h1>
              <p style="margin: 5px 0; font-size: 18px;">Alert Level: ${alertLevel.toUpperCase()}</p>
            </div>
            
            <div style="padding: 20px;">
              <h2 style="color: #1f2937;">📢 Emergency Message:</h2>
              <div style="background-color: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; margin: 20px 0;">
                <p style="margin: 0; font-size: 16px; line-height: 1.5;">${message}</p>
              </div>
              
              <h3 style="color: #dc2626;">🛡️ Safety Instructions:</h3>
              <ul style="color: #374151;">
                <li>Move to higher ground immediately if in flood-prone areas</li>
                <li>Avoid walking or driving through flooded roads</li>
                <li>Keep emergency supplies ready (water, food, flashlight)</li>
                <li>Stay tuned to local emergency broadcasts</li>
                <li>Contact emergency services if in immediate danger</li>
              </ul>
              
              <div style="background-color: #fee2e2; border: 1px solid #fecaca; padding: 15px; border-radius: 8px; margin: 20px 0;">
                <p style="margin: 0; color: #dc2626; font-weight: bold;">
                  Emergency Contacts: Police (100) | Fire (101) | Ambulance (102) | Disaster Management (108)
                </p>
              </div>
              
              <p style="color: #6b7280; font-size: 14px;">
                Alert sent: ${new Date().toLocaleString()}<br>
                Location: ${city}<br>
                Stay safe and follow official instructions.
              </p>
            </div>
          </div>
        `;

        await sendEmail(
          user.email,
          `🚨 URGENT: Flood Alert for ${city} - ${alertLevel.toUpperCase()} Level`,
          alertEmailHtml
        );
        emailsSent++;

        // Send SMS if phone number is available
        if (user.phone) {
          const smsMessage = `🚨 FLOOD ALERT - ${city.toUpperCase()}\nLevel: ${alertLevel.toUpperCase()}\n\n${message}\n\nMove to higher ground. Avoid flooded areas. Emergency: 108\n\nStay Safe!`;
          await sendSMS(user.phone, smsMessage);
          smsSent++;
        }

        // Update user's alert count in Firebase
        await AlertUser.incrementAlertCount(user.id);
        
      } catch (userError) {
        console.error(`❌ Error sending alert to ${user.email}:`, userError.message);
        errors.push(`Failed to send to ${user.email}: ${userError.message}`);
      }
    }

    console.log(`✅ Flood alerts sent for ${city}: ${emailsSent} emails, ${smsSent} SMS`);
    
    res.json({
      success: true,
      message: `Flood alert sent to ${users.length} users in ${city}`,
      city: city,
      alertLevel: alertLevel,
      usersNotified: users.length,
      emailsSent: emailsSent,
      smsSent: smsSent,
      errors: errors.length > 0 ? errors : undefined,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error sending flood alert:', error.message);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Legacy route for backward compatibility - using Firebase data
router.post('/send-by-city', async (req, res) => {
  try {
    const { city } = req.body;
    if (!city) return res.status(400).json({ error: 'City is required.' });

    // Get users from Firebase instead of in-memory storage
    const users = await AlertUser.findByCity(city);
    
    if (users.length === 0) {
      return res.status(200).json({ message: 'No users found for this city.' });
    }

    const cityRisk = getFloodRiskByCity(city);

    if (cityRisk === 'high' || cityRisk === 'moderate') {
      let nearestSafePlaces = findNearestSafePlaces(city);
      
      let safePlacesText = '';
      let safePlacesHtml = '';

      if (nearestSafePlaces && nearestSafePlaces.length > 0) {
        safePlacesText = '\nNearest Safe Places:\n' + nearestSafePlaces.map((place, idx) =>
          `${idx + 1}. ${place.name} (${place.type}) - ${place.distance} km\nMap: ${place.mapLink}`
        ).join('\n');

        safePlacesHtml = `
          <h2>Nearest Safe Places:</h2>
          <ul>
            ${nearestSafePlaces.map(place =>
              `<li><b>${place.name}</b> (${place.type}) - ${place.distance} km
               <br><a href="${place.mapLink}">View on Map</a></li>`
            ).join('')}
          </ul>
        `;
      }

      for (const user of users) {
        const smsMessage = `🚨 Flood Alert!\nYour area (${city}) is at a ${cityRisk} flood risk.\nStay safe!${safePlacesText}`;

        const emailSubject = `🚨 Flood Alert: ${city} - ${cityRisk} Risk`;
        const emailHtml = `
          <h1>🚨 Flood Alert!</h1>
          <p>Hi, your area is at a <b>${cityRisk}</b> flood risk. Please stay safe!</p>
          ${safePlacesHtml}
        `;

        if (user.phone) {
          await sendSMS(user.phone, smsMessage);
        }

        if (user.email) {
          await sendEmail(user.email, emailSubject, emailHtml);
        }

        // Update alert count in Firebase
        await AlertUser.incrementAlertCount(user.id);
      }

      return res.status(200).json({
        message: `✅ SMS + Email alerts sent for ${city} (${cityRisk} risk) to ${users.length} users.`
      });
    }

    res.status(200).json({ message: `No alerts sent. Risk level for ${city} is ${cityRisk}.` });

  } catch (error) {
    console.error('❌ Error sending alerts:', error);
    res.status(500).json({ error: `Failed to send alerts for ${req.body.city}. Error: ${error.message}` });
  }
});

// Direct email alerts (without registration)
router.post('/send-direct', async (req, res) => {
  try {
    const { email, city } = req.body;
    
    if (!email || !city) {
      return res.status(400).json({ error: 'Email and city are required.' });
    }

    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ error: 'Please provide a valid email address.' });
    }

    const cityRisk = getFloodRiskByCity(city);
    let nearestSafePlaces = findNearestSafePlaces(city);

    let safePlacesHtml = '';

    if (nearestSafePlaces && nearestSafePlaces.length > 0) {
      safePlacesHtml = `
        <h2>Nearest Safe Places:</h2>
        <ul>
          ${nearestSafePlaces.map(place =>
            `<li><b>${place.name}</b> (${place.type}) - ${place.distance} km
             <br><a href="${place.mapLink}">View on Map</a></li>`
          ).join('')}
        </ul>
      `;
    }

    const safetyPrecautions = [
      "Move to higher ground immediately.",
      "Avoid walking or driving through flood waters.",
      "Keep a flashlight, battery, and emergency supplies handy.",
      "Disconnect electrical appliances if water enters your home.",
      "Stay tuned to official updates and helpline numbers."
    ];

    // Prepare message based on risk level
    let subject, htmlMessage;
    
    if (cityRisk === 'high') {
      subject = `🚨 HIGH FLOOD ALERT - ${city}`;
      htmlMessage = `
        <h1 style="color: red;">🚨 HIGH FLOOD ALERT - ${city}</h1>
        <p><strong>Flood risk level: HIGH</strong></p>
        <h2>Safety Precautions:</h2>
        <ul>${safetyPrecautions.map(precaution => `<li>${precaution}</li>`).join('')}</ul>
        ${safePlacesHtml}
        <h2>Emergency Numbers:</h2>
        <ul>
          <li>Fire: 101</li>
          <li>Police: 100</li>
          <li>Ambulance: 108</li>
        </ul>
        <p><strong>Stay Safe!</strong></p>
      `;
    } else if (cityRisk === 'moderate') {
      subject = `⚠️ MODERATE FLOOD ALERT - ${city}`;
      htmlMessage = `
        <h1 style="color: orange;">⚠️ MODERATE FLOOD ALERT - ${city}</h1>
        <p><strong>Flood risk level: MODERATE</strong></p>
        <h2>Safety Precautions:</h2>
        <ul>${safetyPrecautions.map(precaution => `<li>${precaution}</li>`).join('')}</ul>
        ${safePlacesHtml}
        <h2>Emergency Numbers:</h2>
        <ul>
          <li>Fire: 101</li>
          <li>Police: 100</li>
          <li>Ambulance: 108</li>
        </ul>
        <p><strong>Stay Alert!</strong></p>
      `;
    } else {
      subject = `✅ Flood Status Update - ${city}`;
      htmlMessage = `
        <h1 style="color: green;">✅ Flood Status Update - ${city}</h1>
        <p><strong>Good news! Currently there is LOW flood risk in ${city}.</strong></p>
        <p>We'll keep monitoring and will notify you if the situation changes.</p>
        ${safePlacesHtml}
        <h2>Emergency Numbers (for reference):</h2>
        <ul>
          <li>Fire: 101</li>
          <li>Police: 100</li>
          <li>Ambulance: 108</li>
        </ul>
        <p><strong>Stay Safe!</strong></p>
      `;
    }

    // Send email
    await sendEmail(email, subject, htmlMessage);

    res.status(200).json({ 
      success: true,
      message: `Flood alert for ${city} sent successfully to ${email}`,
      riskLevel: cityRisk
    });

  } catch (error) {
    console.error('❌ Error sending direct alert:', error);
    res.status(500).json({ error: `Failed to send alert. Error: ${error.message}` });
  }
});

// Quick test endpoint to send demo alert
router.post('/test', async (req, res) => {
  try {
    const { email, city = 'Mumbai' } = req.body;
    
    if (!email) {
      return res.status(400).json({ 
        success: false,
        error: 'Email is required for test alert' 
      });
    }

    // Send test flood alert email
    const testAlertHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background-color: #d97706; color: white; padding: 20px; text-align: center;">
          <h1 style="margin: 0;">🚨 TEST FLOOD ALERT - ${city.toUpperCase()}</h1>
          <p style="margin: 5px 0; font-size: 18px;">Alert Level: MEDIUM (TEST)</p>
        </div>
        
        <div style="padding: 20px;">
          <h2 style="color: #1f2937;">📢 This is a Test Alert</h2>
          <div style="background-color: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; margin: 20px 0;">
            <p style="margin: 0; font-size: 16px; line-height: 1.5;">
              Heavy rainfall expected in ${city} area. Water levels rising in low-lying areas. 
              This is a test message to verify the flood alert system is working properly.
            </p>
          </div>
          
          <div style="background-color: #dbeafe; border: 1px solid #93c5fd; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <p style="margin: 0; color: #1e40af; font-weight: bold;">
              ✅ Test Alert Successful! Your flood alert system is working properly.
            </p>
          </div>
          
          <p style="color: #6b7280; font-size: 14px;">
            Test sent: ${new Date().toLocaleString()}<br>
            Location: ${city}<br>
            This was a test of the emergency alert system.
          </p>
        </div>
      </div>
    `;

    await sendEmail(
      email,
      `🧪 TEST: Flood Alert System for ${city}`,
      testAlertHtml
    );
    
    res.json({
      success: true,
      message: `Test flood alert sent to ${email}`,
      city: city,
      timestamp: new Date().toISOString(),
      note: 'This was a test alert to verify the system is working'
    });
    
  } catch (error) {
    console.error('❌ Error sending test alert:', error.message);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;