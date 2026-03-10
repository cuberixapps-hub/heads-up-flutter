import { useState, useEffect } from 'react';
import { Outlet, NavLink } from 'react-router-dom';
import { signInAnonymously, onAuthStateChanged } from 'firebase/auth';
import type { User } from 'firebase/auth';
import { auth } from '../config/firebase';
import '../styles/Layout.css';

export function Layout() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (user) {
        setUser(user);
      } else {
        // Sign in anonymously
        try {
          await signInAnonymously(auth);
        } catch (error) {
          console.error('Error signing in:', error);
        }
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  if (loading) {
    return (
      <div className="app-loading">
        <div className="loading-spinner"></div>
        <h2>Loading Admin Portal...</h2>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="app-error">
        <h2>Authentication Error</h2>
        <p>Please refresh the page to try again.</p>
      </div>
    );
  }

  return (
    <div className="app">
      <header className="app-header">
        <div className="header-container">
          <div className="logo">
            <span className="logo-icon">🎮</span>
            <h1>Heads Up! Admin</h1>
          </div>
          <div className="user-info">
            <span className="user-status">
              <span className="status-dot"></span>
              Connected to Firebase
            </span>
          </div>
        </div>
      </header>

      <main className="app-main">
        <div className="tabs-container">
          <nav className="tabs">
            <NavLink to="/" className={({ isActive }) => `tab ${isActive ? 'active' : ''}`} end>
              <span className="tab-icon">🎮</span>
              Regular Decks
            </NavLink>
            <NavLink to="/daily" className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>
              <span className="tab-icon">📅</span>
              Daily Heads Up
            </NavLink>
            <NavLink to="/initial-decks" className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>
              <span className="tab-icon">🌍</span>
              Initial Decks
            </NavLink>
            <NavLink to="/ai-generator" className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>
              <span className="tab-icon">✨</span>
              AI Generator
            </NavLink>
            <NavLink to="/automated" className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>
              <span className="tab-icon">🤖</span>
              Automated
            </NavLink>
            <NavLink to="/image-test" className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>
              <span className="tab-icon">🧪</span>
              Image Test
            </NavLink>
          </nav>
        </div>

        <div className="tab-content">
          <Outlet />
        </div>
      </main>
    </div>
  );
}

