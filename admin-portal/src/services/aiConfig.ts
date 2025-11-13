import OpenAI from 'openai';
import Anthropic from '@anthropic-ai/sdk';
import type { AIError } from '../types/ai';
import { AIErrorCode } from '../types/ai';

// Environment variable validation
const OPENAI_API_KEY = import.meta.env.VITE_OPENAI_API_KEY;
const ANTHROPIC_API_KEY = import.meta.env.VITE_ANTHROPIC_API_KEY;
const AI_IMAGE_PROVIDER = import.meta.env.VITE_AI_IMAGE_PROVIDER || 'openai';

// API Client instances
let openaiClient: OpenAI | null = null;
let anthropicClient: Anthropic | null = null;

// Validate API keys on initialization
export const validateAPIKeys = (): { valid: boolean; missing: string[] } => {
  const missing: string[] = [];
  
  if (!OPENAI_API_KEY || OPENAI_API_KEY === 'your_openai_api_key_here') {
    missing.push('OpenAI');
  }
  
  if (!ANTHROPIC_API_KEY || ANTHROPIC_API_KEY === 'your_anthropic_api_key_here') {
    missing.push('Anthropic');
  }
  
  return {
    valid: missing.length === 0,
    missing
  };
};

// Initialize OpenAI client
export const getOpenAIClient = (): OpenAI => {
  if (!openaiClient) {
    if (!OPENAI_API_KEY || OPENAI_API_KEY === 'your_openai_api_key_here') {
      throw new Error('OpenAI API key is not configured');
    }
    openaiClient = new OpenAI({
      apiKey: OPENAI_API_KEY,
      dangerouslyAllowBrowser: true // Note: In production, use a backend API
    });
  }
  return openaiClient;
};

// Initialize Anthropic client
export const getAnthropicClient = (): Anthropic => {
  if (!anthropicClient) {
    if (!ANTHROPIC_API_KEY || ANTHROPIC_API_KEY === 'your_anthropic_api_key_here') {
      throw new Error('Anthropic API key is not configured');
    }
    anthropicClient = new Anthropic({
      apiKey: ANTHROPIC_API_KEY,
      dangerouslyAllowBrowser: true // Note: In production, use a backend API
    });
  }
  return anthropicClient;
};

// Helper function to handle API errors
export const handleAIError = (error: any): AIError => {
  console.error('AI Service Error:', error);
  
  // Check for rate limit errors
  if (error.status === 429 || error.message?.includes('rate limit')) {
    return {
      code: AIErrorCode.RATE_LIMIT,
      message: 'Rate limit reached. Please try again in a few moments.',
      details: error
    };
  }
  
  // Check for network errors
  if (error.code === 'ECONNREFUSED' || error.message?.includes('network')) {
    return {
      code: AIErrorCode.NETWORK_ERROR,
      message: 'Network error. Please check your connection and try again.',
      details: error
    };
  }
  
  // Check for API key errors
  if (error.status === 401 || error.message?.includes('authentication')) {
    return {
      code: AIErrorCode.API_KEY_MISSING,
      message: 'Invalid API key. Please check your configuration.',
      details: error
    };
  }
  
  // Default error
  return {
    code: AIErrorCode.UNKNOWN,
    message: error.message || 'An unexpected error occurred',
    details: error
  };
};

// Get configuration values
export const getAIConfig = () => ({
  imageProvider: AI_IMAGE_PROVIDER,
  hasOpenAIKey: !!OPENAI_API_KEY && OPENAI_API_KEY !== 'your_openai_api_key_here',
  hasAnthropicKey: !!ANTHROPIC_API_KEY && ANTHROPIC_API_KEY !== 'your_anthropic_api_key_here',
});

// Safety wrapper for API calls with retry logic
export const withRetry = async <T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  delay: number = 1000
): Promise<T> => {
  let lastError: any;
  
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error: any) {
      lastError = error;
      
      // Don't retry on authentication errors
      if (error.status === 401) {
        throw error;
      }
      
      // Wait before retrying
      if (i < maxRetries - 1) {
        await new Promise(resolve => setTimeout(resolve, delay * (i + 1)));
      }
    }
  }
  
  throw lastError;
};
