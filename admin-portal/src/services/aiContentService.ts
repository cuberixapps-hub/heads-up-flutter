import { getOpenAIClient, handleAIError, withRetry } from './aiConfig';
import type { DeckContent, DifficultyLevel, DIFFICULTY_CONFIGS } from '../types/ai';
import { DIFFICULTY_CONFIGS as difficultyConfigs } from '../types/ai';
import { fetchFreshData, topicNeedsFreshData } from './freshDataService';

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

export interface FreshDataMeta {
  usedFreshData: boolean;
  freshDataRetrievedAt?: Date;
}

export interface DeckContentWithMeta extends DeckContent {
  freshDataMeta?: FreshDataMeta;
}

/**
 * Generate deck content using OpenAI with optional live web grounding
 * @param topic The deck topic/theme
 * @param difficulty The difficulty level (easy, medium, hard)
 * @param countryContext Optional country name for culturally relevant content
 * @param useFreshData When true (or auto-detected for meme/trending topics),
 *                     calls freshDataService to ground cards in live 2026 content
 * @returns Promise<DeckContentWithMeta> Generated deck content + fresh-data metadata
 */
export const generateDeckContent = async (
  topic: string,
  difficulty: DifficultyLevel = 'medium',
  countryContext?: string,
  useFreshData?: boolean
): Promise<DeckContentWithMeta> => {
  try {
    const openai = getOpenAIClient();
    const diffConfig = difficultyConfigs[difficulty];

    // -----------------------------------------------------------------------
    // Fresh web data grounding
    // -----------------------------------------------------------------------
    const shouldUseFresh = useFreshData ?? topicNeedsFreshData(topic);
    let freshGrounding = '';
    let freshDataMeta: FreshDataMeta = { usedFreshData: false };

    if (shouldUseFresh) {
      console.log('🌐 Fetching fresh web data for topic:', topic);
      try {
        const freshResult = await fetchFreshData(topic);
        freshGrounding = `\n\n🌐 LIVE WEB DATA (retrieved ${freshResult.retrievedAt.toISOString()}):\nUse the following current trending items to build the deck cards — these are real 2026 viral/trending items:\n${freshResult.summary}`;
        freshDataMeta = {
          usedFreshData: true,
          freshDataRetrievedAt: freshResult.retrievedAt,
        };
        console.log('✅ Fresh web data incorporated into prompt');
      } catch (freshErr) {
        console.warn('⚠️ Fresh data fetch failed, continuing without it:', freshErr);
      }
    }
    // -----------------------------------------------------------------------

    const contextNote = countryContext
      ? `\n\n🌍 COUNTRY CONTEXT: This deck is primarily for ${countryContext}. Make content culturally relevant and relatable to ${countryContext} audiences while still being accessible to others. Include references, examples, or items that are popular or trending in ${countryContext}.`
      : '\n\n🌍 COUNTRY CONTEXT: This deck is for UNIVERSAL audiences. Make content globally accessible and recognizable.';

    const systemPrompt = `You are a creative game designer for the Heads Up! game. 
    Generate engaging and fun content for game decks based on the given topic, difficulty level, and cultural context.
    Return your response as valid JSON only, with no additional text.`;

    const userPrompt = `Create a Heads Up! game deck about "${topic}" with ${difficulty.toUpperCase()} difficulty.${contextNote}${freshGrounding}

🎯 DIFFICULTY: ${difficulty.toUpperCase()}
${diffConfig.wordComplexity}
${diffConfig.exampleFormat}

Generate a JSON response with this exact structure:
{
  "name": "Catchy deck name (2-4 words max)",
  "description": "Brief engaging description (1-2 sentences)",
  "cards": ["array of EXACTLY ${diffConfig.cardCount} words/phrases"],
  "suggestedTags": ["3-5 relevant tags"],
  "country": "UNIVERSAL or specific country code if culturally specific (US, GB, IN, JP, etc)",
  "category": "one of: movies, food, animals, sports, music, travel, celebrities, games, or other"
}

📋 CARD GENERATION RULES for ${difficulty.toUpperCase()}:

${difficulty === 'easy' ? `
EASY MODE:
- Use well-known, instantly recognizable items
- Keep it simple: 1-2 words max
- Think household names everyone knows
- Examples from "${topic}":
  * If movies: "Titanic", "Avatar", "Frozen"
  * If food: "Pizza", "Burger", "Tacos"
  * If celebrities: "Taylor Swift", "LeBron James"
- Perfect for beginners and quick games!
` : difficulty === 'medium' ? `
MEDIUM MODE:
- Mix of popular and more specific items
- Use 2-3 words for added challenge
- Balance well-known with slightly niche
- Examples from "${topic}":
  * If movies: "Titanic Sinking Scene", "Avatar Blue People", "Frozen Let It Go"
  * If food: "Pepperoni Pizza", "Cheeseburger Special", "Fish Tacos"
  * If celebrities: "Taylor Swift Concert", "LeBron James Dunk"
- Good challenge for regular players!
` : `
HARD MODE:
- Specific, detailed, lesser-known items
- Use 3-4 words for maximum challenge
- Include specific details and deep cuts
- Examples from "${topic}":
  * If movies: "Titanic Jack and Rose Door Scene", "Avatar Navi Language Words", "Frozen Elsa Ice Palace Build"
  * If food: "Wood-Fired Margherita Pizza", "Wagyu Beef Cheeseburger Deluxe", "Grilled Mahi Mahi Tacos"
  * If celebrities: "Taylor Swift Eras Tour Surprise Songs", "LeBron James Championship Block"
- Ultimate challenge for experts!
`}

🎮 QUALITY REQUIREMENTS:
- Make cards diverse and varied
- Ensure all cards are recognizable (appropriate for difficulty level)
- Cards should be fun to act out or describe
- Mix different aspects of the topic
- MUST generate EXACTLY ${diffConfig.cardCount} cards
- Cards should be family-friendly and culturally appropriate

Generate EXACTLY ${diffConfig.cardCount} amazing cards for this ${difficulty} difficulty deck!`;

    console.log(`Generating ${difficulty} deck content for topic:`, topic);

    // Call OpenAI API with retry logic
    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-5.1', // Latest flagship model
        max_completion_tokens: 2000,
        temperature: 0.8,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ]
      });
    });

    // Extract the text content from OpenAI's response
    const textContent = response.choices[0]?.message?.content?.trim();

    if (!textContent) {
      throw new Error('No text content in OpenAI response');
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

    // Ensure we have the right number of cards
    if (!parsedContent.cards || parsedContent.cards.length < 10) {
      throw new Error('Insufficient cards generated');
    }

    // Limit to the difficulty-specific card count
    const cards = parsedContent.cards.slice(0, diffConfig.cardCount);

    // Construct the deck content with difficulty
    const deckContent: DeckContentWithMeta = {
      name: parsedContent.name || `${topic} Deck`,
      description: parsedContent.description || `A fun ${difficulty} deck about ${topic}`,
      cards,
      suggestedTags: parsedContent.suggestedTags || [topic.toLowerCase()],
      country: parsedContent.country || 'UNIVERSAL',
      difficulty,
      baseTopic: topic, // Store the base topic to link related difficulty versions
      colorSuggestion: colorValue,
      iconSuggestion: iconSuggestion,
      freshDataMeta,
    };

    console.log(`✅ Successfully generated ${difficulty} deck content: "${deckContent.name}" (${cards.length} cards)`);
    return deckContent;

  } catch (error: any) {
    console.error('Content generation error:', error);

    // Handle specific AI errors
    const aiError = handleAIError(error);

    // For content generation failures, return fallback content
    if (aiError.code === 'api_key_missing' ||
        aiError.code === 'rate_limit') {
      console.warn('Falling back to basic content due to:', aiError.message);
      return generateFallbackContent(topic, difficulty);
    }

    throw aiError;
  }
};

