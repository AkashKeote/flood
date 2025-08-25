const twilio = require('twilio');
const nodemailer = require('nodemailer');

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const client = twilio(accountSid, authToken);

// Nodemailer setup
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
    },
});

// 📩 Email Sender
exports.sendEmail = async (to, subject, html) => {
    try {
        await transporter.sendMail({
            from: process.env.EMAIL_USER,
            to: to,
            subject: subject,
            html: html,
        });
        console.log(`✅ Email sent to ${to}`);
    } catch (error) {
        console.error(`❌ Error sending Email to ${to}:`, error.message);
    }
};

// 📱 SMS Sender
exports.sendSMS = async (to, message) => {
    try {
        const sanitizedNumber = to.toString().replace(/[\s\+]/g, '');
        const formattedNumber = `+91${sanitizedNumber.replace(/^91/, '')}`;

        await client.messages.create({
            body: message,
            from: process.env.TWILIO_PHONE_NUMBER,
            to: formattedNumber,
        });

        console.log(`✅ SMS sent to ${formattedNumber}`);
    } catch (error) {
        console.error(`Error sending SMS:`, error.message);
    }
};
