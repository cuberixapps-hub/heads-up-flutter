// AI-related type definitions

export interface DeckContent {
  name: string;
  description: string;
  cards: string[];
  suggestedTags: string[];
  country: string;
  colorSuggestion?: number;
  iconSuggestion?: {
    codePoint: number;
    fontFamily: string;
  };
}

export interface AIGenerationConfig {
  maxCards: number;
  minCards: number;
  imageSize: '1024x1024' | '1024x1792' | '1792x1024';
  imageStyle?: string;
  temperature?: number;
}

export enum AIGenerationProgress {
  IDLE = 'idle',
  GENERATING_CONTENT = 'generating_content',
  GENERATING_IMAGE = 'generating_image',
  FINALIZING = 'finalizing',
  COMPLETE = 'complete',
  ERROR = 'error'
}

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

export enum AIErrorCode {
  API_KEY_MISSING = 'api_key_missing',
  RATE_LIMIT = 'rate_limit',
  NETWORK_ERROR = 'network_error',
  INVALID_RESPONSE = 'invalid_response',
  IMAGE_GENERATION_FAILED = 'image_generation_failed',
  CONTENT_GENERATION_FAILED = 'content_generation_failed',
  UNKNOWN = 'unknown'
}

export interface AIProviders {
  image: 'openai' | 'stability' | 'dalle3';
  content: 'anthropic' | 'openai' | 'gemini';
}

