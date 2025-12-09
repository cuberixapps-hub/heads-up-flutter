import { getOpenAIClient, handleAIError, withRetry } from './aiConfig';
import type { Country } from '../data/countries';

export interface AIGeneratedTopic {
  name: string;
  category: string;
  tags: string[];
  trendingReason: string; // Why this topic is hot right now
  culturalRelevance: string; // Why it matters for the country
  isPremium?: boolean;
  viralScore?: number; // 1-10 how viral/engaging this topic is
}

/**
 * Generate trending and interesting topics for a specific country using AI
 * OPTIMIZED FOR GEN Z - viral, trendy, social media aware content
 * @param country The country to generate topics for
 * @param count Number of topics to generate (default: 5)
 * @returns Promise<AIGeneratedTopic[]> Array of AI-generated trending topics
 */
export const generateTrendingTopics = async (
  country: Country,
  count: number = 5
): Promise<AIGeneratedTopic[]> => {
  try {
    const openai = getOpenAIClient();
    
    const systemPrompt = `You are a DIVERSE ENTERTAINMENT EXPERT who creates engaging deck topics across ALL categories.

YOUR MISSION: Create FUN, RECOGNIZABLE deck topics that people will LOVE to play.

🎯 MANDATORY CATEGORY DIVERSITY - Cover these areas:
- Movies & TV Shows (Bollywood, Hollywood, Netflix, K-drama)
- Sports (Cricket, Football, NBA, IPL)
- Music (Bollywood Songs, K-Pop, Hip-Hop, Regional Music)
- Gaming (Video Games, Gaming Characters, eSports)
- Food (Street Food, Restaurants, Regional Cuisines)
- Celebrities (Actors, Athletes, Musicians, YouTubers)
- Culture (Festivals, Traditions, Memes)
- Tech & Brands

Return ONLY valid JSON, no additional text.`;
    
    const userPrompt = `Generate ${count} DIVERSE deck topics for Heads Up! game for ${country.name} (${country.flag}).

⚠️ CRITICAL: Generate DIVERSE topics - NOT just internet/viral/meme content!

📋 EXCELLENT DIVERSE TOPICS BY CATEGORY:

🎬 MOVIES & TV:
- "Bollywood Superstars" - Shah Rukh Khan, Salman, Deepika
- "Netflix Originals Everyone Binged" - Squid Game, Stranger Things
- "Marvel Superheroes" - Iron Man, Spider-Man, Thor
- "Indian Web Series" - Mirzapur, Sacred Games, Panchayat

🏏 SPORTS:
- "Cricket Legends" - Sachin, Dhoni, Virat, Rohit
- "IPL Teams & Players" - CSK, MI, RCB stars
- "Football Icons" - Messi, Ronaldo, Neymar
- "NBA Superstars" - LeBron, Curry, Jordan

🎵 MUSIC:
- "Bollywood Hit Songs" - Iconic movie songs
- "K-Pop Groups" - BTS, BLACKPINK, NewJeans
- "Punjabi Music Stars" - Diljit, AP Dhillon
- "Global Pop Stars" - Taylor Swift, Ed Sheeran

🎮 GAMING:
- "Video Game Characters" - Mario, Sonic, Master Chief
- "Fortnite & Minecraft" - Popular game content
- "Gaming YouTubers" - PewDiePie, MrBeast Gaming

🍕 FOOD:
- "Indian Street Food" - Pani Puri, Vada Pav, Chole Bhature
- "Fast Food Chains" - McDonald's, KFC, Domino's
- "Regional Cuisines" - South Indian, Punjabi foods

🎉 CULTURE:
- "Indian Festivals" - Diwali, Holi, Eid, Navratri
- "Bollywood Dialogues" - Famous movie lines
- "Indian Memes" - Viral meme templates
- "Regional Cinema Stars" - Telugu, Tamil actors

❌ DO NOT GENERATE:
- Only internet/viral/meme topics
- Only "Viral Reels" or "Trending Online" content
- Generic categories without specificity

📊 REQUIRED JSON FORMAT:
[
  {
    "name": "Clear Topic Name (3-5 words)",
    "category": "bollywood|cricket|gaming|streaming|music|food|sports|anime|kpop|festivals|celebrities|tech",
    "tags": ["4-5 specific tags"],
    "trendingReason": "Why people love this topic (2 sentences)",
    "culturalRelevance": "Why ${country.name} specifically loves this (1-2 sentences)",
    "isPremium": false,
    "viralScore": 9
  }
]

Generate ${count} DIVERSE topics covering DIFFERENT categories!`;

    console.log(`Generating ${count} trending topics for ${country.name}...`);
    
    // Call OpenAI API with retry logic
    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-5.1', // Latest flagship model - best quality
        max_completion_tokens: 3000,
        temperature: 0.9, // Higher temperature for more creative/diverse topics
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
    let parsedTopics: AIGeneratedTopic[];
    try {
      // Clean the response in case it has markdown code blocks
      const jsonStr = textContent.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      parsedTopics = JSON.parse(jsonStr);
    } catch (parseError) {
      console.error('Failed to parse Claude response:', textContent);
      throw new Error('Invalid JSON response from AI');
    }
    
    // Validate response
    if (!Array.isArray(parsedTopics) || parsedTopics.length === 0) {
      throw new Error('Invalid topics array from AI');
    }
    
    // Ensure all required fields are present
    const validTopics = parsedTopics.filter(topic => 
      topic.name && 
      topic.category && 
      topic.tags && 
      Array.isArray(topic.tags) &&
      topic.trendingReason &&
      topic.culturalRelevance
    ).slice(0, count);
    
    if (validTopics.length === 0) {
      throw new Error('No valid topics generated');
    }
    
    console.log(`✅ Generated ${validTopics.length} trending topics for ${country.name}`);
    validTopics.forEach(topic => {
      console.log(`  - ${topic.name} (${topic.category}): ${topic.trendingReason}`);
    });
    
    return validTopics;
    
  } catch (error: any) {
    console.error('Topic generation error:', error);
    
    // Handle specific AI errors
    const aiError = handleAIError(error);
    
    throw aiError;
  }
};

