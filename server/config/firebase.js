// Simple Firebase configuration without admin SDK
const { initializeApp } = require('firebase/app');
const { getFirestore, connectFirestoreEmulator } = require('firebase/firestore');

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyDHYESdlMPD1svkbGa1R_c2ZKZQ_a44pfE",
  authDomain: "flood-66d6c.firebaseapp.com",
  projectId: "flood-66d6c",
  storageBucket: "flood-66d6c.firebasestorage.app",
  messagingSenderId: "684291810558",
  appId: "1:684291810558:web:0be43308aa4ad8907fb1af",
  measurementId: "G-BTCYY5GV69"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firestore Database
const db = getFirestore(app);

module.exports = { db };
