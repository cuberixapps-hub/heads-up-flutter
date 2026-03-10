import React, { useState, useEffect } from 'react';
import { createDeck } from '../services/supabaseDeckService';
import { generateDeckContent } from '../services/aiContentService';
import { generateDeckImage } from '../services/aiImageService';
import { validateAPIKeys } from '../services/aiConfig';
import { AIGenerationProgress } from '../types/ai';
import type { DeckContent, AIError } from '../types/ai';
import { DeckForm } from './DeckForm';
import { Sparkles, AlertCircle, RefreshCw, Edit, Save, Loader, Wand2 } from 'lucide-react';
import * as FaIcons from 'react-icons/fa';
import '../styles/AIDeckGenerator.css';

interface GeneratedDeck extends DeckContent {
  imageUrl?: string;
}

export const AIDeckGenerator: React.FC = () => {
  const [topic, setTopic] = useState('');
  const [progress, setProgress] = useState<AIGenerationProgress>(AIGenerationProgress.IDLE);
  const [generatedDeck, setGeneratedDeck] = useState<GeneratedDeck | null>(null);
  const [error, setError] = useState<AIError | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [apiWarning, setApiWarning] = useState<string | null>(null);

  useEffect(() => {
    // Check API keys on component mount
    const validation = validateAPIKeys();
    if (!validation.valid) {
      setApiWarning(
        `Missing API keys for: ${validation.missing.join(', ')}. ` +
        'Please configure your API keys in .env.local file.'
      );
    }
  }, []);

  const handleGenerate = async () => {
    if (!topic.trim()) {
      setError({
        code: 'invalid_response',
        message: 'Please enter a topic for your deck'
      });
      return;
    }

    setError(null);
    setGeneratedDeck(null);
    setProgress(AIGenerationProgress.GENERATING_CONTENT);

    try {
      // Step 1: Generate deck content
      console.log('Starting content generation for topic:', topic);
      const deckContent = await generateDeckContent(topic);
      
      setProgress(AIGenerationProgress.GENERATING_IMAGE);
      
      // Step 2: Generate deck image
      console.log('Starting image generation');
      let imageUrl: string | undefined;
      
      try {
        imageUrl = await generateDeckImage(topic);
      } catch (imageError) {
        console.warn('Image generation failed, continuing without image:', imageError);
        // Continue without image if generation fails
      }
      
      setProgress(AIGenerationProgress.FINALIZING);
      
      // Step 3: Combine results
      const completeDeck: GeneratedDeck = {
        ...deckContent,
        imageUrl
      };
      
      setGeneratedDeck(completeDeck);
      setProgress(AIGenerationProgress.COMPLETE);
      
    } catch (error: any) {
      console.error('Generation error:', error);
      setError(error);
      setProgress(AIGenerationProgress.ERROR);
    }
  };

  const handleSaveDeck = async () => {
    if (!generatedDeck) return;

    try {
      const deckData = {
        name: generatedDeck.name,
        description: generatedDeck.description,
        cards: generatedDeck.cards,
        iconCodePoint: generatedDeck.iconSuggestion?.codePoint || 0xf005,
        iconFontFamily: generatedDeck.iconSuggestion?.fontFamily || 'FontAwesomeIcons',
        colorValue: generatedDeck.colorSuggestion || 0xFF9C27B0,
        imageUrl: generatedDeck.imageUrl || null,
        isPremium: false,
        isActive: true,
        country: generatedDeck.country,
        countries: [generatedDeck.country || 'UNIVERSAL'],
        tags: generatedDeck.suggestedTags || [],
        priority: 0,
        generatedByAI: true,
        generationTopic: topic
      };

      await createDeck(deckData);
      
      // Reset form
      setTopic('');
      setGeneratedDeck(null);
      setProgress(AIGenerationProgress.IDLE);
      
      // Show success message
      alert('Deck saved successfully!');
      
    } catch (error) {
      console.error('Error saving deck:', error);
      alert('Failed to save deck. Please try again.');
    }
  };

  const handleEdit = () => {
    setIsEditing(true);
  };

  const handleEditComplete = () => {
    setIsEditing(false);
    // Reset the generator
    setTopic('');
    setGeneratedDeck(null);
    setProgress(AIGenerationProgress.IDLE);
  };

  const handleRetry = () => {
    setError(null);
    handleGenerate();
  };

  const colorToHex = (colorValue: number): string => {
    return '#' + (colorValue & 0xFFFFFF).toString(16).padStart(6, '0');
  };

  // If editing, show the DeckForm component
  if (isEditing && generatedDeck) {
    const editableDeck = {
      name: generatedDeck.name,
      description: generatedDeck.description,
      cards: generatedDeck.cards,
      iconCodePoint: generatedDeck.iconSuggestion?.codePoint || 0xf005,
      iconFontFamily: generatedDeck.iconSuggestion?.fontFamily || 'FontAwesomeIcons',
      colorValue: generatedDeck.colorSuggestion || 0xFF9C27B0,
      imageUrl: generatedDeck.imageUrl,
      isPremium: false,
      country: generatedDeck.country,
      tags: generatedDeck.suggestedTags,
      priority: 0,
      isActive: true
    };

    return (
      <DeckForm
        deck={editableDeck}
        onSave={handleEditComplete}
        onCancel={handleEditComplete}
      />
    );
  }

  return (
    <div className="ai-generator-container">
      {apiWarning && (
        <div className="api-warning">
          <AlertCircle size={20} />
          <span>{apiWarning}</span>
        </div>
      )}

      <div className="ai-generator-header">
        <div className="header-icon">
          <Wand2 size={32} />
        </div>
        <h1>AI Deck Generator</h1>
        <p>Enter a topic and let AI create a complete deck for you!</p>
      </div>

      {progress === AIGenerationProgress.IDLE && !generatedDeck && (
        <div className="topic-input-section">
          <div className="input-group">
            <input
              type="text"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
              placeholder="Enter a topic (e.g., 'Classic Movies', 'Italian Food', 'Zoo Animals')"
              className="topic-input"
              onKeyPress={(e) => e.key === 'Enter' && handleGenerate()}
            />
            <button 
              onClick={handleGenerate} 
              className="generate-button"
              disabled={!topic.trim() || !!apiWarning}
            >
              <Sparkles size={20} />
              Generate Deck
            </button>
          </div>
          
          <div className="topic-suggestions">
            <span className="suggestion-label">Try these topics:</span>
            {['80s Movies', 'Superheroes', 'Desserts', 'Famous Landmarks', 'Pop Music'].map((suggestion) => (
              <button
                key={suggestion}
                className="suggestion-chip"
                onClick={() => setTopic(suggestion)}
              >
                {suggestion}
              </button>
            ))}
          </div>
        </div>
      )}

      {progress !== AIGenerationProgress.IDLE && progress !== AIGenerationProgress.COMPLETE && (
        <div className="generation-progress">
          <div className="progress-card">
            <Loader className="spinner" size={48} />
            <h3>
              {progress === AIGenerationProgress.GENERATING_CONTENT && 'Generating deck content...'}
              {progress === AIGenerationProgress.GENERATING_IMAGE && 'Creating deck image...'}
              {progress === AIGenerationProgress.FINALIZING && 'Finalizing your deck...'}
            </h3>
            <div className="progress-steps">
              <div className={`step ${(progress === AIGenerationProgress.GENERATING_CONTENT || progress === AIGenerationProgress.GENERATING_IMAGE || progress === AIGenerationProgress.FINALIZING) ? 'active' : ''}`}>
                <span className="step-number">1</span>
                <span className="step-label">Generate Content</span>
              </div>
              <div className={`step ${
                progress === AIGenerationProgress.GENERATING_IMAGE || 
                progress === AIGenerationProgress.FINALIZING ? 'active' : ''
              }`}>
                <span className="step-number">2</span>
                <span className="step-label">Create Image</span>
              </div>
              <div className={`step ${progress === AIGenerationProgress.FINALIZING ? 'active' : ''}`}>
                <span className="step-number">3</span>
                <span className="step-label">Finalize</span>
              </div>
            </div>
          </div>
        </div>
      )}

      {error && (
        <div className="error-section">
          <div className="error-card">
            <AlertCircle size={24} />
            <h3>Generation Failed</h3>
            <p>{error.message}</p>
            <button onClick={handleRetry} className="retry-button">
              <RefreshCw size={16} />
              Try Again
            </button>
          </div>
        </div>
      )}

      {generatedDeck && progress === AIGenerationProgress.COMPLETE && (
        <div className="preview-section">
          <h2>Generated Deck Preview</h2>
          
          <div className="deck-preview-card">
            <div className="preview-header">
              <div className="preview-icon" style={{ 
                backgroundColor: colorToHex(generatedDeck.colorSuggestion || 0xFF9C27B0),
                color: 'white' 
              }}>
                {generatedDeck.iconSuggestion && 
                  React.createElement(
                    (FaIcons as any)[`Fa${generatedDeck.iconSuggestion.codePoint.toString(16).toUpperCase()}`] || FaIcons.FaStar,
                    { size: 32 }
                  )
                }
              </div>
              <div className="preview-info">
                <h3>{generatedDeck.name}</h3>
                <p>{generatedDeck.description}</p>
                <div className="preview-meta">
                  <span className="meta-item">📍 {generatedDeck.country}</span>
                  <span className="meta-item">🏷️ {generatedDeck.suggestedTags.join(', ')}</span>
                  <span className="meta-item">🎯 {generatedDeck.cards.length} cards</span>
                </div>
              </div>
            </div>

            {generatedDeck.imageUrl && (
              <div className="preview-image">
                <img src={generatedDeck.imageUrl} alt={generatedDeck.name} />
              </div>
            )}

            <div className="preview-cards">
              <h4>Sample Cards:</h4>
              <div className="cards-grid">
                {generatedDeck.cards.slice(0, 8).map((card, index) => (
                  <div key={index} className="card-chip">
                    {card}
                  </div>
                ))}
                {generatedDeck.cards.length > 8 && (
                  <div className="card-chip more">
                    +{generatedDeck.cards.length - 8} more
                  </div>
                )}
              </div>
            </div>

            <div className="preview-actions">
              <button onClick={handleEdit} className="edit-button">
                <Edit size={18} />
                Edit Deck
              </button>
              <button onClick={handleSaveDeck} className="save-deck-button">
                <Save size={18} />
                Save Deck
              </button>
            </div>
          </div>

          <button 
            onClick={() => {
              setTopic('');
              setGeneratedDeck(null);
              setProgress(AIGenerationProgress.IDLE);
            }} 
            className="new-deck-button"
          >
            Generate Another Deck
          </button>
        </div>
      )}
    </div>
  );
};
