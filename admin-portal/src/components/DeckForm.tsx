import React, { useState, useEffect } from 'react';
import { collection, addDoc, updateDoc, doc, serverTimestamp } from 'firebase/firestore';
import { db } from '../config/firebase';
import { IconPicker } from './IconPicker';
import { type IconInfo } from '../data/icons';
import { Plus, X, Sparkles, Palette, Save, ArrowLeft } from 'lucide-react';
import * as FaIcons from 'react-icons/fa';
import '../styles/DeckForm.css';

interface Deck {
    id?: string;
    name: string;
    description: string;
    cards: string[];
    iconCodePoint: number;
    iconFontFamily: string;
    iconFontPackage?: string;
    colorValue: number;
    imageUrl?: string;
    isPremium: boolean;
    createdAt?: any;
    updatedAt?: any;
}

interface DeckFormProps {
    deck?: Deck;
    onSave: () => void;
    onCancel: () => void;
}

const defaultColors = [
    { name: 'Purple', value: 0xFF9C27B0 },
    { name: 'Blue', value: 0xFF2196F3 },
    { name: 'Green', value: 0xFF4CAF50 },
    { name: 'Orange', value: 0xFFFF9800 },
    { name: 'Red', value: 0xFFF44336 },
    { name: 'Teal', value: 0xFF009688 },
    { name: 'Indigo', value: 0xFF3F51B5 },
    { name: 'Pink', value: 0xFFE91E63 },
    { name: 'Amber', value: 0xFFFFC107 },
    { name: 'Deep Purple', value: 0xFF673AB7 },
];

