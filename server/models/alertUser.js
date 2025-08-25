// Firebase Alert User Model for storing registered users
const { db } = require('../config/firebase');
const { 
  collection, 
  doc, 
  addDoc, 
  getDocs, 
  query, 
  where, 
  Timestamp,
  updateDoc,
  increment
} = require('firebase/firestore');

const ALERT_USERS_COLLECTION = 'alertUsers';

class AlertUser {
  // Create new alert user
  static async create(userData) {
    try {
      const docRef = await addDoc(collection(db, ALERT_USERS_COLLECTION), {
        ...userData,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now()
      });
      return { id: docRef.id, ...userData };
    } catch (error) {
      throw new Error('Error creating alert user: ' + error.message);
    }
  }

  // Find users by city (case-insensitive and flexible matching)
  static async findByCity(cityName) {
    try {
      const q = query(collection(db, ALERT_USERS_COLLECTION));
      const querySnapshot = await getDocs(q);
      
      const users = [];
      querySnapshot.forEach((doc) => {
        const userData = doc.data();
        // Flexible city matching - normalize both strings for comparison
        const userCity = userData.city.toLowerCase().trim();
        const searchCity = cityName.toLowerCase().trim();
        
        // Match exact city or if search city is contained in user city
        if (userCity === searchCity || 
            userCity.includes(searchCity) || 
            searchCity.includes(userCity)) {
          users.push({ id: doc.id, ...userData });
        }
      });
      
      return users;
    } catch (error) {
      throw new Error('Error finding users by city: ' + error.message);
    }
  }

  // Find user by email
  static async findByEmail(email) {
    try {
      const q = query(collection(db, ALERT_USERS_COLLECTION), where("email", "==", email));
      const querySnapshot = await getDocs(q);
      
      if (querySnapshot.empty) {
        return null;
      }
      
      const docData = querySnapshot.docs[0];
      return { id: docData.id, ...docData.data() };
    } catch (error) {
      throw new Error('Error finding user by email: ' + error.message);
    }
  }

  // Get all alert users
  static async getAll() {
    try {
      const querySnapshot = await getDocs(collection(db, ALERT_USERS_COLLECTION));
      const users = [];
      querySnapshot.forEach((doc) => {
        users.push({ id: doc.id, ...doc.data() });
      });
      return users;
    } catch (error) {
      throw new Error('Error getting all users: ' + error.message);
    }
  }

  // Register user for alerts (when they signup)
  static async registerForAlerts(email, city, name = '', contact = '') {
    try {
      // Check if user already registered for this city
      const existingUser = await this.findByEmail(email);
      
      if (existingUser) {
        console.log(`User ${email} already registered for alerts`);
        return existingUser;
      }

      // Create new alert registration
      const alertUser = await this.create({
        email: email,
        city: city.toLowerCase().trim(),
        name: name || email.split('@')[0], // Use email prefix if no name
        contact: contact || '',
        isActive: true,
        alertsReceived: 0
      });

      console.log(`✅ User ${email} registered for ${city} flood alerts`);
      return alertUser;
    } catch (error) {
      throw new Error('Error registering user for alerts: ' + error.message);
    }
  }

  // Increment alert count for a user
  static async incrementAlertCount(userId) {
    try {
      const userRef = doc(db, ALERT_USERS_COLLECTION, userId);
      await updateDoc(userRef, {
        alertsReceived: increment(1),
        lastAlertAt: Timestamp.now()
      });
      console.log(`✅ Incremented alert count for user ${userId}`);
    } catch (error) {
      console.error('❌ Error incrementing alert count:', error);
      throw error;
    }
  }
}

module.exports = AlertUser;
