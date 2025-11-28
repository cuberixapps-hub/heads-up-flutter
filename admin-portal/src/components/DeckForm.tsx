import React, { useState, useEffect } from 'react';
import { collection, addDoc, updateDoc, doc, serverTimestamp } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { db, storage } from '../config/firebase';
import { IconPicker } from './IconPicker';
import { type IconInfo } from '../data/icons';
import { Plus, X, Sparkles, Palette, Save, ArrowLeft, Upload, Wand2 } from 'lucide-react';
import * as FaIcons from 'react-icons/fa';
import { generateAdditionalCards, isContentGenerationAvailable } from '../services/aiContentService';
import { generateDeckImage, isImageGenerationAvailable } from '../services/aiImageService';
import { uploadCompressedImage, needsCompression, formatFileSize } from '../services/imageCompressionService';
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
    country?: string;
    tags?: string[];
    priority?: number;
    isActive?: boolean;
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

const countryOptions = [
    { value: 'UNIVERSAL', label: '🌍 Universal' },
    { value: 'IN', label: '🇮🇳 India' },
    { value: 'JP', label: '🇯🇵 Japan' },
    { value: 'KR', label: '🇰🇷 South Korea' },
    { value: 'BR', label: '🇧🇷 Brazil' },
    { value: 'CN', label: '🇨🇳 China' },
    { value: 'US', label: '🇺🇸 United States' },
    { value: 'GB', label: '🇬🇧 United Kingdom' },
    { value: 'MX', label: '🇲🇽 Mexico/Latin America' },
    { value: 'TRENDING', label: '🔥 Trending 2025' },
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
    const [country, setCountry] = useState(deck?.country || 'UNIVERSAL');
    const [tags, setTags] = useState<string[]>(deck?.tags || []);
    const [newTag, setNewTag] = useState('');
    const [priority, setPriority] = useState(deck?.priority || 0);
    const [isActive, setIsActive] = useState(deck?.isActive !== false);
    const [showIconPicker, setShowIconPicker] = useState(false);
    const [showColorPicker, setShowColorPicker] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
    const [errors, setErrors] = useState<{ [key: string]: string }>({});
    const [showAISuggestions, setShowAISuggestions] = useState(false);
    const [aiSuggestions, setAiSuggestions] = useState<string[]>([]);
    const [imageFile, setImageFile] = useState<File | null>(null);
    const [imagePreview, setImagePreview] = useState<string | null>(deck?.imageUrl || null);
    const [isUploading, setIsUploading] = useState(false);
    const [uploadError, setUploadError] = useState<string>('');
    const [showAIAssist, setShowAIAssist] = useState(false);
    const [isGeneratingAICards, setIsGeneratingAICards] = useState(false);
    const [isGeneratingAIImage, setIsGeneratingAIImage] = useState(false);
    const [hasAIContent, setHasAIContent] = useState(isContentGenerationAvailable());
    const [hasAIImage, setHasAIImage] = useState(isImageGenerationAvailable());
    const [compressionProgress, setCompressionProgress] = useState<number>(0);

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
            country,
            tags,
            priority,
            isActive,
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

    const generateAISuggestions = async () => {
        if (!name.trim()) {
            alert('Please enter a deck name first');
            return;
        }

        setIsGeneratingAICards(true);
        setShowAISuggestions(true);

        try {
            // Try to use Claude API if available
            if (hasAIContent) {
                const suggestions = await generateAdditionalCards(name, cards, 10);
                if (suggestions && suggestions.length > 0) {
                    setAiSuggestions(suggestions);
                    return;
                }
            }
        } catch (error) {
            console.error('Failed to generate AI suggestions:', error);
        } finally {
            setIsGeneratingAICards(false);
        }

        // Fallback to hardcoded suggestions
        const deckNameLower = name.toLowerCase();
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

    const handleImageUpload = async (file: File) => {
        // Validate file type
        const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
        if (!validTypes.includes(file.type)) {
            setUploadError('Please upload a JPG, PNG, or WebP image');
            return;
        }

        // Validate file size (10MB)
        if (file.size > 10 * 1024 * 1024) {
            setUploadError('Image must be less than 10MB');
            return;
        }

        setUploadError('');
        setIsUploading(true);
        setCompressionProgress(0);

        try {
            // Use temporary ID if creating new deck, or existing ID if editing
            const deckId = deck?.id || `temp_${Date.now()}`;
            
            // Show file info
            console.log(`Uploading ${file.name} (${formatFileSize(file.size)})`);
            
            // Upload with compression
            const downloadURL = await uploadCompressedImage(
                file,
                deckId,
                (progress) => setCompressionProgress(progress)
            );
            
            setImageUrl(downloadURL);
            setImagePreview(downloadURL);
            setImageFile(file);
            setIsUploading(false);
            setCompressionProgress(0);
        } catch (error) {
            console.error('Error uploading image:', error);
            setUploadError('Failed to upload image. Please try again.');
            setIsUploading(false);
            setCompressionProgress(0);
        }
    };

    const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (file) {
            handleImageUpload(file);
        }
    };

    const removeImage = () => {
        setImageFile(null);
        setImagePreview(null);
        setImageUrl('');
    };

    const generateAIImage = async () => {
        if (!name.trim()) {
            alert('Please enter a deck name first');
            return;
        }

        if (!hasAIImage) {
            alert('AI image generation is not available. Please configure your OpenAI API key.');
            return;
        }

        setIsGeneratingAIImage(true);
        setUploadError('');

        try {
            const generatedImageUrl = await generateDeckImage(name);
            setImageUrl(generatedImageUrl);
            setImagePreview(generatedImageUrl);
        } catch (error: any) {
            console.error('Failed to generate AI image:', error);
            setUploadError('Failed to generate image. Please try again.');
        } finally {
            setIsGeneratingAIImage(false);
        }
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
                <div style={{ display: 'flex', gap: '10px' }}>
                    {(hasAIContent || hasAIImage) && (
                        <button
                            type="button"
                            className="ai-assist-button"
                            onClick={() => setShowAIAssist(true)}
                            style={{
                                padding: '10px 20px',
                                background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                                color: 'white',
                                border: 'none',
                                borderRadius: '8px',
                                display: 'flex',
                                alignItems: 'center',
                                gap: '8px',
                                cursor: 'pointer'
                            }}
                        >
                            <Wand2 size={18} />
                            AI Assist
                        </button>
                    )}
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
            </div>

            {/* Enhanced Deck Summary Card - Shows all key data at a glance */}
            {deck && (
                <div className="deck-summary-banner">
                    <div className="summary-header">
                        <div className="summary-icon-preview">
                            {selectedIcon && React.createElement(selectedIcon.icon, { size: 48 })}
                        </div>
                        <div className="summary-title">
                            <h2>{deck.name}</h2>
                            <div className="summary-badges">
                                {deck.isPremium && <span className="badge badge-premium">👑 Premium</span>}
                                {deck.isActive !== false ? (
                                    <span className="badge badge-active">✅ Active</span>
                                ) : (
                                    <span className="badge badge-inactive">❌ Inactive</span>
                                )}
                                <span className="badge badge-country">
                                    {countryOptions.find(c => c.value === deck.country)?.label || '🌍 Universal'}
                                </span>
                            </div>
                        </div>
                    </div>

                    <div className="summary-stats-grid">
                        <div className="stat-box">
                            <div className="stat-icon">🃏</div>
                            <div className="stat-content">
                                <span className="stat-value">{deck.cards.length}</span>
                                <span className="stat-label">Total Cards</span>
                            </div>
                        </div>
                        <div className="stat-box">
                            <div className="stat-icon">📊</div>
                            <div className="stat-content">
                                <span className="stat-value">{deck.priority || 0}</span>
                                <span className="stat-label">Priority</span>
                            </div>
                        </div>
                        <div className="stat-box">
                            <div className="stat-icon">🏷️</div>
                            <div className="stat-content">
                                <span className="stat-value">{deck.tags?.length || 0}</span>
                                <span className="stat-label">Tags</span>
                            </div>
                        </div>
                        <div className="stat-box">
                            <div className="stat-icon">📅</div>
                            <div className="stat-content">
                                <span className="stat-value">
                                    {deck.createdAt ? new Date(deck.createdAt.seconds * 1000).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : 'N/A'}
                                </span>
                                <span className="stat-label">Created</span>
                            </div>
                        </div>
                    </div>

                    {deck.description && (
                        <div className="summary-description">
                            <p>{deck.description}</p>
                        </div>
                    )}

                    {deck.tags && deck.tags.length > 0 && (
                        <div className="summary-tags">
                            <span className="tags-label">Tags:</span>
                            {deck.tags.map((tag, idx) => (
                                <span key={idx} className="tag-chip">{tag}</span>
                            ))}
                        </div>
                    )}

                    <div className="summary-footer">
                        <div className="summary-detail">
                            <span className="detail-label">Deck ID:</span>
                            <code className="detail-value">{deck.id}</code>
                        </div>
                        {deck.updatedAt && (
                            <div className="summary-detail">
                                <span className="detail-label">Last Updated:</span>
                                <span className="detail-value">
                                    {new Date(deck.updatedAt.seconds * 1000).toLocaleString('en-US', {
                                        month: 'short',
                                        day: 'numeric',
                                        year: 'numeric',
                                        hour: '2-digit',
                                        minute: '2-digit'
                                    })}
                                </span>
                            </div>
                        )}
                        {deck.imageUrl && (
                            <div className="summary-detail">
                                <span className="detail-label">Has Image:</span>
                                <span className="detail-value">✅ Yes</span>
                            </div>
                        )}
                    </div>
                </div>
            )}

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
                        <label>Deck Image</label>
                        
                        {/* Upload Buttons */}
                        <div style={{ display: 'flex', gap: '12px', marginBottom: '12px' }}>
                            <input
                                type="file"
                                id="imageUpload"
                                accept="image/jpeg,image/jpg,image/png,image/webp"
                                onChange={handleFileSelect}
                                style={{ display: 'none' }}
                                disabled={isUploading}
                            />
                            <button
                                type="button"
                                onClick={() => document.getElementById('imageUpload')?.click()}
                                disabled={isUploading}
                                style={{
                                    padding: '10px 16px',
                                    backgroundColor: isUploading ? '#ccc' : '#4CAF50',
                                    color: 'white',
                                    border: 'none',
                                    borderRadius: '6px',
                                    cursor: isUploading ? 'not-allowed' : 'pointer',
                                    display: 'flex',
                                    alignItems: 'center',
                                    gap: '8px',
                                }}
                            >
                                <Upload size={18} />
                                {isUploading ? `Uploading... ${compressionProgress}%` : 'Upload Image'}
                            </button>
                            
                            {hasAIImage && (
                                <button
                                    type="button"
                                    onClick={generateAIImage}
                                    disabled={isGeneratingAIImage || !name.trim()}
                                    style={{
                                        padding: '10px 16px',
                                        background: isGeneratingAIImage || !name.trim() ? '#ccc' : 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                                        color: 'white',
                                        border: 'none',
                                        borderRadius: '6px',
                                        cursor: isGeneratingAIImage || !name.trim() ? 'not-allowed' : 'pointer',
                                        display: 'flex',
                                        alignItems: 'center',
                                        gap: '8px',
                                    }}
                                >
                                    <Wand2 size={18} />
                                    {isGeneratingAIImage ? 'Generating...' : 'AI Generate'}
                                </button>
                            )}
                        </div>

                        {/* Image Preview */}
                        {imagePreview && (
                            <div style={{ position: 'relative', display: 'inline-block', marginBottom: '12px' }}>
                                <img
                                    src={imagePreview}
                                    alt="Deck preview"
                                    style={{
                                        width: '200px',
                                        height: '120px',
                                        objectFit: 'cover',
                                        borderRadius: '8px',
                                        border: '2px solid #e0e0e0',
                                    }}
                                />
                                <button
                                    type="button"
                                    onClick={removeImage}
                                    style={{
                                        position: 'absolute',
                                        top: '-8px',
                                        right: '-8px',
                                        backgroundColor: '#f44336',
                                        color: 'white',
                                        border: 'none',
                                        borderRadius: '50%',
                                        width: '24px',
                                        height: '24px',
                                        cursor: 'pointer',
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                    }}
                                >
                                    <X size={16} />
                                </button>
                            </div>
                        )}

                        {/* Error Message */}
                        {uploadError && (
                            <div style={{ color: '#f44336', fontSize: '14px', marginBottom: '8px' }}>
                                {uploadError}
                            </div>
                        )}

                        {/* URL Input (editable after upload) */}
                        <div>
                            <label htmlFor="imageUrl" style={{ fontSize: '13px', color: '#666' }}>
                                Or paste image URL
                            </label>
                            <input
                                type="url"
                                id="imageUrl"
                                value={imageUrl}
                                onChange={(e) => {
                                    setImageUrl(e.target.value);
                                    setImagePreview(e.target.value);
                                }}
                                placeholder="https://example.com/image.jpg"
                                disabled={isUploading}
                            />
                            <small style={{ color: '#666', fontSize: '12px' }}>
                                Accepted: JPG, PNG, WebP (max 10MB) • Images will be automatically compressed
                            </small>
                        </div>
                    </div>

                    <div className="form-group">
                        <label htmlFor="country">Country/Region *</label>
                        <select
                            id="country"
                            value={country}
                            onChange={(e) => setCountry(e.target.value)}
                            className="form-select"
                            style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid #e0e0e0' }}
                        >
                            {countryOptions.map(option => (
                                <option key={option.value} value={option.value}>
                                    {option.label}
                                </option>
                            ))}
                        </select>
                    </div>

                    <div className="form-group">
                        <label htmlFor="priority">Priority (lower number = higher priority)</label>
                        <input
                            id="priority"
                            type="number"
                            value={priority}
                            onChange={(e) => setPriority(Number(e.target.value))}
                            placeholder="0"
                            min="0"
                            max="999"
                        />
                    </div>

                    <div className="form-group">
                        <label>Tags</label>
                        <div className="add-card-row">
                            <input
                                type="text"
                                value={newTag}
                                onChange={(e) => setNewTag(e.target.value)}
                                placeholder="Add a tag (e.g., trending, party, family)..."
                                onKeyPress={(e) => {
                                    if (e.key === 'Enter') {
                                        e.preventDefault();
                                        if (newTag.trim() && !tags.includes(newTag.trim())) {
                                            setTags([...tags, newTag.trim()]);
                                            setNewTag('');
                                        }
                                    }
                                }}
                            />
                            <button 
                                type="button" 
                                onClick={() => {
                                    if (newTag.trim() && !tags.includes(newTag.trim())) {
                                        setTags([...tags, newTag.trim()]);
                                        setNewTag('');
                                    }
                                }} 
                                className="add-card-button"
                            >
                                <Plus size={20} />
                            </button>
                        </div>
                        {tags.length > 0 && (
                            <div className="cards-list" style={{ marginTop: '10px' }}>
                                {tags.map((tag, index) => (
                                    <div key={index} className="card-item" style={{ padding: '6px 12px' }}>
                                        <span className="card-text">{tag}</span>
                                        <button
                                            type="button"
                                            className="remove-card"
                                            onClick={() => setTags(tags.filter((_, i) => i !== index))}
                                        >
                                            <X size={16} />
                                        </button>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>

                    <div style={{ display: 'flex', gap: '20px' }}>
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

                        <div className="form-group">
                            <label className="checkbox-label">
                                <input
                                    type="checkbox"
                                    checked={isActive}
                                    onChange={(e) => setIsActive(e.target.checked)}
                                />
                                <span>Active (visible to users)</span>
                            </label>
                        </div>
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
                            disabled={isGeneratingAICards}
                        >
                            <Sparkles size={16} />
                            {isGeneratingAICards ? 'Generating...' : 'AI Suggestions'}
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
