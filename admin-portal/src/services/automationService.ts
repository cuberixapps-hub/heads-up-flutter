import { COUNTRIES, type Country } from '../data/countries';
import { 
  createDeck, 
  getCountryDistribution as getSupabaseCountryDistribution,
  getAutomationStats as getSupabaseAutomationStats,
  type DeckData
} from './supabaseDeckService';
import { generateDeckContent } from './aiContentService';
import { generateDeckImage } from './aiImageService';
import { generateRandomTrendingTopic, generateUniversalTopic, type AIGeneratedTopic, generateTrendingTopics } from './aiTopicService';
import { generateResearchedTopics, generateUniversalResearchedTopic, type ResearchedTopic } from './aiTopicResearchService';
import type { DifficultyLevel } from '../types/ai';
import { validateTopic, quickValidateTopic, getQualityRating } from './topicValidationService';
import { selectSmartColor } from './smartColorService';
import { selectRandomDeckColor, type ColorResult, type ColorForImageGeneration } from './colorExtractionService';

export interface AutomationStats {
  totalDecksCreated: number;
  successfulGenerations: number;
  failedGenerations: number;
  countryDistribution: { [countryCode: string]: number };
  lastGeneratedAt?: Date;
}

export interface AutomationConfig {
  enabled: boolean;
  delayBetweenGenerations: number; // in milliseconds
  maxConcurrentGenerations: number;
  preferredRegions?: string[];
  skipCountries?: string[];
  countriesPerDeck?: number; // Number of additional countries (UNIVERSAL is always included)
  universalRatio?: number; // Percentage of decks that should be universal (0-100), default 70
}

// Track recent topic types to ensure proper distribution
let recentTopicTypes: ('universal' | 'regional')[] = [];
const TOPIC_HISTORY_SIZE = 10;

/**
 * Determine if the next topic should be universal or regional
 * Targets 70% universal, 30% regional distribution
 */
export const shouldGenerateUniversal = (config?: AutomationConfig): boolean => {
  const targetRatio = config?.universalRatio ?? 70; // Default 70% universal
  
  // If we have enough history, check current distribution
  if (recentTopicTypes.length >= TOPIC_HISTORY_SIZE) {
    const universalCount = recentTopicTypes.filter(t => t === 'universal').length;
    const currentRatio = (universalCount / recentTopicTypes.length) * 100;
    
    // Adjust to balance toward target ratio
    if (currentRatio < targetRatio - 10) {
      return true; // Need more universal
    } else if (currentRatio > targetRatio + 10) {
      return false; // Need more regional
    }
  }
  
  // Random selection weighted by target ratio
  return Math.random() * 100 < targetRatio;
};

/**
 * Record the type of topic generated for distribution tracking
 */
const recordTopicType = (type: 'universal' | 'regional') => {
  recentTopicTypes.push(type);
  if (recentTopicTypes.length > TOPIC_HISTORY_SIZE) {
    recentTopicTypes.shift();
  }
};

/**
 * Get the current distribution of decks across countries
 * Note: Decks can have multiple countries, so each country is counted separately
 */
export const getCountryDistribution = async (): Promise<{ [countryCode: string]: number }> => {
  return getSupabaseCountryDistribution();
};

/**
 * Select multiple countries for a deck based on equal distribution
 * Note: UNIVERSAL is always added automatically, so this selects additional countries
 */
export const selectNextCountries = async (
  config: AutomationConfig, 
  count: number = 1
): Promise<Country[]> => {
  try {
    const distribution = await getCountryDistribution();
    
    // Filter out UNIVERSAL since it's always included
    // Filter countries based on config
    let availableCountries = COUNTRIES.filter(country => {
      if (country.code === 'UNIVERSAL') {
        return false; // Skip UNIVERSAL, it's added automatically
      }
      if (config.skipCountries?.includes(country.code)) {
        return false;
      }
      if (config.preferredRegions && config.preferredRegions.length > 0) {
        return config.preferredRegions.includes(country.region);
      }
      return true;
    });
    
    // If no countries available, use all countries
    if (availableCountries.length === 0) {
      availableCountries = COUNTRIES;
    }
    
    // Find countries with the lowest deck count
    const countryCounts = availableCountries.map(country => ({
      country,
      count: distribution[country.code] || 0
    }));
    
    // Sort by count (ascending)
    countryCounts.sort((a, b) => a.count - b.count);
    
    // Select multiple countries with the lowest counts
    const selectedCountries: Country[] = [];
    const minCount = countryCounts[0].count;
    
    // Get countries within a reasonable range of the minimum
    const countRange = minCount + 2; // Within 2 of minimum
    const eligibleCountries = countryCounts.filter(c => c.count <= countRange);
    
    // Randomly select the requested number of countries
    const shuffled = [...eligibleCountries].sort(() => Math.random() - 0.5);
    const numToSelect = Math.min(count, shuffled.length);
    
    for (let i = 0; i < numToSelect; i++) {
      selectedCountries.push(shuffled[i].country);
    }
    
    console.log(`Selected ${selectedCountries.length} countries:`, 
      selectedCountries.map(c => `${c.name} (${c.code})`).join(', '));
    
    return selectedCountries;
  } catch (error) {
    console.error('Error selecting countries:', error);
    // Fallback to UNIVERSAL
    return [COUNTRIES[0]];
  }
};

