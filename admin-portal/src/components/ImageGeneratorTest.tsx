import React, { useState } from 'react';
import { generateDeckImage } from '../services/aiImageService';
import { isImageGenerationAvailable } from '../services/aiImageService';
import { Image, RefreshCw, Download, AlertCircle, CheckCircle, Loader } from 'lucide-react';
import '../styles/ImageGeneratorTest.css';

interface TestResult {
  topic: string;
  prompt: string;
  imageUrl: string | null;
  status: 'success' | 'error' | 'loading';
  error?: string;
  timestamp: Date;
  duration?: number;
}

const TEST_SCENARIOS = [
  {
    name: '🎬 Movies',
    topic: 'Classic Horror Movies',
    style: 'dark, cinematic, movie poster style with iconic horror elements'
  },
  {
    name: '🍕 Food',
    topic: 'Italian Cuisine',
    style: 'vibrant, appetizing, restaurant menu style with delicious food'
  },
  {
    name: '🦁 Animals',
    topic: 'African Safari',
    style: 'nature photography style, majestic wildlife in natural habitat'
  },
  {
    name: '🎮 Gaming',
    topic: 'Retro Video Games',
    style: 'pixel art style, nostalgic 8-bit gaming aesthetic'
  },
  {
    name: '🎵 Music',
    topic: '80s Pop Music',
    style: 'colorful, retro, neon lights and synthesizer vibes'
  },
  {
    name: '🏃 Sports',
    topic: 'Olympic Sports',
    style: 'dynamic, energetic, athletic action poses'
  },
  {
    name: '🌍 Travel',
    topic: 'World Landmarks',
    style: 'travel photography, iconic monuments and destinations'
  },
  {
    name: '🎭 Entertainment',
    topic: 'Broadway Musicals',
    style: 'theatrical, dramatic, stage performance aesthetic'
  }
];

