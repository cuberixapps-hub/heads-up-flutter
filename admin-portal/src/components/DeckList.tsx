import React, { useState, useEffect } from 'react';
import { collection, onSnapshot, deleteDoc, doc } from 'firebase/firestore';
import { db } from '../config/firebase';
import { Plus, Edit2, Trash2, Copy, Crown, Search, Filter, Grid, List, Calendar, Tag, Globe, Layers, Eye, EyeOff, ChevronDown, ChevronUp } from 'lucide-react';
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
    countries?: string[];
    tags?: string[];
    priority?: number;
    isActive?: boolean;
    difficulty?: string;
    createdAt: any;
    updatedAt: any;
}

interface DeckListProps {
    onEdit: (deck: Deck) => void;
    onCreate: () => void;
}

type ViewMode = 'grid' | 'list';
type FilterType = 'all' | 'premium' | 'free' | 'active' | 'inactive';

export const DeckList: React.FC<DeckListProps> = ({ onEdit, onCreate }) => {
    const [decks, setDecks] = useState<Deck[]>([]);
    const [filteredDecks, setFilteredDecks] = useState<Deck[]>([]);
    const [searchQuery, setSearchQuery] = useState('');
    const [isLoading, setIsLoading] = useState(true);
    const [selectedDeck, setSelectedDeck] = useState<string | null>(null);
    const [modalImage, setModalImage] = useState<{ url: string; name: string } | null>(null);
    const [viewMode, setViewMode] = useState<ViewMode>('grid');
    const [filterType, setFilterType] = useState<FilterType>('all');
    const [expandedCards, setExpandedCards] = useState<Set<string>>(new Set());

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
                    if ((a.priority || 0) !== (b.priority || 0)) {
                        return (a.priority || 0) - (b.priority || 0);
                    }
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
        let filtered = decks;

        // Apply search filter
        if (searchQuery) {
            filtered = filtered.filter(deck =>
                deck.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                deck.description?.toLowerCase().includes(searchQuery.toLowerCase()) ||
                deck.cards.some(card => card.toLowerCase().includes(searchQuery.toLowerCase())) ||
                deck.tags?.some(tag => tag.toLowerCase().includes(searchQuery.toLowerCase()))
            );
        }

        // Apply type filter
        switch (filterType) {
            case 'premium':
                filtered = filtered.filter(deck => deck.isPremium);
                break;
            case 'free':
                filtered = filtered.filter(deck => !deck.isPremium);
                break;
            case 'active':
                filtered = filtered.filter(deck => deck.isActive !== false);
                break;
            case 'inactive':
                filtered = filtered.filter(deck => deck.isActive === false);
                break;
        }

        setFilteredDecks(filtered);
    }, [searchQuery, decks, filterType]);

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

    const toggleExpandCards = (deckId: string) => {
        setExpandedCards(prev => {
            const newSet = new Set(prev);
            if (newSet.has(deckId)) {
                newSet.delete(deckId);
            } else {
                newSet.add(deckId);
            }
            return newSet;
        });
    };

    const colorToHex = (colorValue: number): string => {
        return '#' + (colorValue & 0xFFFFFF).toString(16).padStart(6, '0');
    };

    const getCountryFlag = (code: string): string => {
        const flags: { [key: string]: string } = {
            'UNIVERSAL': '🌍',
            'IN': '🇮🇳',
            'JP': '🇯🇵',
            'KR': '🇰🇷',
            'BR': '🇧🇷',
            'CN': '🇨🇳',
            'US': '🇺🇸',
            'GB': '🇬🇧',
            'MX': '🇲🇽',
            'CA': '🇨🇦',
            'AU': '🇦🇺',
            'TRENDING': '🔥'
        };
        return flags[code] || '🌐';
    };

    const getCountryName = (code: string): string => {
        const names: { [key: string]: string } = {
            'UNIVERSAL': 'Universal',
            'IN': 'India',
            'JP': 'Japan',
            'KR': 'Korea',
            'BR': 'Brazil',
            'CN': 'China',
            'US': 'USA',
            'GB': 'UK',
            'MX': 'LATAM',
            'CA': 'Canada',
            'AU': 'Australia',
            'TRENDING': 'Trending'
        };
        return names[code] || code;
    };

    const formatDate = (timestamp: any): string => {
        if (!timestamp?.toDate) return 'N/A';
        const date = timestamp.toDate();
        return new Intl.DateTimeFormat('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        }).format(date);
    };

    const formatTime = (timestamp: any): string => {
        if (!timestamp?.toDate) return '';
        const date = timestamp.toDate();
        return new Intl.DateTimeFormat('en-US', {
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
        }).format(date);
    };

    const getDifficultyColor = (difficulty?: string): string => {
        switch (difficulty?.toLowerCase()) {
            case 'easy': return '#10b981';
            case 'medium': return '#f59e0b';
            case 'hard': return '#ef4444';
            default: return '#6b7280';
        }
    };

    const getStats = () => {
        const total = decks.length;
        const premium = decks.filter(d => d.isPremium).length;
        const active = decks.filter(d => d.isActive !== false).length;
        const totalCards = decks.reduce((sum, d) => sum + d.cards.length, 0);
        return { total, premium, active, totalCards };
    };

    const stats = getStats();

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
                        <button className="image-modal-close" onClick={() => setModalImage(null)}>×</button>
                        <h3 className="image-modal-title">{modalImage.name}</h3>
                        <img src={modalImage.url} alt={modalImage.name} className="image-modal-img" />
                    </div>
                </div>
            )}

            {/* Stats Bar */}
            <div className="stats-bar">
                <div className="stat-item">
                    <Layers size={20} />
                    <div className="stat-content">
                        <span className="stat-number">{stats.total}</span>
                        <span className="stat-text">Total Decks</span>
                    </div>
                </div>
                <div className="stat-item premium">
                    <Crown size={20} />
                    <div className="stat-content">
                        <span className="stat-number">{stats.premium}</span>
                        <span className="stat-text">Premium</span>
                    </div>
                </div>
                <div className="stat-item active">
                    <Eye size={20} />
                    <div className="stat-content">
                        <span className="stat-number">{stats.active}</span>
                        <span className="stat-text">Active</span>
                    </div>
                </div>
                <div className="stat-item cards">
                    <Tag size={20} />
                    <div className="stat-content">
                        <span className="stat-number">{stats.totalCards.toLocaleString()}</span>
                        <span className="stat-text">Total Cards</span>
                    </div>
                </div>
            </div>

            {/* Header */}
            <div className="deck-list-header">
                <div className="header-left">
                    <h1>Deck Management</h1>
                    <p>Manage your game decks and content</p>
                </div>
                <div className="header-actions">
                    <div className="search-box">
                        <Search size={20} className="search-icon" />
                        <input
                            type="text"
                            placeholder="Search decks, cards, tags..."
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="search-input"
                        />
                    </div>
                    <div className="filter-group">
                        <Filter size={18} />
                        <select 
                            value={filterType} 
                            onChange={(e) => setFilterType(e.target.value as FilterType)}
                            className="filter-select"
                        >
                            <option value="all">All Decks</option>
                            <option value="premium">Premium Only</option>
                            <option value="free">Free Only</option>
                            <option value="active">Active</option>
                            <option value="inactive">Inactive</option>
                        </select>
                    </div>
                    <div className="view-toggle">
                        <button 
                            className={`view-btn ${viewMode === 'grid' ? 'active' : ''}`}
                            onClick={() => setViewMode('grid')}
                        >
                            <Grid size={18} />
                        </button>
                        <button 
                            className={`view-btn ${viewMode === 'list' ? 'active' : ''}`}
                            onClick={() => setViewMode('list')}
                        >
                            <List size={18} />
                        </button>
                    </div>
                    <button className="create-button" onClick={onCreate}>
                        <Plus size={20} />
                        Create Deck
                    </button>
                </div>
            </div>

            {/* Results count */}
            {searchQuery && (
                <div className="search-results-info">
                    Found <strong>{filteredDecks.length}</strong> deck{filteredDecks.length !== 1 ? 's' : ''} matching "{searchQuery}"
                </div>
            )}

            {filteredDecks.length === 0 ? (
                <div className="empty-state">
                    {searchQuery || filterType !== 'all' ? (
                        <>
                            <h3>No decks found</h3>
                            <p>Try adjusting your search or filter</p>
                            <button className="reset-filters-btn" onClick={() => { setSearchQuery(''); setFilterType('all'); }}>
                                Reset Filters
                            </button>
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
                <div className={`deck-${viewMode}`}>
                    {filteredDecks.map(deck => (
                        <div
                            key={deck.id}
                            className={`deck-card ${viewMode} ${selectedDeck === deck.id ? 'selected' : ''} ${deck.isActive === false ? 'inactive' : ''}`}
                            onClick={() => setSelectedDeck(deck.id === selectedDeck ? null : deck.id)}
                        >
                            {/* Image Section */}
                            <div className="deck-image-section">
                                {deck.imageUrl ? (
                                    <div
                                        className="deck-cover-image"
                                        style={{ backgroundImage: `url(${deck.imageUrl})` }}
                                        onClick={(e) => {
                                            e.stopPropagation();
                                            setModalImage({ url: deck.imageUrl!, name: deck.name });
                                        }}
                                    >
                                        <div className="image-overlay">
                                            <Eye size={24} />
                                            <span>View</span>
                                        </div>
                                    </div>
                                ) : (
                                    <div 
                                        className="deck-placeholder"
                                        style={{ 
                                            background: `linear-gradient(135deg, ${colorToHex(deck.colorValue)}, ${colorToHex(deck.colorValue)}dd)` 
                                        }}
                                    >
                                        <span className="placeholder-letter">{deck.name.charAt(0).toUpperCase()}</span>
                                    </div>
                                )}
                                
                                {/* Badges on image */}
                                <div className="deck-badges">
                                    {deck.isPremium && (
                                        <span className="badge premium-badge">
                                            <Crown size={12} /> Premium
                                        </span>
                                    )}
                                    {deck.isActive === false && (
                                        <span className="badge inactive-badge">
                                            <EyeOff size={12} /> Inactive
                                        </span>
                                    )}
                                    {deck.difficulty && (
                                        <span 
                                            className="badge difficulty-badge"
                                            style={{ backgroundColor: getDifficultyColor(deck.difficulty) }}
                                        >
                                            {deck.difficulty}
                                        </span>
                                    )}
                                </div>
                            </div>

                            {/* Content Section */}
                            <div className="deck-content-section">
                                <div className="deck-header-row">
                                    <h3 className="deck-title">{deck.name}</h3>
                                    <div 
                                        className="deck-color-dot"
                                        style={{ backgroundColor: colorToHex(deck.colorValue) }}
                                        title={`Theme: ${colorToHex(deck.colorValue)}`}
                                    />
                                </div>

                                <p className="deck-description">
                                    {deck.description || 'No description available'}
                                </p>

                                {/* Countries */}
                                <div className="deck-countries">
                                    <Globe size={14} />
                                    <div className="country-list">
                                        {deck.countries?.length ? (
                                            deck.countries.slice(0, 5).map((code, idx) => (
                                                <span key={idx} className="country-chip" title={getCountryName(code)}>
                                                    {getCountryFlag(code)}
                                                </span>
                                            ))
                                        ) : deck.country ? (
                                            <span className="country-chip" title={getCountryName(deck.country)}>
                                                {getCountryFlag(deck.country)} {getCountryName(deck.country)}
                                            </span>
                                        ) : (
                                            <span className="country-chip">🌍 Universal</span>
                                        )}
                                        {deck.countries && deck.countries.length > 5 && (
                                            <span className="country-more">+{deck.countries.length - 5}</span>
                                        )}
                                    </div>
                                </div>

                                {/* Tags */}
                                {deck.tags && deck.tags.length > 0 && (
                                    <div className="deck-tags">
                                        <Tag size={14} />
                                        <div className="tag-list">
                                            {deck.tags.slice(0, 3).map((tag, idx) => (
                                                <span key={idx} className="tag-chip">{tag}</span>
                                            ))}
                                            {deck.tags.length > 3 && (
                                                <span className="tag-more">+{deck.tags.length - 3}</span>
                                            )}
                                        </div>
                                    </div>
                                )}

                                {/* Stats Row */}
                                <div className="deck-stats-row">
                                    <div className="stat-mini">
                                        <span className="stat-value">{deck.cards.length}</span>
                                        <span className="stat-label">Cards</span>
                                    </div>
                                    {deck.priority !== undefined && deck.priority !== 0 && (
                                        <div className="stat-mini">
                                            <span className="stat-value">#{deck.priority}</span>
                                            <span className="stat-label">Priority</span>
                                        </div>
                                    )}
                                    <div className="stat-mini date">
                                        <Calendar size={12} />
                                        <span className="stat-value">{formatDate(deck.createdAt)}</span>
                                    </div>
                                </div>

                                {/* Expandable Cards Preview */}
                                <div className="cards-preview-section">
                                    <button 
                                        className="expand-cards-btn"
                                        onClick={(e) => {
                                            e.stopPropagation();
                                            toggleExpandCards(deck.id);
                                        }}
                                    >
                                        {expandedCards.has(deck.id) ? (
                                            <>Hide Cards <ChevronUp size={16} /></>
                                        ) : (
                                            <>Show Cards <ChevronDown size={16} /></>
                                        )}
                                    </button>
                                    
                                    {expandedCards.has(deck.id) && (
                                        <div className="cards-grid">
                                            {deck.cards.slice(0, 12).map((card, idx) => (
                                                <span key={idx} className="card-chip">{card}</span>
                                            ))}
                                            {deck.cards.length > 12 && (
                                                <span className="card-more">+{deck.cards.length - 12} more</span>
                                            )}
                                        </div>
                                    )}
                                </div>

                                {/* Actions */}
                                <div className="deck-actions">
                                    <button
                                        className="action-btn edit"
                                        onClick={(e) => { e.stopPropagation(); onEdit(deck); }}
                                        title="Edit Deck"
                                    >
                                        <Edit2 size={16} />
                                        <span>Edit</span>
                                    </button>
                                    <button
                                        className="action-btn duplicate"
                                        onClick={(e) => { e.stopPropagation(); handleDuplicate(deck); }}
                                        title="Duplicate Deck"
                                    >
                                        <Copy size={16} />
                                        <span>Copy</span>
                                    </button>
                                    <button
                                        className="action-btn delete"
                                        onClick={(e) => { e.stopPropagation(); handleDelete(deck.id); }}
                                        title="Delete Deck"
                                    >
                                        <Trash2 size={16} />
                                        <span>Delete</span>
                                    </button>
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
};
