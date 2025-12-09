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
  
  // Engagement Metrics (STRICT: 8-10 only for Gen Z appeal)
  viralPotential: number; // 8-10 score (must be shareable)
  recognitionScore: number; // 8-10 score (instant recognition)
  playabilityScore: number; // 8-10 score (fun charades potential)
  
  // Supporting Evidence
  trendingData: {
    source: string; // e.g., "Social Media Trending", "Netflix Top 10", "Gaming Charts"
    evidence: string; // Specific data point or stat
    timeframe: string; // e.g., "2024", "November 2024"
  }[];
  
  // Examples that make it clear
  exampleCards: string[]; // 3-5 example cards that would be in the deck
  
  // Deck Quality Justification
  whyItWorks: string; // Comprehensive explanation of why this deck will be AMAZING
  
  // Gen Z specific
  vibeCheck: string; // Quick Gen Z language summary of why this slaps
}

/**
 * DIVERSE CATEGORY SYSTEM - Ensures variety in deck generation
 * Each country has specific relevant categories
 */
const CATEGORY_DIVERSITY = {
  // Universal categories that work everywhere
  universal: [
    'streaming_shows', 'gaming', 'anime', 'music_global', 'movies', 
    'tech_brands', 'youtubers', 'memes', 'esports', 'superheroes'
  ],
  
  // Country-specific category mappings
  countryCategories: {
    'IN': ['bollywood', 'cricket', 'indian_web_series', 'regional_cinema', 'indian_food', 'indian_festivals', 'ipl', 'indian_music'],
    'US': ['nfl_nba', 'hollywood', 'american_music', 'fast_food', 'reality_tv', 'broadway', 'us_politics'],
    'GB': ['premier_league', 'british_tv', 'british_music', 'british_food', 'royal_family'],
    'JP': ['anime', 'manga', 'jpop', 'japanese_games', 'japanese_food', 'nintendo'],
    'KR': ['kdrama', 'kpop', 'korean_food', 'kbeauty', 'korean_variety', 'korean_esports'],
    'BR': ['brazilian_football', 'telenovela', 'brazilian_music', 'carnival', 'brazilian_food'],
    'CA': ['hockey', 'canadian_celebs', 'canadian_food', 'canadian_tv'],
    'AU': ['australian_sports', 'australian_celebs', 'australian_food', 'australian_wildlife'],
    'MX': ['reggaeton', 'mexican_food', 'mexican_football', 'telenovelas', 'luchadores'],
    'CN': ['cdrama', 'cpop', 'chinese_food', 'chinese_tech', 'chinese_mythology'],
  } as Record<string, string[]>
};

/**
 * Get a random category to ensure diversity
 */
const getRandomCategory = (countryCode: string): string => {
  const countrySpecific = CATEGORY_DIVERSITY.countryCategories[countryCode] || [];
  const allCategories = [...CATEGORY_DIVERSITY.universal, ...countrySpecific];
  return allCategories[Math.floor(Math.random() * allCategories.length)];
};

/**
 * Get country-specific topic examples for the prompt
 */
