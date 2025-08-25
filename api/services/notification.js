const nodemailer = require('nodemailer');
const twilio = require('twilio');

// Email configuration
const emailTransporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS
    }
});

// SMS configuration - only initialize if credentials are available
let smsClient = null;
if (process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN) {
    smsClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
}

async function sendEmail(to, subject, text, html) {
    try {
        const mailOptions = {
            from: process.env.EMAIL_USER,
            to: to,
            subject: subject,
            text: text,
            html: html
        };

        const result = await emailTransporter.sendMail(mailOptions);
        console.log('Email sent:', result.messageId);
        return { success: true, messageId: result.messageId };
    } catch (error) {
        console.error('Email error:', error);
        return { success: false, error: error.message };
    }
}

async function sendSMS(to, body) {
    if (!smsClient) {
        console.log('SMS not configured - Twilio credentials missing');
        return { success: false, error: 'SMS service not configured' };
    }
    
    try {
        const message = await smsClient.messages.create({
            body: body,
            from: process.env.TWILIO_PHONE_NUMBER,
            to: to
        });

        console.log('SMS sent:', message.sid);
        return { success: true, sid: message.sid };
    } catch (error) {
        console.error('SMS error:', error);
        return { success: false, error: error.message };
    }
}

module.exports = { sendEmail, sendSMS };
