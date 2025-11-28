import { getOpenAIClient, handleAIError, withRetry } from './aiConfig';
import type { Country } from '../data/countries';

export interface ResearchedTopic {
  // Basic Info
  name: string;
  category: string;
  tags: string[];
  isPremium?: boolean;
  
  // Deep Research & Reasoning
  trendingReason: string; // Why it's hot NOW (specific data/trends)
  culturalRelevance: string; // Why it matters for the country
  targetAudience: 'teens' | 'adults' | 'families' | 'universal';
  audienceAppeal: string; // Why this audience will love it
  
  // Engagement Metrics
  viralPotential: number; // 1-10 score
  recognitionScore: number; // 1-10 score (how well-known)
  playabilityScore: number; // 1-10 score (how fun to act out)
  
  // Supporting Evidence
  trendingData: {
    source: string; // e.g., "2024 Box Office", "Social Media Trends"
    evidence: string; // Specific data point or stat
    timeframe: string; // e.g., "2024", "November 2024"
  }[];
  
  // Examples that make it clear
  exampleCards: string[]; // 3-5 example cards that would be in the deck
  
  // Deck Quality Justification
  whyItWorks: string; // Comprehensive explanation of why this deck will be AMAZING
}

/**
 * Generate deeply researched, engaging topics with proper reasoning
 * This is the PREMIUM topic generator that creates viral-worthy decks
 */
