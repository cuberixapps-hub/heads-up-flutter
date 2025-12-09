import React, { useState, useEffect, useCallback, useRef } from 'react';
import { Play, Pause, BarChart3, Globe, Sparkles, TrendingUp, AlertCircle, CheckCircle, XCircle, Clock, Flame, Brain, Users } from 'lucide-react';
import {
  getCountryDistribution,
  generateAutomaticDeck,
  generateMultiDifficultyDecks,
  generateResearchedDeck,
  getAutomationStats,
  canRunAutomation,
  sleep,
  type AutomationStats,
  type AutomationConfig
} from '../services/automationService';
import { getCountryByCode, COUNTRIES, type Country } from '../data/countries';
import { isTopicGenerationAvailable } from '../services/aiTopicService';
import '../styles/AutomatedDeckGenerator.css';

interface GenerationLog {
  id: string;
  timestamp: Date;
  message: string;
  type: 'info' | 'success' | 'error';
  deckId?: string;
}

interface LastGeneratedDeck {
  name: string;
  description: string;
  countries: string[]; // Changed to array
  imageUrl?: string;
  deckId: string;
  timestamp: Date;
  trendingReason?: string;
  culturalRelevance?: string;
  audienceAppeal?: string;
  whyItWorks?: string;
  difficulty?: 'easy' | 'medium' | 'hard';
  scores?: {
    viral: number;
    recognition: number;
    playability: number;
  };
  relatedDecks?: {
    id: string;
    difficulty: string;
    cardCount: number;
  }[];
}