/**
 * Generate a single random trending topic for a country
 * @param country The country to generate a topic for
 * @returns Promise<AIGeneratedTopic> A single AI-generated trending topic
 */
export const generateRandomTrendingTopic = async (
  country: Country
): Promise<AIGeneratedTopic> => {
  const topics = await generateTrendingTopics(country, 1);
  return topics[0];
};

/**
 * Generate trending topics for multiple countries
 * @param countries Array of countries
 * @param topicsPerCountry Number of topics per country
 * @returns Promise<Map<string, AIGeneratedTopic[]>> Map of country code to topics
 */
export const generateTopicsForMultipleCountries = async (
  countries: Country[],
  topicsPerCountry: number = 3
): Promise<Map<string, AIGeneratedTopic[]>> => {
  const topicsMap = new Map<string, AIGeneratedTopic[]>();
  
  // Generate topics for each country
  for (const country of countries) {
    try {
      const topics = await generateTrendingTopics(country, topicsPerCountry);
      topicsMap.set(country.code, topics);
      
      // Add delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 1000));
    } catch (error) {
      console.error(`Failed to generate topics for ${country.name}:`, error);
      // Continue with other countries
    }
  }
  
  return topicsMap;
};

/**
 * Generate a universal topic that works across all countries
 * OPTIMIZED FOR GEN Z WORLDWIDE - viral, trendy, globally recognizable
 * @returns Promise<AIGeneratedTopic> A universal trending topic
 */
export const generateUniversalTopic = async (): Promise<AIGeneratedTopic> => {
  try {
    const openai = getOpenAIClient();
    
    const systemPrompt = `You are a GLOBAL ENTERTAINMENT EXPERT creating universally fun deck topics.

YOUR MISSION: Create diverse, FUN topics that work EVERYWHERE in the world.
Cover ALL entertainment categories - NOT just internet/viral content!

🎯 DIVERSE UNIVERSAL CATEGORIES:
- Streaming & TV (Netflix, Disney+, global shows)
- Gaming (Video game characters, popular games)
- Movies (Marvel/DC, Disney/Pixar, Hollywood)
- Music (K-Pop, Global Pop Stars, Classic artists)
- Sports (Football/Soccer, Olympics)
- Food (Global chains, International cuisines)
- Tech (Brands, Apps, Products)
- Anime & Animation

Return ONLY valid JSON, no additional text.`;
    
    const userPrompt = `Generate 1 UNIVERSALLY FUN deck topic for Heads Up!

🌍 MUST work for players in ANY country (India, USA, UK, Japan, Brazil, etc.)

📋 EXCELLENT UNIVERSAL DECK IDEAS:

🎬 MOVIES & TV:
- "Netflix Originals Everyone Binged" - Squid Game, Stranger Things, Wednesday
- "Marvel Superheroes" - Iron Man, Spider-Man, Thor, Captain America
- "Disney/Pixar Characters" - Elsa, Woody, Simba, Nemo
- "Classic Movie Villains" - Thanos, Joker, Darth Vader

🎮 GAMING:
- "Video Game Characters" - Mario, Sonic, Master Chief
- "Pokemon Characters" - Pikachu, Charizard, Mewtwo
- "Gaming Icons" - Fortnite, Minecraft, GTA characters

🎵 MUSIC:
- "K-Pop Groups" - BTS, BLACKPINK, Stray Kids
- "Global Pop Stars" - Taylor Swift, Ed Sheeran, The Weeknd
- "90s/2000s Music Icons" - Classic artists everyone knows

📺 ANIME:
- "Anime Characters" - Naruto, Goku, Luffy, Tanjiro
- "Studio Ghibli Characters" - Totoro, Spirited Away

🍕 GLOBAL FOOD:
- "Fast Food Chains" - McDonald's, KFC, Starbucks
- "Global Snacks" - Oreos, Pringles, Kit-Kat

⚽ SPORTS:
- "Football/Soccer Legends" - Messi, Ronaldo, Neymar

📊 REQUIRED JSON FORMAT:
{
  "name": "Clear Topic Name (3-5 words)",
  "category": "streaming|gaming|music|anime|movies|sports|food|tech|kpop|superheroes",
  "tags": ["4-5 globally recognized tags"],
  "trendingReason": "Why people everywhere love this (2 sentences)",
  "culturalRelevance": "Why this works globally (1-2 sentences)",
  "isPremium": false,
  "viralScore": 9
}

Generate a topic that would be fun in ANY country!`;

    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-5.1', // Latest flagship model - best quality
        max_completion_tokens: 2000,
        temperature: 0.9,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ]
      });
    });
    
    const textContent = response.choices[0]?.message?.content?.trim();
    
    if (!textContent) {
      throw new Error('No text content in OpenAI response');
    }
    
    const jsonStr = textContent.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    const topic = JSON.parse(jsonStr);
    
    return topic;
    
  } catch (error) {
    console.error('Universal topic generation error:', error);
    throw handleAIError(error);
  }
};

/**
 * Check if topic generation is available
 */
export const isTopicGenerationAvailable = (): boolean => {
  try {
    getOpenAIClient();
    return true;
  } catch {
    return false;
  }
};

