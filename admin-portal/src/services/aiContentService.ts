import { getAnthropicClient, handleAIError, withRetry } from './aiConfig';
import type { DeckContent } from '../types/ai';
import { AIErrorCode } from '../types/ai';

// Default color values for different deck categories
const categoryColors: { [key: string]: number } = {
  movies: 0xFFE91E63,     // Pink
  food: 0xFFFF9800,       // Orange
  animals: 0xFF4CAF50,    // Green
  sports: 0xFF2196F3,     // Blue
  music: 0xFF9C27B0,      // Purple
  travel: 0xFF00BCD4,     // Cyan
  celebrities: 0xFFFF5722, // Deep Orange
  games: 0xFF673AB7,      // Deep Purple
  default: 0xFF9C27B0     // Purple
};

// Icon suggestions based on categories
const categoryIcons: { [key: string]: { codePoint: number; fontFamily: string } } = {
  movies: { codePoint: 0xf008, fontFamily: 'FontAwesomeIcons' }, // Film
  food: { codePoint: 0xf0f5, fontFamily: 'FontAwesomeIcons' }, // Utensils
  animals: { codePoint: 0xf1b0, fontFamily: 'FontAwesomeIcons' }, // Paw
  sports: { codePoint: 0xf1e3, fontFamily: 'FontAwesomeIcons' }, // Football
  music: { codePoint: 0xf001, fontFamily: 'FontAwesomeIcons' }, // Music
  travel: { codePoint: 0xf0ac, fontFamily: 'FontAwesomeIcons' }, // Globe
  celebrities: { codePoint: 0xf005, fontFamily: 'FontAwesomeIcons' }, // Star
  games: { codePoint: 0xf11b, fontFamily: 'FontAwesomeIcons' }, // Gamepad
  default: { codePoint: 0xf005, fontFamily: 'FontAwesomeIcons' } // Star
};

/**
 * Generate deck content using Claude
 * @param topic The deck topic/theme
 * @returns Promise<DeckContent> Generated deck content
 */
export const generateDeckContent = async (topic: string): Promise<DeckContent> => {
  try {
    const anthropic = getAnthropicClient();
    
    const systemPrompt = `You are a creative game designer for the Heads Up! game. 
    Generate engaging and fun content for game decks based on the given topic.
    Return your response as valid JSON only, with no additional text.`;
    
    const userPrompt = `Create a Heads Up! game deck about "${topic}".

Generate a JSON response with this exact structure:
{
  "name": "Catchy deck name (2-4 words max)",
  "description": "Brief engaging description (1-2 sentences)",
  "cards": ["array of 15-20 words/phrases that players will guess"],
  "suggestedTags": ["3-5 relevant tags"],
  "country": "UNIVERSAL or specific country code if culturally specific (US, GB, IN, JP, etc)",
  "category": "one of: movies, food, animals, sports, music, travel, celebrities, games, or other"
}

Make the cards diverse, recognizable, and fun to act out or describe.
Cards should be single words or short phrases (1-4 words).
Ensure content is family-friendly and culturally appropriate.`;

    console.log('Generating deck content for topic:', topic);
    
    // Call Claude API with retry logic
    const response = await withRetry(async () => {
      const message = await anthropic.messages.create({
        model: 'claude-3-haiku-20240307',
        max_tokens: 1000,
        temperature: 0.8,
        system: systemPrompt,
        messages: [
          {
            role: 'user',
            content: userPrompt
          }
        ]
      });
      
      return message;
    });
    
    // Extract the text content from Claude's response
    const textContent = response.content[0].type === 'text' 
      ? response.content[0].text 
      : '';
    
    if (!textContent) {
      throw new Error('No text content in Claude response');
    }
    
    // Parse JSON response
    let parsedContent;
    try {
      // Clean the response in case it has markdown code blocks
      const jsonStr = textContent.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      parsedContent = JSON.parse(jsonStr);
    } catch (parseError) {
      console.error('Failed to parse Claude response:', textContent);
      throw new Error('Invalid JSON response from AI');
    }
    
    // Determine color and icon based on category
    const category = parsedContent.category || 'default';
    const colorValue = categoryColors[category] || categoryColors.default;
    const iconSuggestion = categoryIcons[category] || categoryIcons.default;
    
    // Ensure we have at least 10 cards
    if (!parsedContent.cards || parsedContent.cards.length < 10) {
      throw new Error('Insufficient cards generated');
    }
    
    // Construct the deck content
    const deckContent: DeckContent = {
      name: parsedContent.name || `${topic} Deck`,
      description: parsedContent.description || `A fun deck about ${topic}`,
      cards: parsedContent.cards.slice(0, 20), // Limit to 20 cards
      suggestedTags: parsedContent.suggestedTags || [topic.toLowerCase()],
      country: parsedContent.country || 'UNIVERSAL',
      colorSuggestion: colorValue,
      iconSuggestion: iconSuggestion
    };
    
    console.log('Successfully generated deck content:', deckContent.name);
    return deckContent;
    
  } catch (error: any) {
    console.error('Content generation error:', error);
    
    // Handle specific AI errors
    const aiError = handleAIError(error);
    
    // For content generation failures, return fallback content
    if (aiError.code === AIErrorCode.API_KEY_MISSING || 
        aiError.code === AIErrorCode.RATE_LIMIT) {
      console.warn('Falling back to basic content due to:', aiError.message);
      return generateFallbackContent(topic);
    }
    
    throw aiError;
  }
};

