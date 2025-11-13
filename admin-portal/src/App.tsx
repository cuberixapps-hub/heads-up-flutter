import React, { useState, useEffect } from 'react';
import { signInAnonymously, onAuthStateChanged } from 'firebase/auth';
import type { User } from 'firebase/auth';
import { auth } from './config/firebase';
import { DeckList } from './components/DeckList';
import { DeckForm } from './components/DeckForm';
import { DailyDeckManager } from './components/DailyDeckManager';
import { AIDeckGenerator } from './components/AIDeckGenerator';
import { ImageGeneratorTest } from './components/ImageGeneratorTest';
import './App.css';

interface Deck {
  id?: string;
  name: string;
  description: string;
  cards: string[];
  iconCodePoint: number;
  iconFontFamily: string;
  iconFontPackage?: string;
  colorValue: number;
  isPremium: boolean;
  country?: string;
  tags?: string[];
  priority?: number;
  isActive?: boolean;
  createdAt?: any;
  updatedAt?: any;
}

function App() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [currentView, setCurrentView] = useState<'list' | 'form' | 'daily' | 'ai' | 'test'>('list');
  const [editingDeck, setEditingDeck] = useState<Deck | undefined>(undefined);
  const [activeTab, setActiveTab] = useState<'decks' | 'daily' | 'ai' | 'test'>('decks');

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

  const handleEdit = (deck: Deck) => {
    setEditingDeck(deck);
    setCurrentView('form');
  };

  const handleCreate = () => {
    setEditingDeck(undefined);
    setCurrentView('form');
  };

  const handleSave = () => {
    setCurrentView('list');
    setEditingDeck(undefined);
  };

  const handleCancel = () => {
    setCurrentView('list');
    setEditingDeck(undefined);
  };

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
          <div className="tabs">
            <button
              className={`tab ${activeTab === 'decks' ? 'active' : ''}`}
              onClick={() => {
                setActiveTab('decks');
                setCurrentView('list');
              }}
            >
              <span className="tab-icon">🎮</span>
              Regular Decks
            </button>
            <button
              className={`tab ${activeTab === 'daily' ? 'active' : ''}`}
              onClick={() => {
                setActiveTab('daily');
                setCurrentView('daily');
              }}
            >
              <span className="tab-icon">📅</span>
              Daily Heads Up
            </button>
            <button
              className={`tab ${activeTab === 'ai' ? 'active' : ''}`}
              onClick={() => {
                setActiveTab('ai');
                setCurrentView('ai');
              }}
            >
              <span className="tab-icon">✨</span>
              AI Generator
            </button>
            <button
              className={`tab ${activeTab === 'test' ? 'active' : ''}`}
              onClick={() => {
                setActiveTab('test');
                setCurrentView('test');
              }}
            >
              <span className="tab-icon">🧪</span>
              Image Test
            </button>
          </div>
        </div>

        <div className="tab-content">
          {activeTab === 'decks' && (
            currentView === 'list' ? (
              <DeckList onEdit={handleEdit} onCreate={handleCreate} />
            ) : (
              <DeckForm
                deck={editingDeck}
                onSave={handleSave}
                onCancel={handleCancel}
              />
            )
          )}
          {activeTab === 'daily' && <DailyDeckManager />}
          {activeTab === 'ai' && <AIDeckGenerator />}
          {activeTab === 'test' && <ImageGeneratorTest />}
        </div>
      </main>
    </div>
  );
}

export default App;