/**
 * Select the next country to generate content for based on equal distribution
 * @deprecated Use selectNextCountries instead for multi-country support
 */
export const selectNextCountry = async (config: AutomationConfig): Promise<Country> => {
  const countries = await selectNextCountries(config, 1);
  return countries[0];
};

/**
 * Generate a deck automatically with support for multiple countries
 */
export const generateAutomaticDeck = async (
  countries?: Country[],
  topic?: AIGeneratedTopic,
  onProgress?: (message: string) => void,
  config?: AutomationConfig
): Promise<{ success: boolean; deckId?: string; error?: string; generatedDeck?: Record<string, unknown> }> => {
  try {
    const defaultConfig: AutomationConfig = {
      enabled: true,
      delayBetweenGenerations: 5000,
      maxConcurrentGenerations: 1,
      countriesPerDeck: 3 // Default to 3 countries per deck
    };
    
    const finalConfig = { ...defaultConfig, ...config };
    
    // Step 1: Select countries if not provided
    if (!countries || countries.length === 0) {
      onProgress?.('Selecting optimal countries...');
      countries = await selectNextCountries(finalConfig, finalConfig.countriesPerDeck || 3);
    }
    
    // Step 2: Generate trending topic if not provided
    // 🎯 70% UNIVERSAL / 30% REGIONAL logic for Gen Z appeal
    if (!topic) {
      const generateUniversal = shouldGenerateUniversal(config);
      
      onProgress?.('🔥 Generating FIRE topic with AI...');
      onProgress?.(`   📊 Distribution: ${generateUniversal ? '🌍 UNIVERSAL (70%)' : '🌏 REGIONAL (30%)'}`);
      
      // Use the first selected country to generate a trending topic
      const primaryCountry = countries.find(c => c.code !== 'UNIVERSAL') || countries[0];
      
      if (generateUniversal) {
        // 70% of the time: Generate UNIVERSAL topic
        topic = await generateUniversalTopic();
        recordTopicType('universal');
        onProgress?.(`✨ Generated universal Gen Z topic: "${topic.name}"`);
        onProgress?.(`   🔥 Trending because: ${topic.trendingReason}`);
      } else if (primaryCountry.code === 'UNIVERSAL') {
        // Fallback to universal if no regional country
        topic = await generateUniversalTopic();
        recordTopicType('universal');
        onProgress?.(`✨ Generated universal topic: "${topic.name}"`);
      } else {
        // 30% of the time: Generate REGIONAL topic
        topic = await generateRandomTrendingTopic(primaryCountry);
        recordTopicType('regional');
        onProgress?.(`✨ Generated regional topic for ${primaryCountry.flag} ${primaryCountry.name}: "${topic.name}"`);
        onProgress?.(`   🔥 Trending because: ${topic.trendingReason}`);
      }
    }
    
    const countryNames = countries.map(c => `${c.flag} ${c.name}`).join(', ');
    onProgress?.(`Generating deck: "${topic.name}" for ${countryNames} + Universal`);
    
    // Get primary country for context-aware generation
    const primaryCountry = countries.find(c => c.code !== 'UNIVERSAL') || countries[0];
    const countryContext = primaryCountry.code !== 'UNIVERSAL' ? primaryCountry.name : undefined;
    
    // Step 3: Generate content with country context
    onProgress?.('Generating deck content with AI...');
    const deckContent = await generateDeckContent(
      topic.name, 
      'medium', 
      countryContext // Pass country context for relevant content
    );
    
    // Always include UNIVERSAL plus the selected countries
    const countryCodes = ['UNIVERSAL', ...countries.map(c => c.code)];
    
    // 🎨 NEW FLOW: Select color FIRST, then generate image with that color theme
    let imageUrl: string | undefined;
    
    // Step 1: Select random color from our curated palette
    const selectedColorData: ColorForImageGeneration = selectRandomDeckColor();
    const selectedColor: ColorResult = selectedColorData.color;
    
    onProgress?.(`🎨 Selected deck color: ${selectedColor.name} (${selectedColor.hex})`);
    onProgress?.(`🖼️ Generating image with ${selectedColor.name} theme...`);
    
    const topicWithContext = countryContext ? `${topic.name} (${countryContext})` : topic.name;
    
    try {
      // Step 2: Generate image WITH the selected color theme
      imageUrl = await generateDeckImage(topicWithContext, 'retro pulp', {
        targetColor: {
          hex: selectedColor.hex,
          name: selectedColor.name,
          promptDescription: selectedColorData.promptDescription
        }
      });
      onProgress?.(`✅ Image generated with ${selectedColor.name} theme!`);
    } catch (imageError) {
      console.warn('Image generation failed:', imageError);
      onProgress?.('⚠️ Image generation failed, deck will use color without custom image');
    }
    
    onProgress?.(`🎨 Deck theme: ${selectedColor.name} (${selectedColor.hex})`);
    
    // Step 5: Save to Supabase with multiple countries
    onProgress?.('Saving deck to database...');
    const deckDataToSave: DeckData = {
      name: deckContent.name,
      description: deckContent.description,
      cards: deckContent.cards,
      iconCodePoint: deckContent.iconSuggestion?.codePoint || 0xf005,
      iconFontFamily: deckContent.iconSuggestion?.fontFamily || 'FontAwesomeIcons',
      colorValue: selectedColor.colorValue, // Pre-selected color
      colorName: selectedColor.name,
      colorHex: selectedColor.hex,
      imageUrl: imageUrl || null,
      isPremium: topic.isPremium || false,
      isActive: true,
      countries: countryCodes, // Array of country codes
      country: countryCodes[0], // Keep first country for backward compatibility
      tags: deckContent.suggestedTags || [],
      priority: 0,
      generatedByAI: true,
      automatedGeneration: true,
      generationTopic: topic.name,
      generationCategory: topic.category
    };
    
    const savedDeck = await createDeck(deckDataToSave);
    
    onProgress?.(`✅ Successfully created deck: "${deckContent.name}"`);
    
    return {
      success: true,
      deckId: savedDeck.id,
      generatedDeck: {
        name: deckContent.name,
        description: deckContent.description,
        countries: countryCodes,
        imageUrl: imageUrl
      }
    };
    
  } catch (error: unknown) {
    console.error('Automatic generation error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    onProgress?.(`❌ Error: ${errorMessage}`);
    
    return {
      success: false,
      error: errorMessage
    };
  }
};

/**
 * Get automation statistics
 */
export const getAutomationStats = async (): Promise<AutomationStats> => {
  const supabaseStats = await getSupabaseAutomationStats();
  return {
    totalDecksCreated: supabaseStats.totalDecksCreated,
    successfulGenerations: supabaseStats.successfulGenerations,
    failedGenerations: 0,
    countryDistribution: supabaseStats.countryDistribution,
    lastGeneratedAt: supabaseStats.lastGeneratedAt
  };
};

/**
 * Validate if automation can run
 */
export const canRunAutomation = (): { canRun: boolean; reason?: string } => {
  // Check if API keys are available
  const openaiKey = import.meta.env.VITE_OPENAI_API_KEY;
  
  if (!openaiKey) {
    return {
      canRun: false,
      reason: 'Missing OpenAI API key. Please configure VITE_OPENAI_API_KEY in your .env.local file.'
    };
  }
  
  return { canRun: true };
};

/**
 * Sleep utility for delays between generations
 */
export const sleep = (ms: number): Promise<void> => {
  return new Promise(resolve => setTimeout(resolve, ms));
};

/**
 * Generate a PREMIUM, WELL-RESEARCHED deck with proper reasoning
 * This uses the new research-based topic generation for higher quality
 */
export const generateResearchedDeck = async (
  countries?: Country[],
  targetAudience?: 'teens' | 'adults' | 'families',
  onProgress?: (message: string) => void,
  config?: AutomationConfig
): Promise<{ 
  success: boolean; 
  deckIds: string[]; 
  errors: string[];
  generatedDecks: Array<{
    id: string;
    name: string;
    countries: string[];
    research: {
      trendingReason: string;
      culturalRelevance: string;
      audienceAppeal: string;
      whyItWorks: string;
      trendingData: Array<{
        source: string;
        evidence: string;
        timeframe: string;
      }>;
      scores: {
        viral: number;
        recognition: number;
        playability: number;
      };
    };
    modes: {
      easy: number;
      medium: number;
      hard: number;
    };
  }>;
}> => {
  const deckIds: string[] = [];
  const errors: string[] = [];
  const generatedDecks: Array<{
    id: string;
    name: string;
    countries: string[];
    research: {
      trendingReason: string;
      culturalRelevance: string;
      audienceAppeal: string;
      whyItWorks: string;
      trendingData: Array<{
        source: string;
        evidence: string;
        timeframe: string;
      }>;
      scores: {
        viral: number;
        recognition: number;
        playability: number;
      };
    };
    modes: {
      easy: number;
      medium: number;
      hard: number;
    };
  }> = [];
  const difficulties: DifficultyLevel[] = ['easy', 'medium', 'hard'];
  
  try {
    const defaultConfig: AutomationConfig = {
      enabled: true,
      delayBetweenGenerations: 5000,
      maxConcurrentGenerations: 1,
      countriesPerDeck: 3
    };
    
    const finalConfig = { ...defaultConfig, ...config };
    
    // Step 1: Select countries if not provided
    if (!countries || countries.length === 0) {
      onProgress?.('🌍 Selecting optimal countries...');
      countries = await selectNextCountries(finalConfig, finalConfig.countriesPerDeck || 3);
    }
    
    const countryNames = countries.map(c => `${c.flag} ${c.name}`).join(', ');
    onProgress?.(`📍 Selected countries: ${countryNames}`);
    
    // Step 2: Generate RESEARCHED topic with proper reasoning
    // 🎯 70% UNIVERSAL / 30% REGIONAL logic for Gen Z appeal
    const generateUniversal = shouldGenerateUniversal(config);
    
    onProgress?.('\n🔬 GENERATING RESEARCH-BASED TOPIC...');
    onProgress?.(`   📊 Distribution: ${generateUniversal ? '🌍 UNIVERSAL (70% target)' : '🌏 REGIONAL (30% target)'}`);
    onProgress?.('   Analyzing trends, cultural relevance, and audience appeal...');
    
    let researchedTopic: ResearchedTopic;
    const primaryCountry = countries.find(c => c.code !== 'UNIVERSAL') || countries[0];
    
    if (generateUniversal) {
      // 70% of the time: Generate UNIVERSAL topic for global Gen Z appeal
      onProgress?.('   🌍 Researching GLOBAL Gen Z trends...');
      onProgress?.('   🔥 Looking for topics that work in Tokyo, Lagos, London, São Paulo...');
      researchedTopic = await generateUniversalResearchedTopic(targetAudience || 'teens');
      recordTopicType('universal');
      onProgress?.(`   ✨ Generated universal topic: "${researchedTopic.name}"`);
    } else {
      // 30% of the time: Generate REGIONAL topic with country-specific appeal
      onProgress?.(`   ${primaryCountry.flag} Researching regional Gen Z trends in ${primaryCountry.name}...`);
      const topics = await generateResearchedTopics(primaryCountry, 1, targetAudience || 'teens');
      researchedTopic = topics[0];
      recordTopicType('regional');
      onProgress?.(`   ✨ Generated regional topic for ${primaryCountry.name}: "${researchedTopic.name}"`);
    }
    
    // Display the research findings
    onProgress?.(`\n✨ RESEARCHED TOPIC: "${researchedTopic.name}"\n`);
    onProgress?.(`📊 QUALITY SCORES:`);
    onProgress?.(`   🔥 Viral Potential: ${researchedTopic.viralPotential}/10`);
    onProgress?.(`   👁️  Recognition: ${researchedTopic.recognitionScore}/10`);
    onProgress?.(`   🎮 Playability: ${researchedTopic.playabilityScore}/10`);
    onProgress?.(`\n🎯 TARGET AUDIENCE: ${researchedTopic.targetAudience}`);
    onProgress?.(`\n📈 TRENDING REASON:`);
    onProgress?.(`   ${researchedTopic.trendingReason}`);
    onProgress?.(`\n🌍 CULTURAL RELEVANCE:`);
    onProgress?.(`   ${researchedTopic.culturalRelevance}`);
    onProgress?.(`\n💡 AUDIENCE APPEAL:`);
    onProgress?.(`   ${researchedTopic.audienceAppeal}`);
    onProgress?.(`\n✅ WHY IT WORKS:`);
    onProgress?.(`   ${researchedTopic.whyItWorks}`);
    
    if (researchedTopic.trendingData && researchedTopic.trendingData.length > 0) {
      onProgress?.(`\n📚 SUPPORTING DATA:`);
      researchedTopic.trendingData.forEach(data => {
        onProgress?.(`   • ${data.source} (${data.timeframe}): ${data.evidence}`);
      });
    }
    
    if (researchedTopic.exampleCards && researchedTopic.exampleCards.length > 0) {
      onProgress?.(`\n🎴 EXAMPLE CARDS:`);
      researchedTopic.exampleCards.slice(0, 3).forEach(card => {
        onProgress?.(`   • ${card}`);
      });
    }
    
    onProgress?.(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`);
    
    const countryCodes = ['UNIVERSAL', ...countries.map(c => c.code)];
    const countryContext = primaryCountry.code !== 'UNIVERSAL' ? primaryCountry.name : undefined;
    
    onProgress?.(`🎯 Generating ONE deck with 3 difficulty modes: "${researchedTopic.name}"`);
    onProgress?.(`   Countries: ${countryNames} + Universal\n`);
    
    // Step 3: Generate cards for all 3 difficulty modes
    const cardsByDifficulty: { easy: string[]; medium: string[]; hard: string[] } = {
      easy: [],
      medium: [],
      hard: []
    };
    
    let primaryDeckContent;
    let imageUrl: string | undefined;
    
    // 🎨 NEW FLOW: Select color FIRST, then generate image with that theme
    const selectedColorDataRes: ColorForImageGeneration = selectRandomDeckColor();
    const selectedColorRes: ColorResult = selectedColorDataRes.color;
    
    onProgress?.(`🎨 Selected deck color: ${selectedColorRes.name} (${selectedColorRes.hex})`);
    onProgress?.(`🖼️ Generating image with ${selectedColorRes.name} theme for "${researchedTopic.name}"...`);
    
    const topicWithContext = countryContext ? `${researchedTopic.name} (${countryContext})` : researchedTopic.name;
    
    try {
      // Generate image WITH the selected color theme
      imageUrl = await generateDeckImage(topicWithContext, 'retro pulp', {
        targetColor: {
          hex: selectedColorRes.hex,
          name: selectedColorRes.name,
          promptDescription: selectedColorDataRes.promptDescription
        }
      });
      onProgress?.(`   ✅ Image generated with ${selectedColorRes.name} theme!`);
    } catch (imageError) {
      console.warn('Image generation failed:', imageError);
      onProgress?.(`   ⚠️ Image generation failed, deck will use color without custom image`);
    }
    
    onProgress?.(`\n🎨 Deck theme: ${selectedColorRes.name} (${selectedColorRes.hex})\n`);
    
    for (const difficulty of difficulties) {
      try {
        const difficultyEmoji = difficulty === 'easy' ? '🟢' : difficulty === 'medium' ? '🟡' : '🔴';
        onProgress?.(`${difficultyEmoji} Generating ${difficulty.toUpperCase()} mode cards...`);
        
        const deckContent = await generateDeckContent(researchedTopic.name, difficulty, countryContext);
        onProgress?.(`   ✅ ${deckContent.cards.length} cards generated`);
        
        cardsByDifficulty[difficulty] = deckContent.cards;
        
        if (difficulty === 'easy') {
          primaryDeckContent = deckContent;
        }
        
        if (difficulty !== 'hard') {
          await sleep(2000);
        }
        
      } catch (difficultyError: unknown) {
        const errorMsg = `Failed to generate ${difficulty} mode: ${difficultyError instanceof Error ? difficultyError.message : 'Unknown error'}`;
        console.error(errorMsg, difficultyError);
        errors.push(errorMsg);
        onProgress?.(`   ❌ ${errorMsg}\n`);
        
        cardsByDifficulty[difficulty] = [`${researchedTopic.name} ${difficulty} card 1`, `${researchedTopic.name} ${difficulty} card 2`];
      }
    }
    
    if (!primaryDeckContent) {
      throw new Error('Failed to generate deck content');
    }
    
    // Create enhanced description with research
    const enhancedDescription = `${primaryDeckContent.description}\n\n🔥 ${researchedTopic.trendingReason}\n\n💡 ${researchedTopic.whyItWorks}`;
    
    // Save ONE deck to Supabase with research metadata
    onProgress?.(`\n💾 Saving researched deck with metadata...`);
    const researchedDeckData: DeckData = {
      name: primaryDeckContent.name,
      description: enhancedDescription,
      cards: cardsByDifficulty.easy,
      cardsByDifficulty: {
        easy: cardsByDifficulty.easy,
        medium: cardsByDifficulty.medium,
        hard: cardsByDifficulty.hard
      },
      hasDifficultyModes: true,
      iconCodePoint: primaryDeckContent.iconSuggestion?.codePoint || 0xf005,
      iconFontFamily: primaryDeckContent.iconSuggestion?.fontFamily || 'FontAwesomeIcons',
      colorValue: selectedColorRes.colorValue, // Pre-selected color
      colorName: selectedColorRes.name,
      colorHex: selectedColorRes.hex,
      imageUrl: imageUrl || null,
      isPremium: researchedTopic.isPremium || false,
      isActive: true,
      countries: countryCodes,
      country: countryCodes[0],
      tags: [...(primaryDeckContent.suggestedTags || []), 'researched', 'premium-quality', 'multi-difficulty'],
      priority: 0,
      generatedByAI: true,
      automatedGeneration: true,
      researchBased: true, // NEW: Flag for research-based decks
      
      // Research metadata
      research: {
        trendingReason: researchedTopic.trendingReason,
        culturalRelevance: researchedTopic.culturalRelevance,
        targetAudience: researchedTopic.targetAudience,
        audienceAppeal: researchedTopic.audienceAppeal,
        whyItWorks: researchedTopic.whyItWorks,
        trendingData: researchedTopic.trendingData,
        exampleCards: researchedTopic.exampleCards,
        scores: {
          viralPotential: researchedTopic.viralPotential,
          recognitionScore: researchedTopic.recognitionScore,
          playabilityScore: researchedTopic.playabilityScore
        }
      },
      
      generationTopic: researchedTopic.name,
      generationCategory: researchedTopic.category,
      baseTopic: researchedTopic.name
    };
    
    const savedResearchedDeck = await createDeck(researchedDeckData);
    deckIds.push(savedResearchedDeck.id!);
    
    generatedDecks.push({
      id: savedResearchedDeck.id!,
      name: primaryDeckContent.name,
      countries: countryCodes,
      research: {
        trendingReason: researchedTopic.trendingReason,
        culturalRelevance: researchedTopic.culturalRelevance,
        audienceAppeal: researchedTopic.audienceAppeal,
        whyItWorks: researchedTopic.whyItWorks,
        trendingData: researchedTopic.trendingData,
        scores: {
          viral: researchedTopic.viralPotential,
          recognition: researchedTopic.recognitionScore,
          playability: researchedTopic.playabilityScore
        }
      },
      modes: {
        easy: cardsByDifficulty.easy.length,
        medium: cardsByDifficulty.medium.length,
        hard: cardsByDifficulty.hard.length
      }
    });
    
    onProgress?.(`   ✅ Deck saved successfully!\n`);
    
    // Enhanced summary with research
    onProgress?.(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    onProgress?.(`\n🎉 SUCCESS! Generated PREMIUM RESEARCHED DECK`);
    onProgress?.(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    onProgress?.(`\n📦 DECK: "${primaryDeckContent.name}"`);
    onProgress?.(`🌍 COUNTRIES: ${countryNames} + Universal`);
    onProgress?.(`🎯 TARGET: ${researchedTopic.targetAudience}`);
    onProgress?.(`\n📊 QUALITY METRICS:`);
    onProgress?.(`   🔥 Viral Potential: ${researchedTopic.viralPotential}/10`);
    onProgress?.(`   👁️  Recognition: ${researchedTopic.recognitionScore}/10`);
    onProgress?.(`   🎮 Playability: ${researchedTopic.playabilityScore}/10`);
    onProgress?.(`\n🎴 CARDS:`);
    onProgress?.(`   🟢 Easy: ${cardsByDifficulty.easy.length} cards`);
    onProgress?.(`   🟡 Medium: ${cardsByDifficulty.medium.length} cards`);
    onProgress?.(`   🔴 Hard: ${cardsByDifficulty.hard.length} cards`);
    onProgress?.(`\n✅ WHY IT'S AMAZING:`);
    onProgress?.(`   ${researchedTopic.whyItWorks}`);
    onProgress?.(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`);
    
    return {
      success: deckIds.length > 0,
      deckIds,
      errors,
      generatedDecks
    };
    
  } catch (error: unknown) {
    console.error('Researched deck generation error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    errors.push(errorMessage);
    onProgress?.(`\n❌ ERROR: ${errorMessage}\n`);
    
    return {
      success: false,
      deckIds,
      errors,
      generatedDecks
    };
  }
};

/**
 * Generate 3 difficulty versions (easy, medium, hard) of a deck from a single topic
 * @param countries Countries to generate for
 * @param topic The topic to generate decks from
 * @param onProgress Progress callback
 * @param config Automation config
 * @returns Promise with success status and generated deck IDs
 */
export const generateMultiDifficultyDecks = async (
  countries?: Country[],
  topic?: AIGeneratedTopic,
  onProgress?: (message: string) => void,
  config?: AutomationConfig
): Promise<{ 
  success: boolean; 
  deckIds: string[]; 
  errors: string[];
  generatedDecks: Array<{
    id: string;
    name: string;
    countries: string[];
    modes: {
      easy: number;
      medium: number;
      hard: number;
    };
  }>;
}> => {
  const deckIds: string[] = [];
  const errors: string[] = [];
  const generatedDecks: Array<{
    id: string;
    name: string;
    countries: string[];
    modes: {
      easy: number;
      medium: number;
      hard: number;
    };
  }> = [];
  const difficulties: DifficultyLevel[] = ['easy', 'medium', 'hard'];
  
  try {
    const defaultConfig: AutomationConfig = {
      enabled: true,
      delayBetweenGenerations: 5000,
      maxConcurrentGenerations: 1,
      countriesPerDeck: 3
    };
    
    const finalConfig = { ...defaultConfig, ...config };
    
    // Step 1: Select countries if not provided
    if (!countries || countries.length === 0) {
      onProgress?.('Selecting optimal countries...');
      countries = await selectNextCountries(finalConfig, finalConfig.countriesPerDeck || 3);
    }
    
    // Step 2: Generate trending topic if not provided
    // 🎯 70% UNIVERSAL / 30% REGIONAL logic for Gen Z appeal
    if (!topic) {
      const generateUniversal = shouldGenerateUniversal(config);
      
      onProgress?.('🔥 Generating FIRE trending topic with AI...');
      onProgress?.(`   📊 Distribution: ${generateUniversal ? '🌍 UNIVERSAL (70% target)' : '🌏 REGIONAL (30% target)'}`);
      
      const primaryCountry = countries.find(c => c.code !== 'UNIVERSAL') || countries[0];
      
      // Generate multiple topics and validate them
      const maxAttempts = 3; // Try up to 3 times to get a quality topic
      let validatedTopic: AIGeneratedTopic | null = null;
      
      for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          onProgress?.(`   Attempt ${attempt}/${maxAttempts}: Generating topic candidates...`);
          
          // Generate topics based on 70/30 distribution
          let candidateTopics: AIGeneratedTopic[];
          
          if (generateUniversal) {
            // 70% of the time: Generate UNIVERSAL topic for global Gen Z appeal
            onProgress?.('   🌍 Generating universal Gen Z topic...');
            candidateTopics = [await generateUniversalTopic()];
            recordTopicType('universal');
          } else if (primaryCountry.code === 'UNIVERSAL') {
            // Fallback to universal if no regional country selected
            candidateTopics = [await generateUniversalTopic()];
            recordTopicType('universal');
          } else {
            // 30% of the time: Generate REGIONAL topic with country-specific appeal
            onProgress?.(`   ${primaryCountry.flag} Generating regional topic for ${primaryCountry.name}...`);
            candidateTopics = await generateTrendingTopics(primaryCountry, 3);
            recordTopicType('regional');
          }
          
          onProgress?.(`   Generated ${candidateTopics.length} topic candidates, validating...`);
          
          // Quick validate first
          const quickPassedTopics = candidateTopics.filter(t => quickValidateTopic(t));
          
          if (quickPassedTopics.length === 0) {
            onProgress?.(`   ❌ All topics failed quick validation, retrying...`);
            continue;
          }
          
          // AI validate the best candidates
          for (const candidate of quickPassedTopics) {
            try {
              onProgress?.(`   🔍 Validating "${candidate.name}"...`);
              const score = await validateTopic(candidate, primaryCountry.code !== 'UNIVERSAL' ? primaryCountry : undefined);
              
              const rating = getQualityRating(score.total);
              onProgress?.(`   ${rating} Score: ${score.total}/100`);
              onProgress?.(`      💡 ${score.feedback}`);
              
              if (score.passed) {
                validatedTopic = candidate;
                onProgress?.(`   ✅ Topic validated and approved!`);
                break;
              } else {
                onProgress?.(`   ❌ Topic score too low (${score.total}/70), trying next...`);
              }
            } catch (validationError) {
              console.warn(`Validation failed for topic "${candidate.name}":`, validationError);
              onProgress?.(`   ⚠️ Validation error, trying next topic...`);
            }
          }
          
          if (validatedTopic) {
            break; // Success!
          }
          
        } catch (generationError) {
          console.error(`Topic generation attempt ${attempt} failed:`, generationError);
          onProgress?.(`   ❌ Generation failed, retrying...`);
        }
      }
      
      if (!validatedTopic) {
        // Fallback: generate without validation
        onProgress?.(`   ⚠️ Using fallback topic generation (validation unavailable)`);
        if (primaryCountry.code === 'UNIVERSAL') {
          validatedTopic = await generateUniversalTopic();
        } else {
          validatedTopic = await generateRandomTrendingTopic(primaryCountry);
        }
      }
      
      topic = validatedTopic;
      
      if (primaryCountry.code === 'UNIVERSAL') {
        onProgress?.(`✨ Generated universal topic: "${topic.name}"`);
      } else {
        onProgress?.(`✨ Generated topic for ${primaryCountry.flag} ${primaryCountry.name}: "${topic.name}"`);
      }
      onProgress?.(`   🔥 Trending: ${topic.trendingReason}`);
    }
    
    const countryNames = countries.map(c => `${c.flag} ${c.name}`).join(', ');
    const countryCodes = ['UNIVERSAL', ...countries.map(c => c.code)];
    
    // Get primary country for context-aware generation
    const primaryCountry = countries.find(c => c.code !== 'UNIVERSAL') || countries[0];
    const countryContext = primaryCountry.code !== 'UNIVERSAL' ? primaryCountry.name : undefined;
    
    onProgress?.(`\n🎯 Generating ONE deck with 3 difficulty modes: "${topic.name}"`);
    onProgress?.(`   Countries: ${countryNames} + Universal\n`);
    
    // Step 3: Generate cards for all 3 difficulty modes
    const cardsByDifficulty: { easy: string[]; medium: string[]; hard: string[] } = {
      easy: [],
      medium: [],
      hard: []
    };
    
    let primaryDeckContent;
    let imageUrl: string | undefined;
    
    // 🎨 NEW FLOW: Select color FIRST, then generate image with that theme
    const selectedColorDataMulti: ColorForImageGeneration = selectRandomDeckColor();
    const selectedColorMulti: ColorResult = selectedColorDataMulti.color;
    
    onProgress?.(`🎨 Selected deck color: ${selectedColorMulti.name} (${selectedColorMulti.hex})`);
    onProgress?.(`🖼️ Generating image with ${selectedColorMulti.name} theme for "${topic.name}"...`);
    
    const topicWithContextMulti = countryContext ? `${topic.name} (${countryContext})` : topic.name;
    
    try {
      // Generate image WITH the selected color theme
      imageUrl = await generateDeckImage(topicWithContextMulti, 'retro pulp', {
        targetColor: {
          hex: selectedColorMulti.hex,
          name: selectedColorMulti.name,
          promptDescription: selectedColorDataMulti.promptDescription
        }
      });
      onProgress?.(`   ✅ Image generated with ${selectedColorMulti.name} theme!`);
    } catch (imageError) {
      console.warn('Image generation failed:', imageError);
      onProgress?.(`   ⚠️ Image generation failed, deck will use color without custom image`);
    }
    
    onProgress?.(`\n🎨 Deck theme: ${selectedColorMulti.name} (${selectedColorMulti.hex})\n`);
    
    for (const difficulty of difficulties) {
      try {
        const difficultyEmoji = difficulty === 'easy' ? '🟢' : difficulty === 'medium' ? '🟡' : '🔴';
        onProgress?.(`${difficultyEmoji} Generating ${difficulty.toUpperCase()} mode cards...`);
        
        // Generate content with specific difficulty and country context
        const deckContent = await generateDeckContent(topic.name, difficulty, countryContext);
        onProgress?.(`   ✅ ${deckContent.cards.length} cards generated`);
        
        // Store cards by difficulty
        cardsByDifficulty[difficulty] = deckContent.cards;
        
        // Use the first (easy) version for primary deck metadata
        if (difficulty === 'easy') {
          primaryDeckContent = deckContent;
        }
        
        // Small delay between difficulty generations
        if (difficulty !== 'hard') {
          await sleep(2000);
        }
        
      } catch (difficultyError: unknown) {
        const errorMsg = `Failed to generate ${difficulty} mode: ${difficultyError instanceof Error ? difficultyError.message : 'Unknown error'}`;
        console.error(errorMsg, difficultyError);
        errors.push(errorMsg);
        onProgress?.(`   ❌ ${errorMsg}\n`);
        
        // Fill with fallback if generation fails
        cardsByDifficulty[difficulty] = [`${topic.name} ${difficulty} card 1`, `${topic.name} ${difficulty} card 2`];
      }
    }
    
    if (!primaryDeckContent) {
      throw new Error('Failed to generate deck content');
    }
    
    // Save ONE deck to Supabase with all difficulty modes
    onProgress?.(`\n💾 Saving deck with 3 difficulty modes...`);
    const multiDifficultyDeckData: DeckData = {
      name: primaryDeckContent.name,
      description: primaryDeckContent.description,
      cards: cardsByDifficulty.easy, // Default to easy for backward compatibility
      cardsByDifficulty: {
        easy: cardsByDifficulty.easy,
        medium: cardsByDifficulty.medium,
        hard: cardsByDifficulty.hard
      },
      hasDifficultyModes: true, // Flag to indicate this deck has multiple modes
      iconCodePoint: primaryDeckContent.iconSuggestion?.codePoint || 0xf005,
      iconFontFamily: primaryDeckContent.iconSuggestion?.fontFamily || 'FontAwesomeIcons',
      colorValue: selectedColorMulti.colorValue, // Pre-selected color
      colorName: selectedColorMulti.name,
      colorHex: selectedColorMulti.hex,
      imageUrl: imageUrl || null,
      isPremium: topic.isPremium || false,
      isActive: true,
      countries: countryCodes,
      country: countryCodes[0],
      tags: [...(primaryDeckContent.suggestedTags || []), 'multi-difficulty'],
      priority: 0,
      generatedByAI: true,
      automatedGeneration: true,
      generationTopic: topic.name,
      generationCategory: topic.category,
      baseTopic: topic.name
    };
    
    const savedMultiDeck = await createDeck(multiDifficultyDeckData);
    deckIds.push(savedMultiDeck.id!);
    
    generatedDecks.push({
      id: savedMultiDeck.id!,
      name: primaryDeckContent.name,
      countries: countryCodes,
      modes: {
        easy: cardsByDifficulty.easy.length,
        medium: cardsByDifficulty.medium.length,
        hard: cardsByDifficulty.hard.length
      }
    });
    
    onProgress?.(`   ✅ Deck saved successfully!\n`);
    
    // Summary
    onProgress?.(`\n🎉 SUCCESS! Generated ONE deck with 3 difficulty modes`);
    onProgress?.(`   📦 Deck: "${primaryDeckContent.name}"`);
    onProgress?.(`   🌍 Countries: ${countryNames} + Universal`);
    onProgress?.(`   🟢 Easy: ${cardsByDifficulty.easy.length} cards`);
    onProgress?.(`   🟡 Medium: ${cardsByDifficulty.medium.length} cards`);
    onProgress?.(`   🔴 Hard: ${cardsByDifficulty.hard.length} cards`);
    
    return {
      success: deckIds.length > 0,
      deckIds,
      errors,
      generatedDecks
    };
    
  } catch (error: unknown) {
    console.error('Multi-difficulty generation error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    errors.push(errorMessage);
    
    return {
      success: false,
      deckIds,
      errors,
      generatedDecks
    };
  }
};