export const AutomatedDeckGenerator: React.FC = () => {
  const [isRunning, setIsRunning] = useState(false);
  const [stats, setStats] = useState<AutomationStats | null>(null);
  const [logs, setLogs] = useState<GenerationLog[]>([]);
  const [currentGeneration, setCurrentGeneration] = useState<string>('');
  const [lastGeneratedDeck, setLastGeneratedDeck] = useState<LastGeneratedDeck | null>(null);
  const [config, setConfig] = useState<AutomationConfig>({
    enabled: false,
    delayBetweenGenerations: 10000, // 10 seconds
    maxConcurrentGenerations: 1,
    countriesPerDeck: 3, // Default to 3 countries per deck
    universalRatio: 70 // 70% universal, 30% regional (for Gen Z global appeal)
  });
  const [useResearchMode, setUseResearchMode] = useState(true); // NEW: Toggle for research mode
  const [targetAudiences, setTargetAudiences] = useState<Set<'teens' | 'adults' | 'families'>>( new Set(['teens']) ); // Default to teens (Gen Z) - now supports multiple
  const [selectedCountries, setSelectedCountries] = useState<Set<string>>(new Set()); // Selected countries for deck generation
  const [countryDistribution, setCountryDistribution] = useState<{ [key: string]: number }>({});
  const [validationError, setValidationError] = useState<string | null>(null);
  
  // Available countries for selection
  const SELECTABLE_COUNTRIES = [
    { code: 'IN', name: 'India', flag: '🇮🇳' },
    { code: 'US', name: 'USA', flag: '🇺🇸' },
    { code: 'CA', name: 'Canada', flag: '🇨🇦' },
    { code: 'AU', name: 'Australia', flag: '🇦🇺' },
    { code: 'GB', name: 'United Kingdom', flag: '🇬🇧' },
  ];
  
  const automationRef = useRef<boolean>(false);
  const logCounterRef = useRef<number>(0);

  // Load initial stats
  useEffect(() => {
    loadStats();
    loadCountryDistribution();
    
    // Validate automation capability
    const validation = canRunAutomation();
    if (!validation.canRun) {
      setValidationError(validation.reason || 'Cannot run automation');
    }
  }, []);

  const loadStats = async () => {
    const automationStats = await getAutomationStats();
    setStats(automationStats);
  };

  const loadCountryDistribution = async () => {
    const distribution = await getCountryDistribution();
    setCountryDistribution(distribution);
  };

  const addLog = useCallback((message: string, type: 'info' | 'success' | 'error', deckId?: string) => {
    const log: GenerationLog = {
      id: `log-${Date.now()}-${logCounterRef.current++}`,
      timestamp: new Date(),
      message,
      type,
      deckId
    };
    
    setLogs(prev => [log, ...prev].slice(0, 100)); // Keep last 100 logs
  }, []);

  // Helper function to pick a random audience from selected ones
  const getRandomTargetAudience = (): 'teens' | 'adults' | 'families' | undefined => {
    const audienceArray = Array.from(targetAudiences);
    if (audienceArray.length === 0) return undefined;
    return audienceArray[Math.floor(Math.random() * audienceArray.length)];
  };

  // Helper function to get Country objects from selected country codes
  const getSelectedCountryObjects = (): Country[] | undefined => {
    if (selectedCountries.size === 0) return undefined; // Let it auto-select
    
    const countries: Country[] = [];
    selectedCountries.forEach(code => {
      const country = COUNTRIES.find(c => c.code === code);
      if (country) countries.push(country);
    });
    return countries.length > 0 ? countries : undefined;
  };

  const runAutomationCycle = async () => {
    if (!automationRef.current) return;

    try {
      if (useResearchMode) {
        // NEW: Research-based generation with proper reasoning
        // Pick a random audience from the selected ones for variety
        const selectedAudience = getRandomTargetAudience();
        const audienceLabel = selectedAudience === 'teens' ? '🔥 Gen Z' : 
                              selectedAudience === 'adults' ? '👔 Millennials' : 
                              selectedAudience === 'families' ? '👨‍👩‍👧‍👦 Families' : '🌍 Universal';
        
        // Get selected countries (if any)
        const countriesToUse = getSelectedCountryObjects();
        const countryLabel = countriesToUse 
          ? countriesToUse.map(c => c.flag).join(' ')
          : '🌍 Auto-select';
        
        addLog(`🔬 Starting RESEARCHED deck generation for ${audienceLabel} | Countries: ${countryLabel}...`, 'info');
        
        const result = await generateResearchedDeck(
          countriesToUse, // Pass selected countries or undefined for auto-select
          selectedAudience, // Pass randomly selected audience from user's choices
          (progressMessage) => {
            setCurrentGeneration(progressMessage);
            addLog(progressMessage, 'info');
          },
          config
        );
        
        if (result.success && result.deckIds.length > 0) {
          addLog(`🎉 Successfully created PREMIUM researched deck!`, 'success');
          
          const deck = result.generatedDecks[0];
          if (deck) {
            setLastGeneratedDeck({
              name: deck.name,
              description: `Research-based deck with proper reasoning and cultural analysis`,
              countries: deck.countries || [],
              imageUrl: undefined,
              deckId: deck.id,
              timestamp: new Date(),
              trendingReason: deck.research.trendingReason,
              culturalRelevance: deck.research.culturalRelevance,
              audienceAppeal: deck.research.audienceAppeal,
              whyItWorks: deck.research.whyItWorks,
              scores: deck.research.scores,
              relatedDecks: [
                { id: deck.id, difficulty: 'easy', cardCount: deck.modes.easy },
                { id: deck.id, difficulty: 'medium', cardCount: deck.modes.medium },
                { id: deck.id, difficulty: 'hard', cardCount: deck.modes.hard }
              ]
            });
          }
          
          await loadStats();
          await loadCountryDistribution();
        } else {
          const errorMsg = result.errors.length > 0 ? result.errors.join(', ') : 'Unknown error';
          addLog(`❌ Failed to create researched deck: ${errorMsg}`, 'error');
        }
      } else {
        // ORIGINAL: Standard generation (legacy)
        addLog('🎯 Starting standard multi-difficulty deck generation...', 'info');
        
        const result = await generateMultiDifficultyDecks(
          undefined,
          undefined,
          (progressMessage) => {
            setCurrentGeneration(progressMessage);
            addLog(progressMessage, 'info');
          },
          config
        );
        
        if (result.success && result.deckIds.length > 0) {
          addLog(`🎉 Successfully created deck with 3 difficulty modes!`, 'success');
          
          const deck = result.generatedDecks[0];
          if (deck) {
            setLastGeneratedDeck({
              name: deck.name,
              description: `Deck with Easy, Medium, and Hard modes`,
              countries: deck.countries || [],
              imageUrl: undefined,
              deckId: deck.id,
              timestamp: new Date(),
              relatedDecks: [
                { id: deck.id, difficulty: 'easy', cardCount: deck.modes.easy },
                { id: deck.id, difficulty: 'medium', cardCount: deck.modes.medium },
                { id: deck.id, difficulty: 'hard', cardCount: deck.modes.hard }
              ]
            });
          }
          
          await loadStats();
          await loadCountryDistribution();
        } else {
          const errorMsg = result.errors.length > 0 ? result.errors.join(', ') : 'Unknown error';
          addLog(`❌ Failed to create deck: ${errorMsg}`, 'error');
        }
      }
      
      setCurrentGeneration('');
      
      // Wait before next generation
      if (automationRef.current) {
        const delay = config.delayBetweenGenerations;
        addLog(`⏳ Waiting ${delay / 1000} seconds before next generation cycle...`, 'info');
        await sleep(delay);
        
        // Continue automation if still enabled
        if (automationRef.current) {
          runAutomationCycle();
        }
      }
      
    } catch (error: any) {
      console.error('Automation cycle error:', error);
      addLog(`❌ Automation error: ${error.message}`, 'error');
      setCurrentGeneration('');
      
      // Continue automation after error with longer delay
      if (automationRef.current) {
        await sleep(config.delayBetweenGenerations * 2);
        if (automationRef.current) {
          runAutomationCycle();
        }
      }
    }
  };

  const handleToggleAutomation = async () => {
    if (validationError) {
      alert(validationError);
      return;
    }

    if (isRunning) {
      // Stop automation
      automationRef.current = false;
      setIsRunning(false);
      addLog('🛑 Automation stopped by user', 'info');
      setCurrentGeneration('');
    } else {
      // Start automation
      automationRef.current = true;
      setIsRunning(true);
      addLog('🚀 Automation started!', 'success');
      
      // Start the automation cycle
      runAutomationCycle();
    }
  };

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  };

  const getLogIcon = (type: GenerationLog['type']) => {
    switch (type) {
      case 'success':
        return <CheckCircle size={16} />;
      case 'error':
        return <XCircle size={16} />;
      default:
        return <Clock size={16} />;
    }
  };

  // Calculate distribution percentage
  const getTotalDecks = () => {
    return Object.values(countryDistribution).reduce((sum, count) => sum + count, 0);
  };

  const getDistributionPercentage = (count: number) => {
    const total = getTotalDecks();
    return total > 0 ? ((count / total) * 100).toFixed(1) : '0';
  };

  // Get top countries by deck count
  const getTopCountries = () => {
    return Object.entries(countryDistribution)
      .map(([code, count]) => ({
        code,
        count,
        country: getCountryByCode(code)
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);
  };

  return (
    <div className="automated-generator-container">
      {/* Header */}
      <div className="automated-header">
        <div className="header-content">
          <div className="header-icon">
            <Sparkles size={32} />
          </div>
          <div className="header-text">
            <h1>Automated Deck Generator</h1>
            <p>Fully automated deck creation with intelligent country distribution</p>
          </div>
        </div>
      </div>

      {validationError && (
        <div className="validation-error">
          <AlertCircle size={20} />
          <span>{validationError}</span>
        </div>
      )}

      {/* Control Panel */}
      <div className="control-panel">
        <div className="control-header">
          <h2>Automation Control</h2>
          <button
            onClick={handleToggleAutomation}
            className={`toggle-button ${isRunning ? 'running' : ''}`}
            disabled={!!validationError}
          >
            {isRunning ? (
              <>
                <Pause size={20} />
                Stop Automation
              </>
            ) : (
              <>
                <Play size={20} />
                Start Automation
              </>
            )}
          </button>
        </div>

        <div className="control-settings">
          <div className="setting-item setting-featured">
            <label className="setting-label-premium">
              <Brain size={20} />
              <span>Generation Mode:</span>
            </label>
            <div className="mode-toggle">
              <button
                className={`mode-button ${useResearchMode ? 'active' : ''}`}
                onClick={() => setUseResearchMode(true)}
                disabled={isRunning}
              >
                <Brain size={16} />
                <div className="mode-text">
                  <strong>Research Mode (RECOMMENDED)</strong>
                  <span className="mode-description">Generates well-researched decks with proper reasoning, data, and cultural analysis</span>
                </div>
              </button>
              <button
                className={`mode-button ${!useResearchMode ? 'active' : ''}`}
                onClick={() => setUseResearchMode(false)}
                disabled={isRunning}
              >
                <Sparkles size={16} />
                <div className="mode-text">
                  <strong>Standard Mode</strong>
                  <span className="mode-description">Basic AI generation (legacy mode)</span>
                </div>
              </button>
            </div>
          </div>
          
          {useResearchMode && (
            <>
              <div className="setting-item setting-featured">
                <label className="setting-label-premium">
                  <Users size={20} />
                  <span>Target Audiences (select multiple):</span>
                </label>
                <div className="audience-checkboxes">
                  <label className={`audience-checkbox ${targetAudiences.has('teens') ? 'selected' : ''}`}>
                    <input
                      type="checkbox"
                      checked={targetAudiences.has('teens')}
                      onChange={(e) => {
                        const newSet = new Set(targetAudiences);
                        if (e.target.checked) {
                          newSet.add('teens');
                        } else {
                          newSet.delete('teens');
                        }
                        // Ensure at least one is selected
                        if (newSet.size > 0) setTargetAudiences(newSet);
                      }}
                      disabled={isRunning}
                    />
                    <span className="checkbox-icon">🔥</span>
                    <span className="checkbox-label">Gen Z (16-28)</span>
                    <span className="checkbox-desc">Gaming, K-pop, Anime, Memes</span>
                  </label>
                  
                  <label className={`audience-checkbox ${targetAudiences.has('adults') ? 'selected' : ''}`}>
                    <input
                      type="checkbox"
                      checked={targetAudiences.has('adults')}
                      onChange={(e) => {
                        const newSet = new Set(targetAudiences);
                        if (e.target.checked) {
                          newSet.add('adults');
                        } else {
                          newSet.delete('adults');
                        }
                        if (newSet.size > 0) setTargetAudiences(newSet);
                      }}
                      disabled={isRunning}
                    />
                    <span className="checkbox-icon">👔</span>
                    <span className="checkbox-label">Millennials (25-40)</span>
                    <span className="checkbox-desc">Nostalgia, Streaming, Pop Culture</span>
                  </label>
                  
                  <label className={`audience-checkbox ${targetAudiences.has('families') ? 'selected' : ''}`}>
                    <input
                      type="checkbox"
                      checked={targetAudiences.has('families')}
                      onChange={(e) => {
                        const newSet = new Set(targetAudiences);
                        if (e.target.checked) {
                          newSet.add('families');
                        } else {
                          newSet.delete('families');
                        }
                        if (newSet.size > 0) setTargetAudiences(newSet);
                      }}
                      disabled={isRunning}
                    />
                    <span className="checkbox-icon">👨‍👩‍👧‍👦</span>
                    <span className="checkbox-label">Families</span>
                    <span className="checkbox-desc">Kid-friendly, Disney, Wholesome</span>
                  </label>
                </div>
                <span className="setting-hint">
                  Select multiple audiences - each generation cycle will randomly pick one from your selection
                </span>
              </div>
              
              <div className="setting-item setting-featured">
                <label className="setting-label-premium">
                  <Globe size={20} />
                  <span>Target Countries (optional):</span>
                </label>
                <div className="country-checkboxes">
                  {SELECTABLE_COUNTRIES.map(country => (
                    <label 
                      key={country.code}
                      className={`country-checkbox ${selectedCountries.has(country.code) ? 'selected' : ''}`}
                    >
                      <input
                        type="checkbox"
                        checked={selectedCountries.has(country.code)}
                        onChange={(e) => {
                          const newSet = new Set(selectedCountries);
                          if (e.target.checked) {
                            newSet.add(country.code);
                          } else {
                            newSet.delete(country.code);
                          }
                          setSelectedCountries(newSet);
                        }}
                        disabled={isRunning}
                      />
                      <span className="country-flag-icon">{country.flag}</span>
                      <span className="country-name-label">{country.name}</span>
                    </label>
                  ))}
                </div>
                <span className="setting-hint">
                  {selectedCountries.size === 0 
                    ? '🌍 No countries selected - will auto-select based on distribution balance'
                    : `✅ Selected ${selectedCountries.size} ${selectedCountries.size === 1 ? 'country' : 'countries'} - decks will be generated for these countries only`
                  }
                </span>
              </div>
              
              <div className="setting-item setting-featured">
                <label className="setting-label-premium">
                  <Globe size={20} />
                  <span>Topic Distribution:</span>
                </label>
                <div className="ratio-control">
                  <div className="ratio-slider">
                    <span className="ratio-label">🌍 Universal</span>
                    <input
                      type="range"
                      min="0"
                      max="100"
                      value={config.universalRatio || 70}
                      onChange={(e) => setConfig({
                        ...config,
                        universalRatio: parseInt(e.target.value)
                      })}
                      disabled={isRunning}
                      className="slider"
                    />
                    <span className="ratio-label">🌏 Regional</span>
                  </div>
                  <div className="ratio-display">
                    <span className="ratio-value universal">{config.universalRatio || 70}% Universal</span>
                    <span className="ratio-value regional">{100 - (config.universalRatio || 70)}% Regional</span>
                  </div>
                  <span className="setting-hint">
                    Universal topics work globally (viral trends, K-pop, anime). Regional topics are country-specific.
                  </span>
                </div>
              </div>
            </>
          )}
          
          <div className="setting-item">
            <label>Delay Between Generations (seconds):</label>
            <input
              type="number"
              value={config.delayBetweenGenerations / 1000}
              onChange={(e) => setConfig({
                ...config,
                delayBetweenGenerations: parseInt(e.target.value) * 1000
              })}
              min="5"
              max="300"
              disabled={isRunning}
            />
          </div>
          
          <div className="setting-item">
            <label>Additional Countries Per Deck:</label>
            <input
              type="number"
              value={config.countriesPerDeck || 3}
              onChange={(e) => setConfig({
                ...config,
                countriesPerDeck: Math.max(1, Math.min(10, parseInt(e.target.value) || 3))
              })}
              min="1"
              max="10"
              disabled={isRunning}
            />
            <span className="setting-hint">
              Each deck will be available in UNIVERSAL + this many specific countries
            </span>
          </div>
        </div>

        {isRunning && currentGeneration && (
          <div className="current-generation">
            <div className="generation-spinner"></div>
            <span>{currentGeneration}</span>
          </div>
        )}
      </div>

      {/* Statistics Dashboard */}
      <div className="stats-dashboard">
        <div className="stats-header">
          <BarChart3 size={24} />
          <h2>Statistics</h2>
        </div>

        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-icon">
              <TrendingUp size={24} />
            </div>
            <div className="stat-content">
              <span className="stat-label">Total Automated Decks</span>
              <span className="stat-value">{stats?.totalDecksCreated || 0}</span>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon">
              <Globe size={24} />
            </div>
            <div className="stat-content">
              <span className="stat-label">Countries Covered</span>
              <span className="stat-value">{Object.keys(countryDistribution).length}</span>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon">
              <Flame size={24} />
            </div>
            <div className="stat-content">
              <span className="stat-label">AI Topic Generation</span>
              <span className="stat-value">{isTopicGenerationAvailable() ? '✅ Active' : '❌ Inactive'}</span>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon">
              <CheckCircle size={24} />
            </div>
            <div className="stat-content">
              <span className="stat-label">Success Rate</span>
              <span className="stat-value">
                {stats?.totalDecksCreated ? '100%' : '0%'}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Last Generated Deck Preview */}
      {lastGeneratedDeck && (
        <div className="last-deck-preview">
          <div className="preview-header">
            <h2>Last Generated Deck</h2>
            <span className="preview-time">
              {formatTime(lastGeneratedDeck.timestamp)}
            </span>
          </div>
          
          <div className="preview-content">
            <div className="preview-info">
              <h3>{lastGeneratedDeck.name}</h3>
              <p>{lastGeneratedDeck.description}</p>
              
              {/* Difficulty Modes Display */}
              {lastGeneratedDeck.relatedDecks && lastGeneratedDeck.relatedDecks.length > 0 && (
                <div className="difficulty-versions">
                  <h4>🎯 Difficulty Modes (All in ONE deck):</h4>
                  <div className="difficulty-badges">
                    {lastGeneratedDeck.relatedDecks.map((mode, idx) => (
                      <div key={idx} className={`difficulty-badge difficulty-${mode.difficulty}`}>
                        <span className="difficulty-emoji">
                          {mode.difficulty === 'easy' ? '🟢' : mode.difficulty === 'medium' ? '🟡' : '🔴'}
                        </span>
                        <span className="difficulty-label">
                          {mode.difficulty.toUpperCase()}
                        </span>
                        <span className="difficulty-cards">
                          {mode.cardCount} cards
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
              
              {/* Quality Scores (Research Mode) */}
              {lastGeneratedDeck.scores && (
                <div className="quality-scores">
                  <h4>📊 Quality Metrics:</h4>
                  <div className="score-badges">
                    <div className="score-badge">
                      <Flame size={16} />
                      <span>Viral: {lastGeneratedDeck.scores.viral}/10</span>
                    </div>
                    <div className="score-badge">
                      <CheckCircle size={16} />
                      <span>Recognition: {lastGeneratedDeck.scores.recognition}/10</span>
                    </div>
                    <div className="score-badge">
                      <Sparkles size={16} />
                      <span>Playability: {lastGeneratedDeck.scores.playability}/10</span>
                    </div>
                  </div>
                </div>
              )}
              
              {lastGeneratedDeck.trendingReason && (
                <div className="trending-info">
                  <span className="trending-badge">
                    <Flame size={14} /> Trending
                  </span>
                  <p className="trending-reason">{lastGeneratedDeck.trendingReason}</p>
                </div>
              )}
              
              {lastGeneratedDeck.culturalRelevance && (
                <div className="cultural-info">
                  <span className="cultural-badge">
                    <Globe size={14} /> Cultural Relevance
                  </span>
                  <p className="cultural-reason">{lastGeneratedDeck.culturalRelevance}</p>
                </div>
              )}
              
              {lastGeneratedDeck.audienceAppeal && (
                <div className="audience-info">
                  <span className="audience-badge">
                    <Users size={14} /> Audience Appeal
                  </span>
                  <p className="audience-reason">{lastGeneratedDeck.audienceAppeal}</p>
                </div>
              )}
              
              {lastGeneratedDeck.whyItWorks && (
                <div className="why-it-works">
                  <span className="why-badge">
                    <Brain size={14} /> Why It Works
                  </span>
                  <p className="why-reason">{lastGeneratedDeck.whyItWorks}</p>
                </div>
              )}
              
              <div className="preview-meta">
                <div className="countries-badges">
                  {lastGeneratedDeck.countries.map(countryCode => {
                    const country = getCountryByCode(countryCode);
                    return country ? (
                      <span key={countryCode} className="country-badge">
                        {country.flag} {country.name}
                      </span>
                    ) : null;
                  })}
                </div>
                <span className="deck-id">Deck ID: {lastGeneratedDeck.deckId.slice(0, 8)}...</span>
              </div>
            </div>
            
            {lastGeneratedDeck.imageUrl && (
              <div className="preview-image-container">
                <img 
                  src={lastGeneratedDeck.imageUrl} 
                  alt={lastGeneratedDeck.name}
                  className="preview-image"
                />
                <div className="image-badge">✨ AI Generated</div>
              </div>
            )}
            
            {!lastGeneratedDeck.imageUrl && (
              <div className="no-image-placeholder">
                <span className="no-image-icon">🎨</span>
                <span className="no-image-text">Shared image for all modes</span>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Country Distribution */}
      <div className="distribution-panel">
        <div className="distribution-header">
          <Globe size={24} />
          <h2>Country Distribution</h2>
        </div>

        <div className="distribution-grid">
          {getTopCountries().map(({ code, count, country }) => (
            <div key={code} className="distribution-item">
              <div className="distribution-info">
                <span className="country-flag">{country?.flag || '🌍'}</span>
                <span className="country-name">{country?.name || code}</span>
              </div>
              <div className="distribution-stats">
                <span className="deck-count">{count} decks</span>
                <div className="distribution-bar">
                  <div 
                    className="distribution-fill"
                    style={{ width: `${getDistributionPercentage(count)}%` }}
                  ></div>
                </div>
                <span className="distribution-percentage">
                  {getDistributionPercentage(count)}%
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Activity Log */}
      <div className="activity-log">
        <div className="log-header">
          <h2>Activity Log</h2>
          {logs.length > 0 && (
            <button 
              onClick={() => setLogs([])}
              className="clear-log-button"
            >
              Clear Log
            </button>
          )}
        </div>

        <div className="log-container">
          {logs.length === 0 ? (
            <div className="log-empty">
              <Clock size={32} />
              <p>No activity yet. Start automation to see logs.</p>
            </div>
          ) : (
            logs.map(log => (
              <div key={log.id} className={`log-entry log-${log.type}`}>
                <div className="log-icon">{getLogIcon(log.type)}</div>
                <div className="log-content">
                  <span className="log-message">{log.message}</span>
                  <span className="log-time">{formatTime(log.timestamp)}</span>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};

