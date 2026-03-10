import { useState, useCallback } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { DeckList } from '../components/DeckList';
import { DeckForm } from '../components/DeckForm';
import { generateDeckImage } from '../services/aiImageService';
import { isImageGenerationAvailable } from '../services/aiImageService';
import { getAllDecks, updateDeck, type DeckData } from '../services/supabaseDeckService';
import { Wand2, Loader2, CheckCircle, XCircle, ImageIcon } from 'lucide-react';

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
  translations?: {
    [languageCode: string]: {
      name: string;
      description: string;
      cards?: string[];
    };
  };
}

interface GenerationStatus {
  deckName: string;
  status: 'pending' | 'generating' | 'success' | 'error';
  imageUrl?: string;
  error?: string;
}

const COLOR_PROMPT_MAP: Record<number, { hex: string; name: string; promptDescription: string }> = {
  0xFFE91E63: { hex: '#E91E63', name: 'Pink', promptDescription: 'vibrant pink and magenta tones with warm accents' },
  0xFFFFD93D: { hex: '#FFD93D', name: 'Gold', promptDescription: 'rich golden yellow and amber with warm highlights' },
  0xFFFF9800: { hex: '#FF9800', name: 'Orange', promptDescription: 'warm orange with red and amber accents' },
  0xFF4CAF50: { hex: '#4CAF50', name: 'Green', promptDescription: 'natural green with emerald and forest tones' },
  0xFF3F51B5: { hex: '#3F51B5', name: 'Indigo', promptDescription: 'deep indigo blue with navy and violet accents' },
  0xFF8BC34A: { hex: '#8BC34A', name: 'Light Green', promptDescription: 'fresh light green with lime and spring tones' },
  0xFF2196F3: { hex: '#2196F3', name: 'Blue', promptDescription: 'bright blue with sky and ocean tones' },
  0xFF9E9E9E: { hex: '#9E9E9E', name: 'Grey', promptDescription: 'sleek silver grey with metallic chrome accents' },
  0xFFFF5722: { hex: '#FF5722', name: 'Deep Orange', promptDescription: 'deep orange with red and copper accents' },
  0xFF795548: { hex: '#795548', name: 'Brown', promptDescription: 'warm brown with sepia and vintage earth tones' },
};

