// Firestore User Model
const { db } = require('../config/firebase');
const { 
  collection, 
  doc, 
  addDoc, 
  getDoc, 
  getDocs, 
  query, 
  where, 
  updateDoc, 
  deleteDoc,
  Timestamp 
} = require('firebase/firestore');

const COLLECTION_NAME = 'users';

class FirestoreUser {
  // Create new user
  static async create(userData) {
    try {
      const docRef = await addDoc(collection(db, COLLECTION_NAME), {
        ...userData,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now()
      });
      return { id: docRef.id, ...userData };
    } catch (error) {
      throw new Error('Error creating user: ' + error.message);
    }
  }

  // Find user by email
  static async findByEmail(email) {
    try {
      const q = query(collection(db, COLLECTION_NAME), where("email", "==", email));
      const querySnapshot = await getDocs(q);
      
      if (querySnapshot.empty) {
        return null;
      }
      
      const docData = querySnapshot.docs[0];
      return { id: docData.id, ...docData.data() };
    } catch (error) {
      throw new Error('Error finding user: ' + error.message);
    }
  }

  // Find user by ID
  static async findById(id) {
    try {
      const docRef = doc(db, COLLECTION_NAME, id);
      const docSnap = await getDoc(docRef);
      
      if (docSnap.exists()) {
        return { id: docSnap.id, ...docSnap.data() };
      } else {
        return null;
      }
    } catch (error) {
      throw new Error('Error finding user by ID: ' + error.message);
    }
  }

  // Update user
  static async update(id, updateData) {
    try {
      const docRef = doc(db, COLLECTION_NAME, id);
      await updateDoc(docRef, {
        ...updateData,
        updatedAt: Timestamp.now()
      });
      return { id, ...updateData };
    } catch (error) {
      throw new Error('Error updating user: ' + error.message);
    }
  }

  // Delete user
  static async delete(id) {
    try {
      const docRef = doc(db, COLLECTION_NAME, id);
      await deleteDoc(docRef);
      return true;
    } catch (error) {
      throw new Error('Error deleting user: ' + error.message);
    }
  }

  // Get all users
  static async getAll() {
    try {
      const querySnapshot = await getDocs(collection(db, COLLECTION_NAME));
      const users = [];
      querySnapshot.forEach((doc) => {
        users.push({ id: doc.id, ...doc.data() });
      });
      return users;
    } catch (error) {
      throw new Error('Error getting users: ' + error.message);
    }
  }
}

module.exports = FirestoreUser;