export const generateResearchedTopics = async (
  country: Country,
  count: number = 3,
  targetAudience?: 'teens' | 'adults' | 'families'
): Promise<ResearchedTopic[]> => {
  try {
    const openai = getOpenAIClient();
    
    const audienceContext = targetAudience 
      ? `\n\n🎯 TARGET AUDIENCE: ${targetAudience.toUpperCase()}
${targetAudience === 'teens' ? `
- Ages 13-19, deeply immersed in social media (TikTok, Instagram, YouTube)
- Follow viral trends, memes, and internet celebrities
- Love: K-pop, gaming, YouTube stars, viral challenges, current music
- References should be 2022-2024 (nothing older unless it's making a comeback)
- Gen Z humor and sensibilities
` : targetAudience === 'adults' ? `
- Ages 25-45, mix of nostalgia and current trends
- Follow mainstream entertainment, streaming hits, popular culture
- Love: 90s/2000s nostalgia, blockbuster movies, popular TV series, classic references
- Balance between throwback and current content
- Appreciate quality entertainment and recognizable names
` : `
- Mixed ages (kids, parents, grandparents playing together)
- Need universally recognizable, wholesome references
- Love: Disney/Pixar, classic movies, animals, simple categories
- Nothing too niche or adult-oriented
- References should span generations (kid-friendly but parents recognize too)
`}` 
      : '\n\n🎯 TARGET AUDIENCE: Universal (all ages and demographics)';
    
    const systemPrompt = `You are a PREMIUM cultural trends analyst, entertainment researcher, and viral content expert.

Your mission: Create EXCEPTIONAL, VIRAL-WORTHY Heads Up! deck ideas that are:
✅ Backed by REAL research, trends, and data
✅ Deeply engaging for the target audience
✅ Culturally relevant and resonant
✅ Specific and creative (NOT generic)
✅ Fun and playable in the game

You understand:
- What's trending on social media RIGHT NOW
- Box office hits, streaming sensations, chart-topping music
- Cultural moments, viral phenomena, and zeitgeist
- What makes content go VIRAL
- What different age groups love and talk about

Return ONLY valid JSON, no additional text.`;

    const userPrompt = `Generate ${count} EXCEPTIONAL, WELL-RESEARCHED deck ideas for Heads Up! game.

🌍 COUNTRY: ${country.flag} ${country.name} (${country.region})
${audienceContext}

📊 RESEARCH METHODOLOGY:

You must provide PROPER REASONING for each deck idea, including:

1. **Trending Analysis**: What's HOT in ${country.name} RIGHT NOW
   - Current box office hits, streaming trends, music charts
   - Viral social media phenomena (TikTok, Instagram, YouTube)
   - Sports events, celebrity news, cultural moments
   - Gaming trends, tech innovations, lifestyle trends

2. **Cultural Relevance**: Why it resonates in ${country.name}
   - Local celebrities, entertainment, cultural phenomena
   - Regional preferences and passions
   - Cultural values and interests

3. **Audience Appeal**: Why the target audience will LOVE it
   - What makes it engaging for this specific age group
   - Why they'll get excited about this topic
   - Social/viral potential

4. **Data & Evidence**: Back it up with specifics
   - Box office numbers, streaming stats, chart positions
   - Social media engagement, viral metrics
   - Cultural impact, news coverage, search trends

5. **Playability**: Why it works for Heads Up!
   - Easy to act out and describe
   - Recognizable items/references
   - Fun and engaging gameplay
   - Variety of cards possible

🎯 QUALITY STANDARDS:

✅ GOOD TOPICS (Be like these):
- "2024 Grammy Winners & Nominees" 
  WHY: Specific, timely, current events
- "Viral TikTok Dance Challenges 2024"
  WHY: Social media trending, fun to act out
- "Marvel Phase 5 Characters"
  WHY: Specific niche within massive popular franchise
- "Bollywood Blockbusters 2024" (for India)
  WHY: Culturally specific, current, huge appeal
- "Netflix Top 10 Binge Shows"
  WHY: Specific angle on broad category, everyone's watching

❌ BAD TOPICS (Avoid these):
- "Movies" - Too generic, boring, overdone
- "Famous People" - Vague, no angle
- "Sports" - Not specific enough
- "Food" - Too broad

🔥 CREATIVE REQUIREMENTS:
- Find UNIQUE angles on popular themes
- Combine: Trending + Cultural + Specific
- Think "What would go VIRAL?"
- Must be fun to guess and act out
- Should spark excitement and recognition

📋 RESPONSE FORMAT:

Return a JSON array of ${count} researched topics:

[
  {
    "name": "Specific, catchy topic name (3-5 words)",
    "category": "movies|food|music|sports|celebrities|travel|games|tech|culture",
    "tags": ["3-5 specific tags"],
    "isPremium": false,
    
    "trendingReason": "Detailed explanation with SPECIFIC data/trends (2-3 sentences, be SPECIFIC!)",
    "culturalRelevance": "Why this deeply resonates with ${country.name} culture (2-3 sentences)",
    "targetAudience": "${targetAudience || 'universal'}",
    "audienceAppeal": "Why ${targetAudience || 'everyone'} will absolutely LOVE this (2-3 sentences)",
    
    "viralPotential": 8,
    "recognitionScore": 9,
    "playabilityScore": 8,
    
    "trendingData": [
      {
        "source": "Specific source (e.g., '2024 Box Office', 'Billboard Charts Nov 2024')",
        "evidence": "Specific data point (e.g., 'grossed $1.5B worldwide', 'viral with 500M views')",
        "timeframe": "2024 or specific date"
      }
    ],
    
    "exampleCards": [
      "Specific example 1",
      "Specific example 2", 
      "Specific example 3"
    ],
    
    "whyItWorks": "Comprehensive 3-4 sentence explanation of why this deck is AMAZING. Include: trending appeal + cultural fit + audience match + playability + viral potential. Make it compelling!"
  }
]

🌟 SCORE TARGETS:
- Viral Potential: 7-10 (will people talk about this?)
- Recognition Score: 7-10 (will the audience know these items?)
- Playability Score: 7-10 (fun to act out?)

Generate ${count} OUTSTANDING, well-researched topics with PROPER REASONING!`;

    console.log(`Generating ${count} researched topics for ${country.name}${targetAudience ? ` (${targetAudience})` : ''}...`);
    
    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-4o', // Premium model for quality research
        max_tokens: 4000, // More tokens for detailed research
        temperature: 0.85, // Balanced creativity and coherence
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
    
    // Parse JSON response
    let parsedTopics: ResearchedTopic[];
    try {
      const jsonStr = textContent.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      parsedTopics = JSON.parse(jsonStr);
    } catch (parseError) {
      console.error('Failed to parse OpenAI response:', textContent);
      throw new Error('Invalid JSON response from AI');
    }
    
    // Validate response
    if (!Array.isArray(parsedTopics) || parsedTopics.length === 0) {
      throw new Error('Invalid topics array from AI');
    }
    
    // Ensure all required fields are present
    const validTopics = parsedTopics.filter(topic => 
      topic.name && 
      topic.trendingReason &&
      topic.culturalRelevance &&
      topic.whyItWorks &&
      topic.exampleCards &&
      Array.isArray(topic.exampleCards) &&
      topic.trendingData &&
      Array.isArray(topic.trendingData)
    ).slice(0, count);
    
    if (validTopics.length === 0) {
      throw new Error('No valid researched topics generated');
    }
    
    console.log(`✅ Generated ${validTopics.length} researched topics for ${country.name}`);
    validTopics.forEach(topic => {
      console.log(`  🔥 ${topic.name}`);
      console.log(`     Viral: ${topic.viralPotential}/10 | Recognition: ${topic.recognitionScore}/10 | Playability: ${topic.playabilityScore}/10`);
      console.log(`     Why it works: ${topic.whyItWorks.substring(0, 100)}...`);
    });
    
    return validTopics;
    
  } catch (error: any) {
    console.error('Researched topic generation error:', error);
    throw handleAIError(error);
  }
};

/**
 * Generate a single researched topic
 */
export const generateSingleResearchedTopic = async (
  country: Country,
  targetAudience?: 'teens' | 'adults' | 'families'
): Promise<ResearchedTopic> => {
  const topics = await generateResearchedTopics(country, 1, targetAudience);
  return topics[0];
};

/**
 * Generate a universal researched topic (works across all countries)
 */
export const generateUniversalResearchedTopic = async (
  targetAudience?: 'teens' | 'adults' | 'families'
): Promise<ResearchedTopic> => {
  try {
    const openai = getOpenAIClient();
    
    const audienceContext = targetAudience 
      ? `\n\n🎯 TARGET AUDIENCE: ${targetAudience.toUpperCase()}`
      : '\n\n🎯 TARGET AUDIENCE: Universal (all ages, all countries)';
    
    const systemPrompt = `You are a GLOBAL trends expert and viral content specialist.
Create EXCEPTIONAL, UNIVERSALLY VIRAL deck ideas with proper research and reasoning.
Think global phenomena, worldwide obsessions, content that breaks cultural barriers.
Return ONLY valid JSON, no additional text.`;

    const userPrompt = `Generate 1 OUTSTANDING universal deck idea for Heads Up! that works WORLDWIDE.

🌍 UNIVERSAL CRITERIA:
- Recognizable in New York, Tokyo, Mumbai, London, São Paulo, Sydney
- Transcends language and cultural barriers  
- Currently trending GLOBALLY
- Family-friendly worldwide
${audienceContext}

🌐 GLOBAL TRENDING ANALYSIS:

What's VIRAL worldwide RIGHT NOW:
- International streaming sensations (Netflix, Disney+, Apple TV+)
- Global sports events and superstars (Olympics, World Cup, etc.)
- Worldwide social media phenomena (TikTok trends that cross borders)
- Universal human experiences and emotions
- Cross-cultural music hits (artists with global fanbase)
- Global brands and tech innovations
- Worldwide movements and cultural moments

📊 PROVIDE PROPER RESEARCH:
- Global box office numbers, streaming stats
- Worldwide social media engagement
- International chart positions
- Cross-cultural appeal evidence
- Why it works in multiple regions

Return a JSON object with this structure:
{
  "name": "Specific universal topic (3-5 words)",
  "category": "movies|food|music|sports|celebrities|travel|games|tech|culture",
  "tags": ["3-5 globally relevant tags"],
  "isPremium": false,
  
  "trendingReason": "Why this is HOT worldwide RIGHT NOW (2-3 sentences, SPECIFIC data)",
  "culturalRelevance": "Why this resonates across ALL cultures (2-3 sentences)",
  "targetAudience": "${targetAudience || 'universal'}",
  "audienceAppeal": "Why ${targetAudience || 'everyone globally'} will love this (2-3 sentences)",
  
  "viralPotential": 9,
  "recognitionScore": 9,
  "playabilityScore": 8,
  
  "trendingData": [
    {
      "source": "Global Box Office 2024",
      "evidence": "Specific worldwide data",
      "timeframe": "2024"
    }
  ],
  
  "exampleCards": [
    "Example that works globally 1",
    "Example that works globally 2",
    "Example that works globally 3"
  ],
  
  "whyItWorks": "Comprehensive explanation of why this deck is GLOBALLY AMAZING (3-4 sentences)"
}

Make it EXCEPTIONAL with PROPER REASONING!`;

    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-4o',
        max_tokens: 3000,
        temperature: 0.85,
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
    
    console.log(`✅ Generated universal researched topic: ${topic.name}`);
    console.log(`   Viral: ${topic.viralPotential}/10 | Recognition: ${topic.recognitionScore}/10`);
    
    return topic;
    
  } catch (error) {
    console.error('Universal researched topic generation error:', error);
    throw handleAIError(error);
  }
};

/**
 * Check if researched topic generation is available
 */
export const isResearchedTopicGenerationAvailable = (): boolean => {
  try {
    getOpenAIClient();
    return true;
  } catch {
    return false;
  }
};