const getCountrySpecificExamples = (countryCode: string, countryName: string): string => {
  const examples: Record<string, string> = {
    'IN': `
🇮🇳 INDIA-SPECIFIC DECK IDEAS:
- "Bollywood Superstars" - Shah Rukh Khan, Salman Khan, Deepika, Alia
- "Cricket Legends" - Sachin, Dhoni, Virat, Rohit Sharma
- "Indian Web Series" - Mirzapur, Sacred Games, Panchayat, TVF shows
- "IPL Teams & Players" - CSK, MI, RCB, player names
- "Bollywood Hit Songs" - Iconic movie songs everyone knows
- "Indian Street Food" - Pani Puri, Vada Pav, Chole Bhature
- "Indian Festivals" - Diwali, Holi, Eid, Navratri, Durga Puja
- "Regional Cinema Stars" - Telugu (Allu Arjun), Tamil (Vijay), Malayalam
- "Bollywood Dialogues" - Famous movie lines
- "Indian Memes" - Viral Indian meme templates
- "Punjabi Music Artists" - Diljit, AP Dhillon, Sidhu Moosewala
- "Indian Reality TV" - Bigg Boss, KBC, Indian Idol`,

    'US': `
🇺🇸 USA-SPECIFIC DECK IDEAS:
- "NFL Legends" - Tom Brady, Patrick Mahomes, famous players
- "NBA Superstars" - LeBron, Curry, Jordan, Kobe
- "American Fast Food" - McDonald's, Chick-fil-A, In-N-Out
- "Reality TV Stars" - Kardashians, Bachelor, Real Housewives
- "Broadway Musicals" - Hamilton, Wicked, Les Mis
- "US Presidents" - Famous presidents past & present
- "American Sitcoms" - Friends, The Office, Seinfeld
- "Hip-Hop Legends" - Kanye, Drake, Kendrick, Jay-Z
- "Hollywood A-Listers" - DiCaprio, Dwayne Johnson, Jennifer Lawrence`,

    'GB': `
🇬🇧 UK-SPECIFIC DECK IDEAS:
- "Premier League Players" - Haaland, Salah, famous footballers
- "British TV Shows" - Doctor Who, Peaky Blinders, The Crown
- "British Slang" - British expressions and words
- "UK Music Artists" - Adele, Ed Sheeran, Dua Lipa, Harry Styles
- "British Food" - Fish & Chips, Sunday Roast, Full English
- "British Royals" - Royal family members
- "British Comedians" - James Corden, Ricky Gervais`,

    'JP': `
🇯🇵 JAPAN-SPECIFIC DECK IDEAS:
- "Anime Characters" - Naruto, Goku, Luffy, Tanjiro
- "Manga Titles" - One Piece, Dragon Ball, Death Note
- "J-Pop Artists" - YOASOBI, Kenshi Yonezu, Ado
- "Japanese Video Games" - Mario, Pokemon, Final Fantasy
- "Japanese Food" - Sushi types, Ramen varieties, Wagashi
- "Nintendo Characters" - Mario, Link, Kirby, Pikachu
- "Studio Ghibli" - Spirited Away characters, Totoro`,

    'KR': `
🇰🇷 KOREA-SPECIFIC DECK IDEAS:
- "K-Drama Characters" - Popular K-drama leads
- "K-Pop Groups" - BTS, BLACKPINK, Stray Kids, NewJeans
- "Korean Street Food" - Tteokbokki, Kimbap, Korean BBQ
- "K-Beauty Brands" - Innisfree, Laneige, COSRX
- "Korean Variety Shows" - Running Man, Knowing Bros
- "Korean eSports" - Faker, Korean gaming legends`,

    'AU': `
🇦🇺 AUSTRALIA-SPECIFIC DECK IDEAS:
- "Australian Sports Stars" - Cricket, Rugby, Tennis stars
- "Australian Celebrities" - Hugh Jackman, Margot Robbie
- "Australian Food" - Vegemite, Meat Pie, Tim Tam
- "Australian Wildlife" - Kangaroo, Koala, unique animals
- "Australian Slang" - Aussie expressions`,

    'CA': `
🇨🇦 CANADA-SPECIFIC DECK IDEAS:
- "NHL Hockey Stars" - Gretzky, Crosby, McDavid
- "Canadian Celebrities" - Ryan Reynolds, Drake, The Weeknd
- "Canadian Food" - Poutine, Maple Syrup dishes
- "Canadian TV Shows" - Schitt's Creek, Letterkenny`,

    'BR': `
🇧🇷 BRAZIL-SPECIFIC DECK IDEAS:
- "Brazilian Football Legends" - Neymar, Ronaldo, Pelé
- "Telenovela Characters" - Famous soap opera stars
- "Brazilian Music" - Sertanejo, Funk artists
- "Carnival Culture" - Samba, Rio Carnival
- "Brazilian Food" - Feijoada, Açaí, Coxinha`,
  };

  return examples[countryCode] || `
🌍 ${countryName} DECK IDEAS:
- Famous celebrities from ${countryName}
- Popular sports in ${countryName}
- Traditional food from ${countryName}
- Cultural festivals of ${countryName}
- Music artists from ${countryName}
- TV shows popular in ${countryName}`;
};

/**
 * Generate deeply researched, engaging topics with proper reasoning
 * DIVERSE topic generator covering ALL entertainment categories
 */
