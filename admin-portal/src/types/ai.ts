// AI-related type definitions

/**
 * Difficulty levels for deck generation
 */
export type DifficultyLevel = 'easy' | 'medium' | 'hard';

/**
 * Difficulty configuration for card generation
 */
export interface DifficultyConfig {
  level: DifficultyLevel;
  cardCount: number;        // Number of cards to generate
  wordComplexity: string;   // Description of complexity level
  exampleFormat: string;    // Example format for AI
}

/**
 * Predefined difficulty configurations
 */
export const DIFFICULTY_CONFIGS: Record<DifficultyLevel, DifficultyConfig> = {
  easy: {
    level: 'easy',
    cardCount: 15,
    wordComplexity: 'Common, well-known words and household names (1-2 words)',
    exampleFormat: 'Examples: "Harry Potter", "Pizza", "Basketball", "Tiger", "Netflix"'
  },
  medium: {
    level: 'medium',
    cardCount: 18,
    wordComplexity: 'Moderately challenging phrases, mix of popular and specific (2-3 words)',
    exampleFormat: 'Examples: "Hermione Granger", "Margherita Pizza", "Three-Point Shot", "Bengal Tiger", "Stranger Things"'
  },
  hard: {
    level: 'hard',
    cardCount: 20,
    wordComplexity: 'Complex phrases, specific details, lesser-known items (3-4 words)',
    exampleFormat: 'Examples: "Dumbledore\'s Army Members", "Neapolitan Wood-Fired Pizza", "Stephen Curry\'s Signature Move", "Endangered Siberian Tiger", "Netflix Original Series 2024"'
  }
};

export interface DeckContent {
  name: string;
  description: string;
  cards: string[]; // For backward compatibility with single-difficulty decks
  cardsByDifficulty?: {
    easy: string[];
    medium: string[];
    hard: string[];
  };
  suggestedTags: string[];
  country: string;
  difficulty?: DifficultyLevel; // For single-difficulty decks (legacy)
  hasDifficultyModes?: boolean; // NEW: indicates this deck has multiple difficulty modes
  baseTopic?: string;       // Link related difficulty versions
  colorSuggestion?: number;
  iconSuggestion?: {
    codePoint: number;
    fontFamily: string;
  };
  translations?: {
    [languageCode: string]: {
      name: string;
      description: string;
      cards?: string[];
    };
  };
}

export interface AIGenerationConfig {
  maxCards: number;
  minCards: number;
  imageSize: '1024x1024' | '1024x1792' | '1792x1024';
  imageStyle?: string;
  temperature?: number;
}

export const AIGenerationProgress = {
  IDLE: 'idle',
  GENERATING_CONTENT: 'generating_content',
  GENERATING_IMAGE: 'generating_image',
  FINALIZING: 'finalizing',
  COMPLETE: 'complete',
  ERROR: 'error'
} as const;

export type AIGenerationProgress = typeof AIGenerationProgress[keyof typeof AIGenerationProgress];

export interface AIGenerationResult {
  success: boolean;
  deck?: DeckContent;
  imageUrl?: string;
  error?: AIError;
}

export interface AIError {
  code: AIErrorCode;
  message: string;
  details?: any;
}

export const AIErrorCode = {
  API_KEY_MISSING: 'api_key_missing',
  RATE_LIMIT: 'rate_limit',
  NETWORK_ERROR: 'network_error',
  INVALID_RESPONSE: 'invalid_response',
  IMAGE_GENERATION_FAILED: 'image_generation_failed',
  CONTENT_GENERATION_FAILED: 'content_generation_failed',
  UNKNOWN: 'unknown'
} as const;

export type AIErrorCode = typeof AIErrorCode[keyof typeof AIErrorCode];

export interface AIProviders {
  image: 'openai' | 'stability' | 'dalle3';
  content: 'anthropic' | 'openai' | 'gemini';
}