export const ImageGeneratorTest: React.FC = () => {
  const [customTopic, setCustomTopic] = useState('');
  const [customStyle, setCustomStyle] = useState('vibrant, colorful, game-style illustration');
  const [testResults, setTestResults] = useState<TestResult[]>([]);
  const [currentTest, setCurrentTest] = useState<string | null>(null);
  const [isAvailable, setIsAvailable] = useState(isImageGenerationAvailable());

  const runTest = async (topic: string, style: string) => {
    setCurrentTest(topic);
    const startTime = Date.now();

    // Add loading result
    const loadingResult: TestResult = {
      topic,
      prompt: `Create a ${style} cover image for a Heads Up game deck about "${topic}".`,
      imageUrl: null,
      status: 'loading',
      timestamp: new Date()
    };
    setTestResults(prev => [loadingResult, ...prev]);

    try {
      const imageUrl = await generateDeckImage(topic, style);
      const duration = Date.now() - startTime;

      // Update with success
      setTestResults(prev => prev.map((result, index) => 
        index === 0 ? {
          ...result,
          imageUrl,
          status: 'success' as const,
          duration
        } : result
      ));
    } catch (error: any) {
      const duration = Date.now() - startTime;

      // Update with error
      setTestResults(prev => prev.map((result, index) => 
        index === 0 ? {
          ...result,
          status: 'error' as const,
          error: error.message || 'Unknown error occurred',
          duration
        } : result
      ));
    } finally {
      setCurrentTest(null);
    }
  };

  const runCustomTest = () => {
    if (!customTopic.trim()) {
      alert('Please enter a topic');
      return;
    }
    runTest(customTopic, customStyle);
  };

  const downloadImage = async (url: string, topic: string) => {
    try {
      const response = await fetch(url);
      const blob = await response.blob();
      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob);
      link.download = `${topic.replace(/[^a-z0-9]/gi, '_')}.png`;
      link.click();
    } catch (error) {
      console.error('Download failed:', error);
      alert('Failed to download image');
    }
  };

  const clearResults = () => {
    setTestResults([]);
  };

  return (
    <div className="image-test-container">
      <div className="test-header">
        <div className="header-icon">
          <Image size={40} />
        </div>
        <h1>AI Image Generation Test Lab</h1>
        <p>Test DALL-E 3 image generation with different prompts and styles</p>
        
        {!isAvailable && (
          <div className="status-banner error">
            <AlertCircle size={20} />
            <span>OpenAI API key not configured. Please add VITE_OPENAI_API_KEY to .env.local</span>
          </div>
        )}
        
        {isAvailable && (
          <div className="status-banner success">
            <CheckCircle size={20} />
            <span>Image generation is available and ready to test!</span>
          </div>
        )}
      </div>

      {/* Custom Test Section */}
      <div className="custom-test-section">
        <h2>🎨 Custom Test</h2>
        <div className="custom-inputs">
          <div className="input-group">
            <label>Topic:</label>
            <input
              type="text"
              value={customTopic}
              onChange={(e) => setCustomTopic(e.target.value)}
              placeholder="Enter a deck topic (e.g., 'Space Exploration')"
              className="topic-input"
            />
          </div>
          
          <div className="input-group">
            <label>Style Modifier:</label>
            <input
              type="text"
              value={customStyle}
              onChange={(e) => setCustomStyle(e.target.value)}
              placeholder="Describe the visual style"
              className="style-input"
            />
          </div>

          <button 
            onClick={runCustomTest}
            disabled={!isAvailable || currentTest !== null}
            className="test-button primary"
          >
            {currentTest ? <Loader className="spinner" size={20} /> : <Image size={20} />}
            Generate Custom Image
          </button>
        </div>

        <div className="style-presets">
          <span className="presets-label">Style Presets:</span>
          <button onClick={() => setCustomStyle('vibrant, colorful, game-style illustration')}>Game Style</button>
          <button onClick={() => setCustomStyle('minimalist, modern, clean design')}>Minimalist</button>
          <button onClick={() => setCustomStyle('cartoon, playful, fun artwork')}>Cartoon</button>
          <button onClick={() => setCustomStyle('realistic, photographic, detailed')}>Realistic</button>
          <button onClick={() => setCustomStyle('abstract, artistic, creative expression')}>Abstract</button>
        </div>
      </div>

      {/* Preset Tests Section */}
      <div className="preset-tests-section">
        <h2>🧪 Preset Test Scenarios</h2>
        <div className="test-scenarios-grid">
          {TEST_SCENARIOS.map((scenario) => (
            <div key={scenario.name} className="scenario-card">
              <div className="scenario-header">
                <span className="scenario-name">{scenario.name}</span>
              </div>
              <div className="scenario-details">
                <strong>Topic:</strong> {scenario.topic}
                <br />
                <strong>Style:</strong> {scenario.style}
              </div>
              <button
                onClick={() => runTest(scenario.topic, scenario.style)}
                disabled={!isAvailable || currentTest !== null}
                className="test-button"
              >
                {currentTest === scenario.topic ? (
                  <Loader className="spinner" size={16} />
                ) : (
                  <Image size={16} />
                )}
                Test
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* Results Section */}
      {testResults.length > 0 && (
        <div className="results-section">
          <div className="results-header">
            <h2>📊 Test Results ({testResults.length})</h2>
            <button onClick={clearResults} className="clear-button">
              Clear All
            </button>
          </div>

          <div className="results-grid">
            {testResults.map((result, index) => (
              <div key={index} className={`result-card ${result.status}`}>
                <div className="result-header">
                  <div className="result-info">
                    <h3>{result.topic}</h3>
                    <span className="result-time">
                      {result.timestamp.toLocaleTimeString()}
                      {result.duration && ` (${(result.duration / 1000).toFixed(1)}s)`}
                    </span>
                  </div>
                  <div className={`result-status ${result.status}`}>
                    {result.status === 'loading' && <Loader className="spinner" size={20} />}
                    {result.status === 'success' && <CheckCircle size={20} />}
                    {result.status === 'error' && <AlertCircle size={20} />}
                  </div>
                </div>

                <div className="result-prompt">
                  <strong>Prompt:</strong> {result.prompt}
                </div>

                {result.status === 'success' && result.imageUrl && (
                  <div className="result-image-container">
                    <img 
                      src={result.imageUrl} 
                      alt={result.topic}
                      className="result-image"
                    />
                    <div className="image-actions">
                      <button 
                        onClick={() => window.open(result.imageUrl!, '_blank')}
                        className="action-button"
                      >
                        <Image size={16} />
                        View Full
                      </button>
                      <button 
                        onClick={() => downloadImage(result.imageUrl!, result.topic)}
                        className="action-button"
                      >
                        <Download size={16} />
                        Download
                      </button>
                    </div>
                  </div>
                )}

                {result.status === 'error' && (
                  <div className="result-error">
                    <AlertCircle size={20} />
                    <span>{result.error}</span>
                  </div>
                )}

                {result.status === 'loading' && (
                  <div className="result-loading">
                    <Loader className="spinner" size={40} />
                    <span>Generating image with DALL-E 3...</span>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Info Section */}
      <div className="info-section">
        <h3>ℹ️ About This Test Page</h3>
        <ul>
          <li>Tests DALL-E 3 image generation API integration</li>
          <li>Each generation costs approximately $0.04-0.08</li>
          <li>Images are 1024x1024 pixels in PNG format</li>
          <li>Generated images are uploaded to Firebase Storage</li>
          <li>Average generation time: 15-30 seconds</li>
        </ul>
      </div>
    </div>
  );
};

