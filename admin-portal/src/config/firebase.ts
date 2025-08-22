import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyA1C_hCbUz0fAf0HjnZcfw1yN5cmkNPflM",
  authDomain: "heads-up-game-48f14.firebaseapp.com",
  projectId: "heads-up-game-48f14",
  storageBucket: "heads-up-game-48f14.firebasestorage.app",
  messagingSenderId: "169350826692",
  appId: "1:169350826692:web:headsupwebapp" // Using a placeholder web app ID
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
