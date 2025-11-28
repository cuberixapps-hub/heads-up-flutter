import React, { useState, useEffect } from 'react';
import { collection, onSnapshot, deleteDoc, doc } from 'firebase/firestore';
import { db } from '../config/firebase';
import { Plus, Edit2, Trash2, Copy, Crown, Search } from 'lucide-react';
import '../styles/DeckList.css';

interface Deck {
    id: string;
    name: string;
    description: string;
    cards: string[];
    iconCodePoint: number;
    iconFontFamily: string;
    colorValue: number;
    imageUrl?: string;
    isPremium: boolean;
    country?: string;
    tags?: string[];
    priority?: number;
    isActive?: boolean;
    createdAt: any;
    updatedAt: any;
}

interface DeckListProps {
    onEdit: (deck: Deck) => void;
    onCreate: () => void;
}

export const DeckList: React.FC<DeckListProps> = ({ onEdit, onCreate }) => {
    const [decks, setDecks] = useState<Deck[]>([]);
    const [filteredDecks, setFilteredDecks] = useState<Deck[]>([]);
    const [searchQuery, setSearchQuery] = useState('');
    const [isLoading, setIsLoading] = useState(true);
    const [selectedDeck, setSelectedDeck] = useState<string | null>(null);
    const [modalImage, setModalImage] = useState<{ url: string; name: string } | null>(null);

    useEffect(() => {
        const unsubscribe = onSnapshot(
            collection(db, 'decks'),
            (snapshot) => {
                const deckData = snapshot.docs.map(doc => ({
                    id: doc.id,
                    ...doc.data()
                } as Deck));

                // Sort by priority first, then by creation date
                deckData.sort((a, b) => {
                    // Sort by priority (lower number = higher priority)
                    if ((a.priority || 0) !== (b.priority || 0)) {
                        return (a.priority || 0) - (b.priority || 0);
                    }
                    // Then by creation date (newest first)
                    const dateA = a.createdAt?.toDate?.() || new Date(0);
                    const dateB = b.createdAt?.toDate?.() || new Date(0);
                    return dateB.getTime() - dateA.getTime();
                });

                setDecks(deckData);
                setFilteredDecks(deckData);
                setIsLoading(false);
            },
            (error) => {
                console.error('Error fetching decks:', error);
                setIsLoading(false);
            }
        );

        return () => unsubscribe();
    }, []);

    useEffect(() => {
        if (searchQuery) {
            const filtered = decks.filter(deck =>
                deck.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                deck.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
                deck.cards.some(card => card.toLowerCase().includes(searchQuery.toLowerCase()))
            );
            setFilteredDecks(filtered);
        } else {
            setFilteredDecks(decks);
        }
    }, [searchQuery, decks]);

    // Handle ESC key to close modal
    useEffect(() => {
        const handleEscKey = (event: KeyboardEvent) => {
            if (event.key === 'Escape' && modalImage) {
                setModalImage(null);
            }
        };

        if (modalImage) {
            document.addEventListener('keydown', handleEscKey);
        }

        return () => {
            document.removeEventListener('keydown', handleEscKey);
        };
    }, [modalImage]);

    const handleDelete = async (deckId: string) => {
        if (window.confirm('Are you sure you want to delete this deck?')) {
            try {
                await deleteDoc(doc(db, 'decks', deckId));
            } catch (error) {
                console.error('Error deleting deck:', error);
                alert('Failed to delete deck. Please try again.');
            }
        }
    };

    const handleDuplicate = (deck: Deck) => {
        const duplicatedDeck = {
            ...deck,
            name: `${deck.name} (Copy)`,
            id: undefined
        };
        onEdit(duplicatedDeck);
    };

    const colorToHex = (colorValue: number): string => {
        return '#' + (colorValue & 0xFFFFFF).toString(16).padStart(6, '0');
    };

    const getCountryLabel = (country: string): string => {
        const labels: { [key: string]: string } = {
            'UNIVERSAL': '🌍 Universal',
            'IN': '🇮🇳 India',
            'JP': '🇯🇵 Japan',
            'KR': '🇰🇷 Korea',
            'BR': '🇧🇷 Brazil',
            'CN': '🇨🇳 China',
            'US': '🇺🇸 USA',
            'GB': '🇬🇧 UK',
            'MX': '🇲🇽 LATAM',
            'TRENDING': '🔥 Trending'
        };
        return labels[country] || country;
    };

    const getCountryColor = (country: string): string => {
        const colors: { [key: string]: string } = {
            'UNIVERSAL': '#4CAF50',
            'IN': '#FF9933',
            'JP': '#DC143C',
            'KR': '#0066CC',
            'BR': '#009B3A',
            'CN': '#DE2910',
            'US': '#3C3B6E',
            'GB': '#012169',
            'MX': '#006341',
            'TRENDING': '#FF6B6B'
        };
        return colors[country] || '#757575';
    };

    const renderIcon = (deck: Deck) => {
        // If deck has an image, display it
        if (deck.imageUrl) {
            return (
                <div
                    className="deck-icon deck-image"
                    style={{
                        backgroundImage: `url(${deck.imageUrl})`,
                        backgroundSize: 'cover',
                        backgroundPosition: 'center',
                        cursor: 'pointer'
                    }}
                    onClick={(e) => {
                        e.stopPropagation();
                        setModalImage({ url: deck.imageUrl!, name: deck.name });
                    }}
                    title="Click to view full image"
                />
            );
        }
        
        // Otherwise show placeholder with first letter
        return (
            <div
                className="deck-icon"
                style={{
                    backgroundColor: colorToHex(deck.colorValue) + '20',
                    color: colorToHex(deck.colorValue)
                }}
            >
                {deck.name.charAt(0).toUpperCase()}
            </div>
        );
    };

    if (isLoading) {
        return (
            <div className="loading-container">
                <div className="loading-spinner"></div>
                <p>Loading decks...</p>
            </div>
        );
    }

    return (
        <div className="deck-list-container">
            {/* Image Modal */}
            {modalImage && (
                <div className="image-modal-overlay" onClick={() => setModalImage(null)}>
                    <div className="image-modal-content" onClick={(e) => e.stopPropagation()}>
                        <button 
                            className="image-modal-close" 
                            onClick={() => setModalImage(null)}
                            aria-label="Close"
                        >
                            ×
                        </button>
                        <h3 className="image-modal-title">{modalImage.name}</h3>
                        <img 
                            src={modalImage.url} 
                            alt={modalImage.name}
                            className="image-modal-img"
                        />
                    </div>
                </div>
            )}

            <div className="deck-list-header">
                <div className="header-left">
                    <h1>Deck Management</h1>
                    <p>{decks.length} total decks</p>
                </div>
                <div className="header-actions">
                    <div className="search-box">
                        <Search size={20} className="search-icon" />
                        <input
                            type="text"
                            placeholder="Search decks..."
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="search-input"
                        />
                    </div>
                    <button className="create-button" onClick={onCreate}>
                        <Plus size={20} />
                        Create Deck
                    </button>
                </div>
            </div>

            {filteredDecks.length === 0 ? (
                <div className="empty-state">
                    {searchQuery ? (
                        <>
                            <h3>No decks found</h3>
                            <p>Try adjusting your search terms</p>
                        </>
                    ) : (
                        <>
                            <h3>No decks yet</h3>
                            <p>Create your first deck to get started</p>
                            <button className="create-button-large" onClick={onCreate}>
                                <Plus size={24} />
                                Create Your First Deck
                            </button>
                        </>
                    )}
                </div>
            ) : (
                <div className="deck-grid">
                    {filteredDecks.map(deck => (
                        <div
                            key={deck.id}
                            className={`deck-card ${selectedDeck === deck.id ? 'selected' : ''}`}
                            onClick={() => setSelectedDeck(deck.id === selectedDeck ? null : deck.id)}
                        >
                            <div className="deck-card-header">
                                {renderIcon(deck)}
                                <div className="deck-info">
                                    <h3>
                                        {deck.name}
                                        {deck.isPremium && (
                                            <Crown size={16} className="premium-icon" title="Premium" />
                                        )}
                                        {deck.isActive === false && (
                                            <span className="inactive-badge" style={{
                                                marginLeft: '8px',
                                                padding: '2px 8px',
                                                backgroundColor: '#f44336',
                                                color: 'white',
                                                fontSize: '11px',
                                                borderRadius: '4px',
                                                fontWeight: 'normal'
                                            }}>Inactive</span>
                                        )}
                                    </h3>
                                    <p className="deck-description">{deck.description || 'No description'}</p>
                                    <div style={{ marginTop: '6px', display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                                        {deck.country && (
                                            <span style={{
                                                padding: '2px 10px',
                                                backgroundColor: getCountryColor(deck.country),
                                                color: 'white',
                                                fontSize: '12px',
                                                borderRadius: '12px',
                                                fontWeight: '500'
                                            }}>
                                                {getCountryLabel(deck.country)}
                                            </span>
                                        )}
                                        {deck.priority !== undefined && deck.priority !== 0 && (
                                            <span style={{
                                                padding: '2px 10px',
                                                backgroundColor: '#9e9e9e',
                                                color: 'white',
                                                fontSize: '12px',
                                                borderRadius: '12px',
                                                fontWeight: '500'
                                            }}>
                                                Priority: {deck.priority}
                                            </span>
                                        )}
                                    </div>
                                </div>
                            </div>

                            <div className="deck-stats">
                                <div className="stat">
                                    <span className="stat-value">{deck.cards.length}</span>
                                    <span className="stat-label">Cards</span>
                                </div>
                                <div className="stat">
                                    <span className="stat-value">
                                        {deck.createdAt?.toDate?.().toLocaleDateString() || 'N/A'}
                                    </span>
                                    <span className="stat-label">Created</span>
                                </div>
                            </div>

                            {selectedDeck === deck.id && (
                                <div className="deck-preview">
                                    <h4>Sample Cards:</h4>
                                    <div className="preview-cards">
                                        {deck.cards.slice(0, 5).map((card, index) => (
                                            <span key={index} className="preview-card">
                                                {card}
                                            </span>
                                        ))}
                                        {deck.cards.length > 5 && (
                                            <span className="preview-more">
                                                +{deck.cards.length - 5} more
                                            </span>
                                        )}
                                    </div>
                                </div>
                            )}

                            <div className="deck-actions">
                                <button
                                    className="action-button edit"
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        onEdit(deck);
                                    }}
                                    title="Edit"
                                >
                                    <Edit2 size={16} />
                                </button>
                                <button
                                    className="action-button duplicate"
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        handleDuplicate(deck);
                                    }}
                                    title="Duplicate"
                                >
                                    <Copy size={16} />
                                </button>
                                <button
                                    className="action-button delete"
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        handleDelete(deck.id);
                                    }}
                                    title="Delete"
                                >
                                    <Trash2 size={16} />
                                </button>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
};