export const generateResearchedTopics = async (
  country: Country,
  count: number = 3,
  targetAudience?: 'teens' | 'adults' | 'families'
): Promise<ResearchedTopic[]> => {
  try {
    const openai = getOpenAIClient();
    
    const effectiveAudience = targetAudience || 'teens';
    
    // Get a random suggested category to ensure diversity
    const suggestedCategory = getRandomCategory(country.code);
    
    // Build country-specific topic examples
    const countryExamples = getCountrySpecificExamples(country.code, country.name);
    
    const systemPrompt = `You are a DIVERSE ENTERTAINMENT EXPERT who creates engaging deck topics across ALL categories.

YOUR MISSION: Create FUN, RECOGNIZABLE deck topics that people will LOVE to play. Cover DIVERSE categories - NOT just internet/viral content!

🎯 MANDATORY CATEGORY DIVERSITY - You MUST cover different areas:

📺 ENTERTAINMENT:
- Movies (Hollywood, Bollywood, Regional Cinema)
- TV Shows (Netflix, Web Series, Reality TV)
- Streaming Content (Originals, Documentaries)

🏆 SPORTS:
- Cricket (for India/UK/Australia)
- Football/Soccer (Global)
- Basketball/NFL (USA)
- eSports & Gaming Tournaments

🎵 MUSIC:
- Bollywood Songs (India)
- K-Pop Groups & Songs
- Hip-Hop/Rap Artists
- Regional Music (Punjabi, Tamil, Telugu)
- Global Pop Stars

🎮 GAMING:
- Video Game Characters
- Game Titles (Fortnite, Minecraft, GTA, FIFA)
- Gaming YouTubers
- Retro Games

🍕 FOOD & CULTURE:
- Street Food (country-specific)
- Restaurants & Chains
- Festival Foods
- Comfort Foods

🎭 CELEBRITIES:
- Movie Stars (country-specific)
- Athletes
- Musicians
- YouTubers & Influencers

🎪 CULTURE & FESTIVALS:
- National Festivals
- Cultural Traditions
- Regional Specialties

⚡ TECH & BRANDS:
- Tech Companies
- Apps & Platforms
- Gadgets

Return ONLY valid JSON, no additional text.`;

    const userPrompt = `Generate ${count} DIVERSE deck ideas for Heads Up!

🌍 COUNTRY: ${country.flag} ${country.name}
🎯 AUDIENCE: ${effectiveAudience}
📂 SUGGESTED CATEGORY THIS TIME: ${suggestedCategory}

⚠️ CRITICAL: DO NOT generate only internet/viral/meme content!
⚠️ You MUST cover DIVERSE categories like the examples below!

${countryExamples}

🎯 CATEGORY TO FOCUS ON THIS TIME: ${suggestedCategory}
(But you can pick from ANY category - just ensure DIVERSITY!)

📋 GOOD DIVERSE EXAMPLES:

🎬 ENTERTAINMENT:
- "Bollywood Superstars" - Iconic actors everyone knows
- "Netflix Originals Everyone Binged" - Streaming hits
- "Marvel & DC Superheroes" - Comic book characters
- "Anime Characters" - Popular anime protagonists
- "K-Drama Lead Characters" - Korean drama stars

🏏 SPORTS:
- "Cricket Legends" - Famous cricketers past & present
- "IPL Teams & Players" - Indian Premier League
- "Football Icons" - Soccer/football stars
- "NBA Superstars" - Basketball greats
- "Olympic Champions" - Multi-sport athletes

🎵 MUSIC:
- "Bollywood Hit Songs" - Iconic movie songs
- "K-Pop Groups" - Korean pop bands
- "90s Music Icons" - Nostalgic artists
- "Punjabi Music Stars" - Regional music
- "Global Pop Stars" - International artists

🎮 GAMING:
- "Video Game Characters" - Mario, Sonic, etc.
- "Fortnite & Minecraft" - Popular games
- "Gaming YouTubers" - Content creators
- "Retro Games" - Classic video games

🍕 FOOD:
- "Indian Street Food" - Pani puri, vada pav, etc.
- "Fast Food Chains" - McDonald's, KFC, etc.
- "Regional Cuisines" - South Indian, Punjabi, etc.
- "Festival Foods" - Diwali sweets, etc.

🎉 CULTURE:
- "Indian Festivals" - Diwali, Holi, Eid, etc.
- "Bollywood Dialogues" - Famous movie lines
- "Indian Web Series" - Mirzapur, Sacred Games
- "Regional Cinema Stars" - Telugu, Tamil heroes

❌ DO NOT GENERATE:
- Only internet/viral/meme topics
- Only "Viral Reels" type content
- Generic "Internet Trends" topics
- Repetitive social media topics

📋 REQUIRED JSON FORMAT:

[
  {
    "name": "Specific Topic Name (3-5 words)",
    "category": "bollywood|cricket|gaming|streaming|music|food|sports|anime|kpop|festivals|celebrities|tech",
    "tags": ["5 relevant tags"],
    "isPremium": false,
    
    "trendingReason": "Why people love this topic - 2 sentences",
    "culturalRelevance": "Why it matters for ${country.name} specifically - 2 sentences",
    "targetAudience": "${effectiveAudience}",
    "audienceAppeal": "Why this audience will enjoy playing this - 2 sentences",
    
    "viralPotential": 8,
    "recognitionScore": 9,
    "playabilityScore": 9,
    
    "trendingData": [
      {
        "source": "Relevant source (Netflix, Gaming Charts, Box Office, etc.)",
        "evidence": "Specific popularity metric",
        "timeframe": "2024-2025"
      }
    ],
    
    "exampleCards": [
      "Specific example 1 everyone knows",
      "Specific example 2 everyone knows",
      "Specific example 3 everyone knows",
      "Specific example 4 everyone knows",
      "Specific example 5 everyone knows"
    ],
    
    "whyItWorks": "3-4 sentences explaining why this is fun to play and easy to guess",
    
    "vibeCheck": "One sentence summary of why this deck is great"
  }
]

Generate ${count} DIVERSE topics covering DIFFERENT categories!`;

    console.log(`Generating ${count} researched topics for ${country.name}${targetAudience ? ` (${targetAudience})` : ''}...`);
    
    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-5.1', // Latest flagship model - premium research
        max_completion_tokens: 4000, // More tokens for detailed research
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
    } catch {
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
    
  } catch (error) {
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
 * Get random universal category for diversity
 */
const getRandomUniversalCategory = (): string => {
  const categories = [
    'netflix_originals', 'gaming_icons', 'anime_characters', 'kpop_groups',
    'marvel_dc_heroes', 'global_music', 'youtubers_streamers', 'classic_movies',
    'video_game_characters', 'global_food_chains', 'tech_brands', 'sports_legends',
    'disney_pixar', 'internet_memes', 'esports_players', 'podcast_hosts'
  ];
  return categories[Math.floor(Math.random() * categories.length)];
};

/**
 * Generate a universal researched topic (works across all countries)
 * DIVERSE topics covering all entertainment categories
 */
export const generateUniversalResearchedTopic = async (
  targetAudience?: 'teens' | 'adults' | 'families'
): Promise<ResearchedTopic> => {
  try {
    const openai = getOpenAIClient();
    
    const effectiveAudience = targetAudience || 'teens';
    const suggestedCategory = getRandomUniversalCategory();
    
    const systemPrompt = `You are a GLOBAL ENTERTAINMENT EXPERT creating universally fun deck topics.

YOUR MISSION: Create diverse, FUN topics that work EVERYWHERE in the world.
Cover ALL entertainment categories - NOT just internet/viral content!

🎯 DIVERSE UNIVERSAL CATEGORIES TO COVER:

📺 STREAMING & TV:
- Netflix Originals (Squid Game, Stranger Things, Wednesday)
- Disney+ Shows (Mandalorian, Marvel series)
- Global TV phenomena

🎮 GAMING:
- Video Game Characters (Mario, Sonic, Master Chief)
- Gaming Icons (Fortnite, Minecraft, GTA)
- eSports Players
- Gaming YouTubers

🎬 MOVIES:
- Marvel/DC Superheroes
- Disney/Pixar Characters
- Hollywood Blockbusters
- Classic Movie Characters

🎵 MUSIC:
- K-Pop Groups & Idols
- Global Pop Stars
- Music Festival Artists
- 90s/2000s Music Icons

📱 TECH & INTERNET:
- Tech Brands & Products
- YouTubers & Streamers
- Internet Memes (global ones)
- AI & Tech Personalities

🏆 SPORTS:
- Football/Soccer Stars (global)
- Olympic Athletes
- Sports Legends

🍕 FOOD:
- Global Fast Food Chains
- International Cuisines
- Food Trends

Return ONLY valid JSON, no additional text.`;

    const userPrompt = `Generate 1 UNIVERSALLY FUN deck topic for Heads Up!

🌍 MUST work for players in ANY country (India, USA, UK, Japan, Brazil, etc.)
🎯 SUGGESTED CATEGORY: ${suggestedCategory}
👥 AUDIENCE: ${effectiveAudience}

⚠️ DO NOT generate only internet/viral/meme topics!
⚠️ Cover DIVERSE categories!

📋 EXCELLENT UNIVERSAL DECK IDEAS BY CATEGORY:

🎬 MOVIES & TV:
- "Netflix Originals Everyone Binged" - Squid Game, Stranger Things, Wednesday
- "Marvel Superheroes" - Iron Man, Spider-Man, Thor, Captain America
- "DC Superheroes" - Batman, Superman, Wonder Woman, Aquaman
- "Disney/Pixar Characters" - Elsa, Woody, Simba, Nemo
- "Classic Movie Villains" - Thanos, Joker, Darth Vader

🎮 GAMING:
- "Video Game Characters" - Mario, Sonic, Master Chief, Lara Croft
- "Gaming Icons" - Fortnite, Minecraft, GTA, FIFA games
- "Pokemon Characters" - Pikachu, Charizard, Mewtwo
- "Gaming YouTubers" - PewDiePie, MrBeast Gaming, Markiplier

🎵 MUSIC:
- "K-Pop Groups" - BTS, BLACKPINK, Stray Kids, NewJeans
- "Global Pop Stars" - Taylor Swift, Ed Sheeran, The Weeknd
- "90s/2000s Music Icons" - Backstreet Boys, Spice Girls

📺 ANIME:
- "Anime Characters" - Naruto, Goku, Luffy, Tanjiro
- "Anime Villains" - Frieza, Madara, Pain
- "Studio Ghibli Characters" - Totoro, Spirited Away characters

🍕 GLOBAL FOOD:
- "Fast Food Chains" - McDonald's, KFC, Starbucks, Pizza Hut
- "Global Snacks" - Oreos, Pringles, Kit-Kat flavors

⚽ GLOBAL SPORTS:
- "Football/Soccer Legends" - Messi, Ronaldo, Neymar, Mbappé
- "Olympic Sports" - Athletics, Swimming, Gymnastics events

📱 TECH:
- "Tech Brands" - Apple, Google, Tesla, Netflix
- "Famous Apps" - Instagram, YouTube, Spotify

📋 REQUIRED JSON FORMAT:
{
  "name": "Clear topic name (3-5 words)",
  "category": "streaming|gaming|music|anime|movies|sports|food|tech|kpop|superheroes",
  "tags": ["5 globally recognized Gen Z tags"],
  "isPremium": false,
  
  "trendingReason": "Why this is GLOBALLY trending with SPECIFIC evidence across multiple regions (3 sentences)",
  "culturalRelevance": "Why this resonates with Gen Z EVERYWHERE - what's the universal experience? (2 sentences)",
  "targetAudience": "${effectiveAudience}",
  "audienceAppeal": "Why Gen Z from ANY country would be excited about this (2-3 sentences)",
  
  "viralPotential": 9,
  "recognitionScore": 9,
  "playabilityScore": 9,
  
  "trendingData": [
    {
      "source": "Global Social Media/Netflix/Spotify/Gaming (specific platform)",
      "evidence": "Worldwide metrics: global views, international charts, cross-border engagement",
      "timeframe": "2024"
    }
  ],
  
  "exampleCards": [
    "Example recognized globally 1",
    "Example recognized globally 2",
    "Example recognized globally 3",
    "Example recognized globally 4",
    "Example recognized globally 5"
  ],
  
  "whyItWorks": "4-5 sentence explanation of why this is PERFECT for global Gen Z: What's the universal appeal? Why does it cross cultural barriers? Why would someone in Tokyo AND Lagos both get excited? Why is it fun to play?",
  
  "vibeCheck": "One sentence Gen Z summary of why this topic is globally fire (e.g., 'literally everyone on earth knows these and that's the point')"
}

Generate something SO good it could trend in 100 countries simultaneously! 🌍🔥`;

    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-5.1', // Latest flagship model
        max_completion_tokens: 3000,
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