export function InitialDecksPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [editingDeck, setEditingDeck] = useState<Deck | undefined>(undefined);
  const [isGeneratingImages, setIsGeneratingImages] = useState(false);
  const [generationStatuses, setGenerationStatuses] = useState<GenerationStatus[]>([]);
  const [showImagePanel, setShowImagePanel] = useState(false);

  const isEditing = searchParams.get('mode') === 'edit';
  const isCreating = searchParams.get('mode') === 'create';
  const showForm = isEditing || isCreating;

  const handleEdit = (deck: Deck) => {
    setEditingDeck(deck);
    navigate('/initial-decks?mode=edit');
  };

  const handleCreate = () => {
    setEditingDeck(undefined);
    navigate('/initial-decks?mode=create');
  };

  const handleSave = () => {
    setEditingDeck(undefined);
    navigate('/initial-decks');
  };

  const handleCancel = () => {
    setEditingDeck(undefined);
    navigate('/initial-decks');
  };

  const generateAllImages = useCallback(async (skipExisting: boolean = true) => {
    if (!isImageGenerationAvailable()) {
      alert('AI Image generation is not available. Please configure your OpenAI API key in .env.local (VITE_OPENAI_API_KEY).');
      return;
    }

    setIsGeneratingImages(true);
    setShowImagePanel(true);

    try {
      const allDecks = await getAllDecks();
      const initialDecks = allDecks.filter(d => d.tags?.includes('initial'));

      if (initialDecks.length === 0) {
        alert('No initial decks found. Please run the seed script first.');
        setIsGeneratingImages(false);
        return;
      }

      const decksToProcess = skipExisting
        ? initialDecks.filter(d => !d.imageUrl)
        : initialDecks;

      if (decksToProcess.length === 0) {
        alert('All initial decks already have images! Use "Regenerate All" to replace them.');
        setIsGeneratingImages(false);
        return;
      }

      const statuses: GenerationStatus[] = decksToProcess.map(d => ({
        deckName: d.name,
        status: 'pending' as const,
      }));
      setGenerationStatuses(statuses);

      for (let i = 0; i < decksToProcess.length; i++) {
        const deck = decksToProcess[i];

        setGenerationStatuses(prev =>
          prev.map((s, idx) => idx === i ? { ...s, status: 'generating' } : s)
        );

        try {
          const colorInfo = COLOR_PROMPT_MAP[deck.colorValue] || {
            hex: '#' + (deck.colorValue & 0xFFFFFF).toString(16).padStart(6, '0'),
            name: 'Custom',
            promptDescription: 'vibrant and eye-catching color palette',
          };

          console.log(`Generating image for: ${deck.name} (color: ${colorInfo.name})`);

          const imageUrl = await generateDeckImage(deck.name, 'retro pulp', {
            quality: 'medium',
            size: '1024x1536',
            targetColor: colorInfo,
          });

          await updateDeck(deck.id!, { imageUrl } as Partial<DeckData>);

          setGenerationStatuses(prev =>
            prev.map((s, idx) => idx === i ? { ...s, status: 'success', imageUrl } : s)
          );

          console.log(`Image generated for ${deck.name}: ${imageUrl}`);
        } catch (error: any) {
          console.error(`Failed to generate image for ${deck.name}:`, error);
          setGenerationStatuses(prev =>
            prev.map((s, idx) => idx === i ? { ...s, status: 'error', error: error.message } : s)
          );
        }

        if (i < decksToProcess.length - 1) {
          await new Promise(resolve => setTimeout(resolve, 3000));
        }
      }
    } catch (error: any) {
      console.error('Image generation batch failed:', error);
      alert(`Image generation failed: ${error.message}`);
    } finally {
      setIsGeneratingImages(false);
    }
  }, []);

  const completedCount = generationStatuses.filter(s => s.status === 'success').length;
  const errorCount = generationStatuses.filter(s => s.status === 'error').length;
  const totalCount = generationStatuses.length;

  return (
    <>
      {showForm ? (
        <DeckForm
          deck={editingDeck}
          onSave={handleSave}
          onCancel={handleCancel}
        />
      ) : (
        <>
          {/* AI Image Generation Panel */}
          <div style={{
            margin: '0 0 24px 0',
            padding: '20px 24px',
            background: 'linear-gradient(135deg, #1a1a2e 0%, #16213e 100%)',
            borderRadius: '12px',
            border: '1px solid rgba(255,255,255,0.1)',
          }}>
            <div style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              flexWrap: 'wrap',
              gap: '12px',
            }}>
              <div>
                <h2 style={{ margin: 0, color: '#fff', fontSize: '18px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <ImageIcon size={20} />
                  AI Deck Cover Images
                </h2>
                <p style={{ margin: '4px 0 0', color: 'rgba(255,255,255,0.6)', fontSize: '13px' }}>
                  Generate AI cover images for initial decks using OpenAI gpt-image-1
                </p>
              </div>
              <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                <button
                  onClick={() => generateAllImages(true)}
                  disabled={isGeneratingImages}
                  style={{
                    display: 'flex', alignItems: 'center', gap: '6px',
                    padding: '10px 18px', borderRadius: '8px', border: 'none',
                    background: isGeneratingImages ? '#555' : 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                    color: '#fff', fontSize: '14px', fontWeight: 600,
                    cursor: isGeneratingImages ? 'not-allowed' : 'pointer',
                    transition: 'all 0.2s',
                  }}
                >
                  {isGeneratingImages ? <Loader2 size={16} className="spinning" /> : <Wand2 size={16} />}
                  {isGeneratingImages ? 'Generating...' : 'Generate Missing Images'}
                </button>
                <button
                  onClick={() => generateAllImages(false)}
                  disabled={isGeneratingImages}
                  style={{
                    display: 'flex', alignItems: 'center', gap: '6px',
                    padding: '10px 18px', borderRadius: '8px',
                    border: '1px solid rgba(255,255,255,0.2)',
                    background: 'transparent', color: 'rgba(255,255,255,0.8)',
                    fontSize: '14px', fontWeight: 500,
                    cursor: isGeneratingImages ? 'not-allowed' : 'pointer',
                  }}
                >
                  Regenerate All
                </button>
              </div>
            </div>

            {/* Generation Progress */}
            {showImagePanel && generationStatuses.length > 0 && (
              <div style={{ marginTop: '20px' }}>
                {totalCount > 0 && (
                  <div style={{
                    display: 'flex', alignItems: 'center', gap: '12px',
                    marginBottom: '12px', color: 'rgba(255,255,255,0.7)', fontSize: '13px',
                  }}>
                    <span>Progress: {completedCount + errorCount}/{totalCount}</span>
                    {completedCount > 0 && <span style={{ color: '#4ade80' }}>{completedCount} done</span>}
                    {errorCount > 0 && <span style={{ color: '#f87171' }}>{errorCount} failed</span>}
                    <div style={{
                      flex: 1, height: '4px', background: 'rgba(255,255,255,0.1)', borderRadius: '2px',
                    }}>
                      <div style={{
                        height: '100%', borderRadius: '2px',
                        width: `${((completedCount + errorCount) / totalCount) * 100}%`,
                        background: errorCount > 0 ? 'linear-gradient(90deg, #4ade80, #f87171)' : '#4ade80',
                        transition: 'width 0.5s ease',
                      }} />
                    </div>
                  </div>
                )}

                <div style={{
                  display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
                  gap: '10px',
                }}>
                  {generationStatuses.map((status, idx) => (
                    <div key={idx} style={{
                      display: 'flex', alignItems: 'center', gap: '10px',
                      padding: '10px 14px', borderRadius: '8px',
                      background: status.status === 'generating'
                        ? 'rgba(99, 102, 241, 0.15)'
                        : status.status === 'success'
                        ? 'rgba(74, 222, 128, 0.1)'
                        : status.status === 'error'
                        ? 'rgba(248, 113, 113, 0.1)'
                        : 'rgba(255,255,255,0.03)',
                      border: `1px solid ${
                        status.status === 'generating' ? 'rgba(99, 102, 241, 0.3)'
                        : status.status === 'success' ? 'rgba(74, 222, 128, 0.2)'
                        : status.status === 'error' ? 'rgba(248, 113, 113, 0.2)'
                        : 'rgba(255,255,255,0.05)'
                      }`,
                    }}>
                      {status.status === 'pending' && <div style={{ width: 16, height: 16, borderRadius: '50%', background: 'rgba(255,255,255,0.2)' }} />}
                      {status.status === 'generating' && <Loader2 size={16} style={{ color: '#818cf8', animation: 'spin 1s linear infinite' }} />}
                      {status.status === 'success' && <CheckCircle size={16} style={{ color: '#4ade80' }} />}
                      {status.status === 'error' && <XCircle size={16} style={{ color: '#f87171' }} />}
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ color: '#fff', fontSize: '13px', fontWeight: 500 }}>{status.deckName}</div>
                        {status.status === 'error' && (
                          <div style={{ color: '#f87171', fontSize: '11px', marginTop: '2px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {status.error}
                          </div>
                        )}
                      </div>
                      {status.status === 'success' && status.imageUrl && (
                        <img
                          src={status.imageUrl}
                          alt={status.deckName}
                          style={{ width: 36, height: 48, objectFit: 'cover', borderRadius: '4px', border: '1px solid rgba(255,255,255,0.1)' }}
                        />
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          <DeckList
            onEdit={handleEdit}
            onCreate={handleCreate}
            filterTag="initial"
            title="Initial Universal Decks"
            subtitle="Manage the default decks visible to all users on first launch"
          />

          <style>{`
            @keyframes spin {
              from { transform: rotate(0deg); }
              to { transform: rotate(360deg); }
            }
            .spinning {
              animation: spin 1s linear infinite;
            }
          `}</style>
        </>
      )}
    </>
  );
}