export const DeckForm: React.FC<DeckFormProps> = ({ deck, onSave, onCancel }) => {
    const [name, setName] = useState(deck?.name || '');
    const [description, setDescription] = useState(deck?.description || '');
    const [cards, setCards] = useState<string[]>(deck?.cards || []);
    const [newCard, setNewCard] = useState('');
    const [selectedIcon, setSelectedIcon] = useState<IconInfo | null>({
        icon: FaIcons.FaStar,
        name: 'solidStar',
        codePoint: deck?.iconCodePoint || 0xf005,
        fontFamily: deck?.iconFontFamily || 'FontAwesomeIcons'
    });
    const [selectedColor, setSelectedColor] = useState(deck?.colorValue || 0xFF9C27B0);
    const [imageUrl, setImageUrl] = useState(deck?.imageUrl || '');
    const [isPremium, setIsPremium] = useState(deck?.isPremium || false);
    const [showIconPicker, setShowIconPicker] = useState(false);
    const [showColorPicker, setShowColorPicker] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
    const [errors, setErrors] = useState<{ [key: string]: string }>({});
    const [showAISuggestions, setShowAISuggestions] = useState(false);
    const [aiSuggestions, setAiSuggestions] = useState<string[]>([]);

    const validateForm = () => {
        const newErrors: { [key: string]: string } = {};

        if (!name.trim()) {
            newErrors.name = 'Deck name is required';
        }

        if (cards.length < 5) {
            newErrors.cards = 'At least 5 cards are required';
        }

        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (!validateForm()) {
            return;
        }

        setIsLoading(true);

        const deckData: any = {
            name: name.trim(),
            description: description.trim(),
            cards,
            iconCodePoint: selectedIcon?.codePoint || 0xf005,
            iconFontFamily: selectedIcon?.fontFamily || 'FontAwesomeIcons',
            colorValue: selectedColor,
            imageUrl: imageUrl.trim() || null,
            isPremium,
            updatedAt: serverTimestamp(),
        };

        // Only add iconFontPackage if it exists
        if (selectedIcon?.fontPackage) {
            deckData.iconFontPackage = selectedIcon.fontPackage;
        }

        try {
            if (deck?.id) {
                // Update existing deck
                await updateDoc(doc(db, 'decks', deck.id), deckData);
            } else {
                // Create new deck
                await addDoc(collection(db, 'decks'), {
                    ...deckData,
                    createdAt: serverTimestamp(),
                });
            }
            onSave();
        } catch (error) {
            console.error('Error saving deck:', error);
            alert('Failed to save deck. Please try again.');
        } finally {
            setIsLoading(false);
        }
    };

    const addCard = () => {
        if (newCard.trim()) {
            setCards([...cards, newCard.trim()]);
            setNewCard('');
            setErrors({ ...errors, cards: '' });
        }
    };

    const removeCard = (index: number) => {
        setCards(cards.filter((_, i) => i !== index));
    };

    const generateAISuggestions = () => {
        // Generate contextual suggestions based on deck name
        const deckNameLower = deckName.toLowerCase();
        let suggestions: string[] = [];

        if (deckNameLower.includes('movie') || deckNameLower.includes('film')) {
            suggestions = [
                'Titanic', 'Avatar', 'Star Wars', 'The Lion King', 'Inception',
                'The Matrix', 'Toy Story', 'Jurassic Park', 'Harry Potter', 'The Avengers'
            ];
        } else if (deckNameLower.includes('food') || deckNameLower.includes('eat')) {
            suggestions = [
                'Pizza', 'Hamburger', 'Sushi', 'Ice Cream', 'Chocolate',
                'Pasta', 'Tacos', 'Salad', 'French Fries', 'Chicken Wings'
            ];
        } else if (deckNameLower.includes('animal') || deckNameLower.includes('pet')) {
            suggestions = [
                'Lion', 'Elephant', 'Penguin', 'Dolphin', 'Giraffe',
                'Tiger', 'Monkey', 'Kangaroo', 'Eagle', 'Butterfly'
            ];
        } else if (deckNameLower.includes('celebrit') || deckNameLower.includes('famous')) {
            suggestions = [
                'Taylor Swift', 'Tom Cruise', 'Beyoncé', 'Brad Pitt', 'Jennifer Lawrence',
                'Leonardo DiCaprio', 'Emma Watson', 'Chris Hemsworth', 'Scarlett Johansson', 'Robert Downey Jr.'
            ];
        } else if (deckNameLower.includes('sport')) {
            suggestions = [
                'Basketball', 'Soccer', 'Tennis', 'Swimming', 'Golf',
                'Baseball', 'Football', 'Volleyball', 'Boxing', 'Cycling'
            ];
        } else if (deckNameLower.includes('countr') || deckNameLower.includes('place')) {
            suggestions = [
                'France', 'Japan', 'Brazil', 'Australia', 'Canada',
                'Italy', 'Mexico', 'India', 'Egypt', 'Germany'
            ];
        } else if (deckNameLower.includes('music') || deckNameLower.includes('song')) {
            suggestions = [
                'Bohemian Rhapsody', 'Imagine', 'Hey Jude', 'Stairway to Heaven', 'Billie Jean',
                'Hotel California', 'Sweet Child O Mine', 'Wonderwall', 'Smells Like Teen Spirit', 'Let It Be'
            ];
        } else {
            // Generic suggestions if no category detected
            suggestions = [
                'Eiffel Tower', 'Pizza', 'Harry Potter', 'Basketball', 'Paris',
                'Chocolate', 'Superman', 'Guitar', 'Birthday Cake', 'Rainbow'
            ];
        }

        setAiSuggestions(suggestions);
        setShowAISuggestions(true);
    };

    const addAISuggestion = (suggestion: string) => {
        if (!cards.includes(suggestion)) {
            setCards([...cards, suggestion]);
        }
    };

    const addAllAISuggestions = () => {
        const newCards = [...cards];
        aiSuggestions.forEach(suggestion => {
            if (!newCards.includes(suggestion)) {
                newCards.push(suggestion);
            }
        });
        setCards(newCards);
        setShowAISuggestions(false);
    };

    const colorToHex = (colorValue: number): string => {
        return '#' + (colorValue & 0xFFFFFF).toString(16).padStart(6, '0');
    };

    return (
        <div className="deck-form-container">
            <div className="deck-form-header">
                <button className="back-button" onClick={onCancel}>
                    <ArrowLeft size={20} />
                </button>
                <div className="header-content">
                    <h1>{deck ? 'Edit Deck' : 'Create New Deck'}</h1>
                    <p>{deck ? 'Modify your deck details' : 'Build a new custom deck'}</p>
                </div>
                <button
                    className="save-button"
                    onClick={handleSubmit}
                    disabled={isLoading}
                >
                    {isLoading ? (
                        <span className="loading-spinner"></span>
                    ) : (
                        <>
                            <Save size={18} />
                            Save
                        </>
                    )}
                </button>
            </div>

            <form onSubmit={handleSubmit} className="deck-form">
                <div className="form-section">
                    <h3 className="section-title">
                        <span className="section-icon">ℹ️</span>
                        Deck Information
                    </h3>

                    <div className="form-group">
                        <label htmlFor="name">Deck Name *</label>
                        <input
                            id="name"
                            type="text"
                            value={name}
                            onChange={(e) => setName(e.target.value)}
                            placeholder="Enter a unique deck name"
                            className={errors.name ? 'error' : ''}
                        />
                        {errors.name && <span className="error-message">{errors.name}</span>}
                    </div>

                    <div className="form-group">
                        <label htmlFor="description">Description</label>
                        <textarea
                            id="description"
                            value={description}
                            onChange={(e) => setDescription(e.target.value)}
                            placeholder="Describe your deck (optional)"
                            rows={3}
                        />
                    </div>

                    <div className="form-group">
                        <label htmlFor="imageUrl">Image URL</label>
                        <input
                            type="url"
                            id="imageUrl"
                            value={imageUrl}
                            onChange={(e) => setImageUrl(e.target.value)}
                            placeholder="https://example.com/image.jpg (optional)"
                        />
                        {imageUrl && (
                            <div className="image-preview" style={{ marginTop: '10px' }}>
                                <img
                                    src={imageUrl}
                                    alt="Deck preview"
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
                        <label className="checkbox-label">
                            <input
                                type="checkbox"
                                checked={isPremium}
                                onChange={(e) => setIsPremium(e.target.checked)}
                            />
                            <span>Premium Deck</span>
                        </label>
                    </div>
                </div>

                <div className="form-section">
                    <h3 className="section-title">
                        <span className="section-icon">🎨</span>
                        Customization
                    </h3>

                    <div className="customization-row">
                        <div className="customization-item">
                            <label>Icon</label>
                            <button
                                type="button"
                                className="icon-selector"
                                onClick={() => setShowIconPicker(true)}
                                style={{ borderColor: colorToHex(selectedColor) }}
                            >
                                <div
                                    className="icon-preview"
                                    style={{
                                        backgroundColor: colorToHex(selectedColor) + '20',
                                        color: colorToHex(selectedColor)
                                    }}
                                >
                                    {selectedIcon && React.createElement(selectedIcon.icon, { size: 32 })}
                                </div>
                                <span>Change Icon</span>
                            </button>
                        </div>

                        <div className="customization-item">
                            <label>Color</label>
                            <button
                                type="button"
                                className="color-selector"
                                onClick={() => setShowColorPicker(!showColorPicker)}
                            >
                                <div
                                    className="color-preview"
                                    style={{ background: colorToHex(selectedColor) }}
                                >
                                    <Palette size={24} color="white" />
                                </div>
                                <span>Change Color</span>
                            </button>
                        </div>
                    </div>

                    {showColorPicker && (
                        <div className="color-picker-grid">
                            {defaultColors.map(color => (
                                <button
                                    key={color.name}
                                    type="button"
                                    className={`color-option ${selectedColor === color.value ? 'selected' : ''}`}
                                    style={{ backgroundColor: colorToHex(color.value) }}
                                    onClick={() => {
                                        setSelectedColor(color.value);
                                        setShowColorPicker(false);
                                    }}
                                    title={color.name}
                                />
                            ))}
                        </div>
                    )}
                </div>

                <div className="form-section">
                    <div className="section-header">
                        <h3 className="section-title">
                            <span className="section-icon">🃏</span>
                            Cards ({cards.length})
                        </h3>
                        <button
                            type="button"
                            className="ai-button"
                            onClick={generateAISuggestions}
                        >
                            <Sparkles size={16} />
                            AI Suggestions
                        </button>
                    </div>

                    <div className="add-card-row">
                        <input
                            type="text"
                            value={newCard}
                            onChange={(e) => setNewCard(e.target.value)}
                            placeholder="Enter card text..."
                            onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addCard())}
                        />
                        <button type="button" onClick={addCard} className="add-card-button">
                            <Plus size={20} />
                        </button>
                    </div>

                    {errors.cards && <span className="error-message">{errors.cards}</span>}

                    {cards.length > 0 && (
                        <div className="cards-list">
                            {cards.map((card, index) => (
                                <div key={index} className="card-item">
                                    <span className="card-number">{index + 1}</span>
                                    <span className="card-text">{card}</span>
                                    <button
                                        type="button"
                                        className="remove-card"
                                        onClick={() => removeCard(index)}
                                    >
                                        <X size={16} />
                                    </button>
                                </div>
                            ))}
                        </div>
                    )}

                    <div className="card-count-indicator">
                        {cards.length >= 5 ? (
                            <span className="success">✓ {cards.length} cards - Ready to play!</span>
                        ) : (
                            <span className="warning">⚠️ Need at least 5 cards ({5 - cards.length} more)</span>
                        )}
                    </div>

                    {showAISuggestions && aiSuggestions.length > 0 && (
                        <div className="ai-suggestions">
                            <div className="ai-suggestions-header">
                                <h4>
                                    <Sparkles size={16} />
                                    AI Suggestions
                                </h4>
                                <button type="button" onClick={addAllAISuggestions}>
                                    Add All
                                </button>
                            </div>
                            <div className="ai-suggestions-list">
                                {aiSuggestions.map((suggestion, index) => (
                                    <button
                                        key={index}
                                        type="button"
                                        className="ai-suggestion-chip"
                                        onClick={() => addAISuggestion(suggestion)}
                                    >
                                        {suggestion}
                                        <Plus size={14} />
                                    </button>
                                ))}
                            </div>
                        </div>
                    )}
                </div>
            </form>

            {showIconPicker && (
                <IconPicker
                    selectedIcon={selectedIcon}
                    onSelectIcon={setSelectedIcon}
                    onClose={() => setShowIconPicker(false)}
                />
            )}
        </div>
    );
};
