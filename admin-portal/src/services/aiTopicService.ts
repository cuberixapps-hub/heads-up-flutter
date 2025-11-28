import { getOpenAIClient, handleAIError, withRetry } from './aiConfig';
import type { Country } from '../data/countries';

export interface AIGeneratedTopic {
  name: string;
  category: string;
  tags: string[];
  trendingReason: string; // Why this topic is hot right now
  culturalRelevance: string; // Why it matters for the country
  isPremium?: boolean;
}

/**
 * Generate trending and interesting topics for a specific country using AI
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
    
    const systemPrompt = `You are an expert cultural trends analyst and game designer specializing in viral, engaging content. 
Your mission is to create AMAZING, VIRAL-WORTHY topics that players will absolutely love - topics that are specific, 
creative, and irresistibly fun. You understand what makes content trend and what resonates with different cultures.
Return your response as valid JSON only, with no additional text.`;
    
    const userPrompt = `Generate ${count} AMAZING, VIRAL-WORTHY topics for Heads Up! game decks for ${country.name} (${country.flag} ${country.region}).

🎯 WHAT MAKES AN AMAZING TOPIC:

✅ GOOD TOPICS (Be like these):
- "2024 Grammy Winners" - Specific, timely, current
- "Viral TikTok Dance Challenges" - Trending, fun, recognizable
- "Marvel Phase 5 Characters" - Specific niche within popular category
- "Bollywood Dance Numbers 2024" - Cultural + current + specific
- "Netflix Top 10 Binge Shows" - Specific angle on broad category

❌ BAD TOPICS (Avoid these):
- "Movies" - Too generic, boring, overdone
- "Food" - Too broad, not interesting
- "Famous People" - Vague, unoriginal
- "Sports" - Not specific enough
- "Random Things" - Lazy, no focus

🔥 CREATIVITY GUIDELINES:
- Find unique angles on popular themes
- Combine trending + cultural + specific
- Think "What would go VIRAL on social media?"
- Focus on what people are OBSESSED with RIGHT NOW
- Make it fun to guess and act out!

📱 TRENDING ANALYSIS for ${country.name}:
Consider what's HOT in ${country.name} RIGHT NOW:
- Viral social media trends, challenges, memes
- Latest blockbuster movies, hit shows, chart-topping music
- Current sports events, celebrity news, gaming phenomena
- Local festivals, cultural moments, seasonal events
- What's dominating conversations in ${country.region}

🎮 PLAYABILITY CHECK:
- Can players act it out or describe it?
- Are the items recognizable to the audience?
- Will it be FUN in a fast-paced game?
- Does it have enough variety for 15-20 cards?

Return ONLY a JSON array with this structure:
[
  {
    "name": "Catchy, specific topic name (3-5 words, be creative!)",
    "category": "movies|food|music|sports|celebrities|travel|games|tech|culture",
    "tags": ["3-5 relevant, specific tags"],
    "trendingReason": "Compelling explanation of why this is HOT right now (1-2 sentences, be specific!)",
    "culturalRelevance": "Why this resonates deeply with ${country.name} culture (1-2 sentences)",
    "isPremium": false
  }
]

🌟 QUALITY STANDARDS:
- Each topic must score 70+ on quality (creativity, trend, cultural, playability)
- Aim for 90+ scores with specificity and creativity
- Think viral, think exciting, think AMAZING!
- Make every topic something players will get HYPED about!

Generate ${count} unique, OUTSTANDING topics as a JSON array. Make them INCREDIBLE!`;

    console.log(`Generating ${count} trending topics for ${country.name}...`);
    
    // Call OpenAI API with retry logic
    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-4o', // Using GPT-4o for best quality
        max_tokens: 3000,
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
 * @returns Promise<AIGeneratedTopic> A universal trending topic
 */
export const generateUniversalTopic = async (): Promise<AIGeneratedTopic> => {
  try {
    const openai = getOpenAIClient();
    
    const systemPrompt = `You are a global trends expert and viral content specialist.
Create AMAZING, UNIVERSALLY VIRAL topics that work across all cultures and countries.
Think global phenomena, worldwide obsessions, and content that breaks cultural barriers.
Return your response as valid JSON only, with no additional text.`;
    
    const userPrompt = `Generate 1 OUTSTANDING universal topic for a Heads Up! game deck that appeals to people WORLDWIDE.

🌍 UNIVERSAL TOPIC GUIDELINES:

✅ EXCELLENT UNIVERSAL TOPICS:
- "2024 Olympics Viral Moments" - Global event, specific, timely
- "Worldwide Netflix Hits" - Universal platform, current
- "Iconic Disney Characters" - Recognizable everywhere
- "Global Climate Heroes" - Universal concern, inspiring
- "Social Media Viral Challenges" - Cross-cultural, trending

❌ AVOID:
- Country-specific references
- Regional celebrities unknown elsewhere
- Cultural practices unfamiliar globally
- Language-specific humor

🔥 GLOBAL TRENDING ANALYSIS:
What's VIRAL worldwide RIGHT NOW:
- International streaming sensations (Netflix, Disney+, etc.)
- Global sports events and superstars
- Worldwide social media phenomena
- Universal human experiences and emotions
- Cross-cultural music and entertainment hits
- Global brands and tech innovations
- Worldwide environmental/social movements

🎯 CRITERIA:
- Recognizable in New York, Tokyo, Mumbai, London, São Paulo
- Transcends language and cultural barriers
- Current and trending globally
- Fun to play for any audience
- Family-friendly worldwide

Return ONLY a JSON object with this structure:
{
  "name": "Catchy, specific universal topic (3-5 words)",
  "category": "movies|food|music|sports|celebrities|travel|games|tech|culture",
  "tags": ["3-5 globally relevant tags"],
  "trendingReason": "Why this is HOT worldwide right now (1-2 sentences, be specific about global appeal)",
  "culturalRelevance": "Why this resonates across ALL cultures (1-2 sentences)",
  "isPremium": false
}

Make it AMAZING - something that would trend GLOBALLY!`;

    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-4o', // Using GPT-4o for best quality
        max_tokens: 2000,
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