/**
 * Generate fallback content when AI is unavailable
 */
const generateFallbackContent = (topic: string): DeckContent => {
  const topicLower = topic.toLowerCase();
  
  // Simple category detection
  let category = 'default';
  let cards: string[] = [];
  
  if (topicLower.includes('movie') || topicLower.includes('film')) {
    category = 'movies';
    cards = [
      'The Lion King', 'Titanic', 'Star Wars', 'The Matrix', 'Frozen',
      'Avatar', 'Inception', 'Toy Story', 'Harry Potter', 'The Avengers',
      'Jurassic Park', 'The Dark Knight', 'Forrest Gump', 'Shrek', 'Finding Nemo'
    ];
  } else if (topicLower.includes('food') || topicLower.includes('eat')) {
    category = 'food';
    cards = [
      'Pizza', 'Burger', 'Sushi', 'Tacos', 'Ice Cream',
      'Pasta', 'Chocolate', 'Salad', 'Sandwich', 'French Fries',
      'Steak', 'Chicken', 'Rice', 'Soup', 'Cake'
    ];
  } else if (topicLower.includes('animal') || topicLower.includes('pet')) {
    category = 'animals';
    cards = [
      'Dog', 'Cat', 'Lion', 'Elephant', 'Giraffe',
      'Monkey', 'Tiger', 'Bear', 'Penguin', 'Dolphin',
      'Horse', 'Rabbit', 'Snake', 'Eagle', 'Butterfly'
    ];
  } else {
    // Generic cards
    cards = Array.from({ length: 15 }, (_, i) => `${topic} Item ${i + 1}`);
  }
  
  return {
    name: `${topic} Deck`,
    description: `A collection of items related to ${topic}`,
    cards,
    suggestedTags: [topic.toLowerCase(), 'custom'],
    country: 'UNIVERSAL',
    colorSuggestion: categoryColors[category],
    iconSuggestion: categoryIcons[category]
  };
};

/**
 * Generate additional card suggestions for an existing deck
 */
export const generateAdditionalCards = async (
  deckName: string,
  existingCards: string[],
  count: number = 10
): Promise<string[]> => {
  try {
    const anthropic = getAnthropicClient();
    
    const prompt = `Given a Heads Up! deck called "${deckName}" with these existing cards:
${existingCards.slice(0, 10).join(', ')}${existingCards.length > 10 ? ', ...' : ''}

Generate ${count} additional cards that fit the same theme and style.
Return only a JSON array of strings, no other text.`;
    
    const response = await withRetry(async () => {
      const message = await anthropic.messages.create({
        model: 'claude-3-haiku-20240307',
        max_tokens: 500,
        temperature: 0.8,
        messages: [
          {
            role: 'user',
            content: prompt
          }
        ]
      });
      
      return message;
    });
    
    const textContent = response.content[0].type === 'text' 
      ? response.content[0].text 
      : '';
    
    // Parse the response
    const jsonStr = textContent.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    const suggestions = JSON.parse(jsonStr);
    
    if (!Array.isArray(suggestions)) {
      throw new Error('Invalid response format');
    }
    
    return suggestions.slice(0, count);
    
  } catch (error) {
    console.error('Failed to generate additional cards:', error);
    // Return empty array as fallback
    return [];
  }
};

/**
 * Validate if content generation is available
 */
export const isContentGenerationAvailable = (): boolean => {
  try {
    getAnthropicClient();
    return true;
  } catch {
    return false;
  }
};
