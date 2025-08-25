const express = require('express');
const jwt = require('jsonwebtoken');
const FirestoreUser = require('../models/firestoreUser');

const router = express.Router();

// Signup route
router.post('/signup', async (req, res) => {
    try {
        const { email, city } = req.body;

        // Validate required fields
        if (!email || !city) {
            return res.status(400).json({ 
                success: false,
                error: 'Email and city are required fields.' 
            });
        }

        // Check if user already exists
        const existingUser = await FirestoreUser.findByEmail(email);
        if (existingUser) {
            return res.status(400).json({ 
                success: false,
                error: 'User with this email already exists.' 
            });
        }

        // Create new user with minimal data (no password)
        const userData = {
            email,
            city
        };

        const savedUser = await FirestoreUser.create(userData);

        // Generate JWT token
        const token = jwt.sign(
            { id: savedUser.id }, 
            process.env.JWT_SECRET || 'your_jwt_secret', 
            { expiresIn: '1h' }
        );

        res.status(201).json({
            success: true,
            message: 'User registered successfully!',
            token,
            user: {
                id: savedUser.id,
                email: savedUser.email,
                city: savedUser.city
            }
        });
    } catch (error) {
        console.error('Signup error:', error);
        res.status(500).json({ 
            success: false,
            error: 'Internal server error: ' + error.message 
        });
    }
});

// Login route (email only login)
router.post('/login', async (req, res) => {
    try {
        const { email } = req.body;

        // Validate required field
        if (!email) {
            return res.status(400).json({ 
                success: false,
                error: 'Email is required.' 
            });
        }

        // Find user by email
        const user = await FirestoreUser.findByEmail(email);
        if (!user) {
            return res.status(400).json({ 
                success: false,
                error: 'User not found with this email.' 
            });
        }

        // Generate JWT token (no password verification needed)
        const token = jwt.sign(
            { id: user.id }, 
            process.env.JWT_SECRET || 'your_jwt_secret', 
            { expiresIn: '1h' }
        );

        res.status(200).json({
            success: true,
            message: 'Login successful!',
            token,
            user: {
                id: user.id,
                email: user.email,
                city: user.city
            }
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ 
            success: false,
            error: 'Internal server error: ' + error.message 
        });
    }
});

// Get user profile route
router.get('/profile/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const user = await FirestoreUser.findById(id);
        
        if (!user) {
            return res.status(404).json({ 
                success: false,
                error: 'User not found.' 
            });
        }

        res.status(200).json({
            success: true,
            user: {
                id: user.id,
                email: user.email,
                city: user.city
            }
        });
    } catch (error) {
        console.error('Profile fetch error:', error);
        res.status(500).json({ 
            success: false,
            error: 'Internal server error: ' + error.message 
        });
    }
});

module.exports = router;