/**
 * Generate fallback content when AI is unavailable
 */
const generateFallbackContent = (topic: string, difficulty: DifficultyLevel = 'medium'): DeckContentWithMeta => {
  const topicLower = topic.toLowerCase();
  const diffConfig = difficultyConfigs[difficulty];

  // Simple category detection
  let category = 'default';
  let cards: string[] = [];

  if (topicLower.includes('movie') || topicLower.includes('film')) {
    category = 'movies';
    cards = difficulty === 'easy'
      ? ['Titanic', 'Avatar', 'Frozen', 'Star Wars', 'The Matrix', 'Toy Story', 'Harry Potter', 'The Avengers', 'Jurassic Park', 'The Lion King', 'Shrek', 'Finding Nemo', 'Inception', 'Forrest Gump', 'The Dark Knight']
      : difficulty === 'medium'
      ? ['Titanic Sinking', 'Avatar Blue People', 'Frozen Elsa', 'Star Wars Lightsaber', 'The Matrix Bullet Time', 'Toy Story Woody', 'Harry Potter Wand', 'Avengers Team Up', 'Jurassic Park T-Rex', 'Lion King Circle', 'Shrek Donkey', 'Finding Nemo Dory', 'Inception Dream', 'Forrest Gump Running', 'Dark Knight Joker', 'Titanic Door Scene', 'Avatar Tree', 'Frozen Castle']
      : ['Titanic Jack Rose Door', 'Avatar Navi Tree Connection', 'Frozen Let It Go Scene', 'Star Wars Force Awakens', 'Matrix Neo Bullet Dodge', 'Toy Story Andy Growing Up', 'Harry Potter Patronus Spell', 'Avengers Infinity Stones Snap', 'Jurassic Park Raptor Kitchen', 'Lion King Mufasa Death', 'Shrek Onion Layers Speech', 'Finding Nemo Sydney Harbor', 'Inception Spinning Top Ending', 'Forrest Gump Chocolates Quote', 'Dark Knight Bank Heist', 'Titanic Heart Ocean Necklace', 'Avatar Pandora Floating Mountains', 'Frozen Ice Palace Build', 'Star Wars I Am Father', 'Matrix Red Blue Pill'];
  } else if (topicLower.includes('food') || topicLower.includes('eat')) {
    category = 'food';
    cards = difficulty === 'easy'
      ? ['Pizza', 'Burger', 'Sushi', 'Tacos', 'Ice Cream', 'Pasta', 'Chocolate', 'Salad', 'Sandwich', 'French Fries', 'Steak', 'Chicken', 'Rice', 'Soup', 'Cake']
      : difficulty === 'medium'
      ? ['Pepperoni Pizza', 'Cheeseburger Deluxe', 'Salmon Sushi', 'Beef Tacos', 'Chocolate Ice Cream', 'Spaghetti Bolognese', 'Dark Chocolate Bar', 'Caesar Salad', 'Club Sandwich', 'Crispy Fries', 'Ribeye Steak', 'Fried Chicken', 'Fried Rice', 'Chicken Soup', 'Chocolate Cake', 'Margherita Pizza', 'Veggie Burger', 'Tuna Roll']
      : ['Wood-Fired Neapolitan Pizza', 'Wagyu Beef Cheeseburger', 'Omakase Nigiri Sushi', 'Carne Asada Street Tacos', 'Artisan Gelato Flavors', 'Homemade Pappardelle Pasta', 'Belgian Dark Chocolate Truffle', 'Authentic Caesar Salad Dressing', 'Triple-Decker Club Sandwich', 'Belgian Frites Mayo', 'Dry-Aged Prime Ribeye', 'Nashville Hot Fried Chicken', 'Thai Pineapple Fried Rice', 'French Onion Soup Gratinée', 'Black Forest Chocolate Cake', 'San Marzano Tomato Sauce', 'Beyond Meat Impossible Burger', 'Fatty Tuna Toro Sashimi', 'Molecular Gastronomy Spheres', 'Sous Vide Egg Yolk'];
  } else if (topicLower.includes('animal') || topicLower.includes('pet')) {
    category = 'animals';
    cards = difficulty === 'easy'
      ? ['Dog', 'Cat', 'Lion', 'Elephant', 'Giraffe', 'Monkey', 'Tiger', 'Bear', 'Penguin', 'Dolphin', 'Horse', 'Rabbit', 'Snake', 'Eagle', 'Butterfly']
      : difficulty === 'medium'
      ? ['Golden Retriever', 'Siamese Cat', 'African Lion', 'African Elephant', 'Tall Giraffe', 'Spider Monkey', 'Bengal Tiger', 'Grizzly Bear', 'Emperor Penguin', 'Bottlenose Dolphin', 'Arabian Horse', 'Cottontail Rabbit', 'Python Snake', 'Bald Eagle', 'Monarch Butterfly', 'German Shepherd', 'Persian Cat', 'Zebra Stripes']
      : ['Golden Retriever Service Dog', 'Blue-Eyed Siamese Cat', 'African Savanna Lion Pride', 'Endangered African Elephant Tusks', 'Tallest Giraffe Neck Stretch', 'Capuchin Spider Monkey Climbing', 'Endangered Bengal Tiger Stripes', 'Alaskan Grizzly Bear Fishing', 'Emperor Penguin Egg Huddle', 'Wild Bottlenose Dolphin Pod', 'Purebred Arabian Horse Gallop', 'Eastern Cottontail Rabbit Burrow', 'Burmese Python Snake Constrictor', 'American Bald Eagle Soaring', 'Migrating Monarch Butterfly Mexico', 'Police K9 German Shepherd', 'Show Cat Persian Grooming', 'Zebra Black White Stripes', 'Koala Eucalyptus Tree Sleep', 'Red Panda Bamboo Eating'];
  } else {
    // Generic cards based on difficulty
    const count = diffConfig.cardCount;
    cards = Array.from({ length: count }, (_, i) => {
      if (difficulty === 'easy') return `${topic} ${i + 1}`;
      if (difficulty === 'medium') return `${topic} Item ${i + 1}`;
      return `${topic} Detailed Item ${i + 1}`;
    });
  }

  // Adjust to exact card count
  cards = cards.slice(0, diffConfig.cardCount);

  return {
    name: `${topic} ${difficulty === 'easy' ? 'Easy' : difficulty === 'hard' ? 'Hard' : ''}`,
    description: `A ${difficulty} difficulty collection about ${topic}`,
    cards,
    suggestedTags: [topic.toLowerCase(), difficulty, 'custom'],
    country: 'UNIVERSAL',
    difficulty,
    baseTopic: topic,
    colorSuggestion: categoryColors[category],
    iconSuggestion: categoryIcons[category],
    freshDataMeta: { usedFreshData: false },
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
    const openai = getOpenAIClient();

    const prompt = `Given a Heads Up! deck called "${deckName}" with these existing cards:
${existingCards.slice(0, 10).join(', ')}${existingCards.length > 10 ? ', ...' : ''}

Generate ${count} additional cards that fit the same theme and style.
Return only a JSON array of strings, no other text.`;

    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-5.1', // Latest flagship model
        max_completion_tokens: 1000,
        temperature: 0.8,
        messages: [
          { role: 'user', content: prompt }
        ]
      });
    });

    const textContent = response.choices[0]?.message?.content?.trim();

    if (!textContent) {
      throw new Error('No text content in OpenAI response');
    }

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
    getOpenAIClient();
    return true;
  } catch {
    return false;
  }
};
