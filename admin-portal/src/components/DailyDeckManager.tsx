import React, { useState, useEffect } from 'react';
import {
    collection,
    addDoc,
    updateDoc,
    deleteDoc,
    doc,
    onSnapshot,
    query,
    orderBy,
    Timestamp
} from 'firebase/firestore';
import { db } from '../config/firebase';
import '../styles/DailyDeckManager.css';

interface DailyDeck {
    id?: string;
    date: Date;
    title: string;
    description: string;
    cards: Array<{
        word: string;
        category: string;
        difficulty: number;
    }>;
    color: number;
    iconName: string;
    imageUrl?: string;
    isActive: boolean;
    createdAt: Date;
    expiresAt?: Date;
}

export const DailyDeckManager: React.FC = () => {
    const [dailyDecks, setDailyDecks] = useState<DailyDeck[]>([]);
    const [loading, setLoading] = useState(true);
    const [isFormOpen, setIsFormOpen] = useState(false);
    const [editingDeck, setEditingDeck] = useState<DailyDeck | null>(null);
    const [formData, setFormData] = useState<Partial<DailyDeck>>({
        title: '',
        description: '',
        cards: [],
        color: 0xFF4CAF50,
        iconName: 'calendar_today',
        imageUrl: '',
        isActive: true,
    });
    const [newCard, setNewCard] = useState({ word: '', category: '', difficulty: 1 });
    const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]);

    useEffect(() => {
        // Load daily decks from Firebase
        const q = query(
            collection(db, 'daily_decks'),
            orderBy('date', 'desc')
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const decks: DailyDeck[] = [];
            snapshot.forEach((doc) => {
                const data = doc.data();
                decks.push({
                    id: doc.id,
                    date: data.date?.toDate() || new Date(),
                    title: data.title || '',
                    description: data.description || '',
                    cards: data.cards || [],
                    color: data.color || 0xFF4CAF50,
                    iconName: data.iconName || 'calendar_today',
                    isActive: data.isActive ?? true,
                    createdAt: data.createdAt?.toDate() || new Date(),
                    expiresAt: data.expiresAt?.toDate(),
                });
            });
            setDailyDecks(decks);
            setLoading(false);
        });

        return () => unsubscribe();
    }, []);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        try {
            const deckData = {
                ...formData,
                date: Timestamp.fromDate(new Date(selectedDate)),
                createdAt: Timestamp.now(),
                expiresAt: formData.expiresAt ? Timestamp.fromDate(formData.expiresAt) : null,
            };

            if (editingDeck?.id) {
                // Update existing deck
                await updateDoc(doc(db, 'daily_decks', editingDeck.id), deckData);
            } else {
                // Create new deck
                await addDoc(collection(db, 'daily_decks'), deckData);
            }

            // Reset form
            setIsFormOpen(false);
            setEditingDeck(null);
            setFormData({
                title: '',
                description: '',
                cards: [],
                color: 0xFF4CAF50,
                iconName: 'calendar_today',
                imageUrl: '',
                isActive: true,
            });
            setSelectedDate(new Date().toISOString().split('T')[0]);
        } catch (error) {
            console.error('Error saving daily deck:', error);
            alert('Failed to save daily deck');
        }
    };

    const handleDelete = async (id: string) => {
        if (window.confirm('Are you sure you want to delete this daily deck?')) {
            try {
                await deleteDoc(doc(db, 'daily_decks', id));
            } catch (error) {
                console.error('Error deleting daily deck:', error);
                alert('Failed to delete daily deck');
            }
        }
    };

    const handleEdit = (deck: DailyDeck) => {
        setEditingDeck(deck);
        setFormData({
            title: deck.title,
            description: deck.description,
            cards: deck.cards,
            color: deck.color,
            iconName: deck.iconName,
            isActive: deck.isActive,
        });
        setSelectedDate(deck.date.toISOString().split('T')[0]);
        setIsFormOpen(true);
    };

    const handleAddCard = () => {
        if (newCard.word.trim()) {
            setFormData({
                ...formData,
                cards: [...(formData.cards || []), newCard],
            });
            setNewCard({ word: '', category: '', difficulty: 1 });
        }
    };

    const handleRemoveCard = (index: number) => {
        const updatedCards = [...(formData.cards || [])];
        updatedCards.splice(index, 1);
        setFormData({ ...formData, cards: updatedCards });
    };

    const formatDate = (date: Date) => {
        return new Intl.DateTimeFormat('en-US', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric',
        }).format(date);
    };

    const isToday = (date: Date) => {
        const today = new Date();
        return date.toDateString() === today.toDateString();
    };

    const isFuture = (date: Date) => {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        return date > today;
    };

    if (loading) {
        return <div className="loading">Loading daily decks...</div>;
    }

    return (
        <div className="daily-deck-manager">
            <div className="manager-header">
                <h2>Daily Heads Up Manager</h2>
                <button
                    className="btn-primary"
                    onClick={() => setIsFormOpen(true)}
                >
                    + Create Daily Deck
                </button>
            </div>

            {isFormOpen && (
                <div className="modal-overlay">
                    <div className="modal-content">
                        <h3>{editingDeck ? 'Edit' : 'Create'} Daily Deck</h3>
                        <form onSubmit={handleSubmit}>
                            <div className="form-group">
                                <label>Date</label>
                                <input
                                    type="date"
                                    value={selectedDate}
                                    onChange={(e) => setSelectedDate(e.target.value)}
                                    required
                                />
                            </div>

                            <div className="form-group">
                                <label>Title</label>
                                <input
                                    type="text"
                                    value={formData.title}
                                    onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                                    placeholder="e.g., Monday Madness"
                                    required
                                />
                            </div>

                            <div className="form-group">
                                <label>Description</label>
                                <textarea
                                    value={formData.description}
                                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                                    placeholder="Brief description of today's challenge"
                                    rows={3}
                                    required
                                />
                            </div>

                            <div className="form-group">
                                <label>Image URL</label>
                                <input
                                    type="url"
                                    value={formData.imageUrl || ''}
                                    onChange={(e) => setFormData({ ...formData, imageUrl: e.target.value })}
                                    placeholder="https://example.com/image.jpg (optional)"
                                />
                                {formData.imageUrl && (
                                    <div style={{ marginTop: '10px' }}>
                                        <img
                                            src={formData.imageUrl}
                                            alt="Daily deck preview"
                                            style={{
                                                width: '100%',
                                                maxWidth: '200px',
                                                height: '120px',
                                                objectFit: 'cover',
                                                borderRadius: '8px',
                                                border: '1px solid #e0e0e0'
                                            }}
                                            onError={(e) => {
                                                (e.target as HTMLImageElement).style.display = 'none';
                                            }}
                                        />
                                    </div>
                                )}
                            </div>

                            <div className="form-group">
                                <label>Color (Hex)</label>
                                <input
                                    type="text"
                                    value={`#${(formData.color || 0xFF4CAF50).toString(16).slice(2)}`}
                                    onChange={(e) => {
                                        const hex = e.target.value.replace('#', '');
                                        setFormData({ ...formData, color: parseInt(`FF${hex}`, 16) });
                                    }}
                                    placeholder="#4CAF50"
                                />
                            </div>

                            <div className="form-group">
                                <label>Icon Name</label>
                                <select
                                    value={formData.iconName}
                                    onChange={(e) => setFormData({ ...formData, iconName: e.target.value })}
                                >
                                    <option value="calendar_today">Calendar</option>
                                    <option value="star">Star</option>
                                    <option value="trending_up">Trending</option>
                                    <option value="celebration">Celebration</option>
                                    <option value="today">Today</option>
                                </select>
                            </div>

                            <div className="form-group">
                                <label>
                                    <input
                                        type="checkbox"
                                        checked={formData.isActive}
                                        onChange={(e) => setFormData({ ...formData, isActive: e.target.checked })}
                                    />
                                    Active
                                </label>
                            </div>

                            <div className="form-group">
                                <label>Cards</label>
                                <div className="card-input-group">
                                    <input
                                        type="text"
                                        value={newCard.word}
                                        onChange={(e) => setNewCard({ ...newCard, word: e.target.value })}
                                        placeholder="Card word"
                                    />
                                    <input
                                        type="text"
                                        value={newCard.category}
                                        onChange={(e) => setNewCard({ ...newCard, category: e.target.value })}
                                        placeholder="Category"
                                    />
                                    <select
                                        value={newCard.difficulty}
                                        onChange={(e) => setNewCard({ ...newCard, difficulty: parseInt(e.target.value) })}
                                    >
                                        <option value={1}>Easy</option>
                                        <option value={2}>Medium</option>
                                        <option value={3}>Hard</option>
                                    </select>
                                    <button type="button" onClick={handleAddCard}>Add</button>
                                </div>

                                <div className="cards-list">
                                    {formData.cards?.map((card, index) => (
                                        <div key={index} className="card-item">
                                            <span>{card.word} - {card.category} (Level {card.difficulty})</span>
                                            <button type="button" onClick={() => handleRemoveCard(index)}>×</button>
                                        </div>
                                    ))}
                                </div>
                            </div>

                            <div className="form-actions">
                                <button type="submit" className="btn-primary">
                                    {editingDeck ? 'Update' : 'Create'}
                                </button>
                                <button
                                    type="button"
                                    className="btn-secondary"
                                    onClick={() => {
                                        setIsFormOpen(false);
                                        setEditingDeck(null);
                                        setFormData({
                                            title: '',
                                            description: '',
                                            cards: [],
                                            color: 0xFF4CAF50,
                                            iconName: 'calendar_today',
                                            isActive: true,
                                        });
                                    }}
                                >
                                    Cancel
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            <div className="daily-decks-grid">
                {dailyDecks.map((deck) => (
                    <div
                        key={deck.id}
                        className={`daily-deck-card ${isToday(deck.date) ? 'today' : ''} ${isFuture(deck.date) ? 'future' : 'past'}`}
                    >
                        <div className="deck-header">
                            <div className="deck-date">
                                {formatDate(deck.date)}
                                {isToday(deck.date) && <span className="badge today">TODAY</span>}
                                {isFuture(deck.date) && <span className="badge future">UPCOMING</span>}
                            </div>
                            <div className="deck-status">
                                <span className={`status-indicator ${deck.isActive ? 'active' : 'inactive'}`}>
                                    {deck.isActive ? '✓ Active' : '× Inactive'}
                                </span>
                            </div>
                        </div>

                        <div className="deck-content">
                            <h3>{deck.title}</h3>
                            <p>{deck.description}</p>
                            <div className="deck-stats">
                                <span>📝 {deck.cards.length} cards</span>
                                <span style={{ color: `#${deck.color.toString(16).slice(2)}` }}>
                                    ● Color
                                </span>
                                <span>🎯 {deck.iconName}</span>
                            </div>
                        </div>

                        <div className="deck-actions">
                            <button onClick={() => handleEdit(deck)}>Edit</button>
                            <button onClick={() => handleDelete(deck.id!)} className="btn-danger">
                                Delete
                            </button>
                        </div>
                    </div>
                ))}
            </div>

            {dailyDecks.length === 0 && (
                <div className="empty-state">
                    <p>No daily decks created yet.</p>
                    <button className="btn-primary" onClick={() => setIsFormOpen(true)}>
                        Create Your First Daily Deck
                    </button>
                </div>
            )}
        </div>
    );
};
