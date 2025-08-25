const express = require('express');
const User = require('../models/userModel');
const { sendSMS, sendEmail } = require('../services/notification');
const { getFloodRiskByCity } = require('../services/floodApi');
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

        const users = await User.find({ city });
        if (users.length === 0) {
            return res.status(200).json({ message: 'No users found for this city.' });
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
                    <p>Hi ${user.name}, your area is at a <b>${cityRisk}</b> flood risk. Please stay safe!</p>
                    ${safePlacesHtml}
                    ${appLinkHtml}
                `;

                if (user.contact) {
                    await sendSMS(user.contact, smsMessage);
                }

                if (user.email) {
                    await sendEmail(user.email, emailSubject, emailHtml);
                }
            }

            return res.status(200).json({
                message: `✅ SMS + Email alerts sent for ${city} (${cityRisk} risk).`
            });
        }

        res.status(200).json({ message: `No alerts sent. Risk level for ${city} is ${cityRisk}.` });

    } catch (error) {
        console.error('❌ Error sending alerts:', error);
        res.status(500).json({ error: `Failed to send alerts for ${req.body.city}. Error: ${error.message}` });
    }
});

module.exports = router;