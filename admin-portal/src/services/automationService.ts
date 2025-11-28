import { collection, getDocs, addDoc, serverTimestamp, query, where } from 'firebase/firestore';
import { db } from '../config/firebase';
import { COUNTRIES, type Country } from '../data/countries';
import { generateDeckContent } from './aiContentService';
import { generateDeckImage } from './aiImageService';
import { generateRandomTrendingTopic, generateUniversalTopic, type AIGeneratedTopic, generateTrendingTopics } from './aiTopicService';
import { generateResearchedTopics, generateUniversalResearchedTopic, type ResearchedTopic } from './aiTopicResearchService';
import type { DifficultyLevel } from '../types/ai';
import { validateTopic, quickValidateTopic, getQualityRating } from './topicValidationService';
import { extractPrimaryColor, getRandomVibrantColor } from './colorExtractionService';

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
}

/**
 * Get the current distribution of decks across countries
 * Note: Decks can have multiple countries, so each country is counted separately
 */
export const getCountryDistribution = async (): Promise<{ [countryCode: string]: number }> => {
  try {
    const decksRef = collection(db, 'decks');
    const snapshot = await getDocs(decksRef);
    
    const distribution: { [countryCode: string]: number } = {};
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const countries = data.countries || (data.country ? [data.country] : ['UNIVERSAL']);
      
      // Count each country separately for multi-country decks
      countries.forEach((countryCode: string) => {
        distribution[countryCode] = (distribution[countryCode] || 0) + 1;
      });
    });
    
    return distribution;
  } catch (error) {
    console.error('Error getting country distribution:', error);
    return {};
  }
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
    if (!topic) {
      onProgress?.('🔥 Generating trending topic with AI...');
      
      // Use the first selected country to generate a trending topic
      // If it's UNIVERSAL, generate a universal topic
      const primaryCountry = countries.find(c => c.code !== 'UNIVERSAL') || countries[0];
      
      if (primaryCountry.code === 'UNIVERSAL') {
        topic = await generateUniversalTopic();
        onProgress?.(`✨ Generated universal topic: "${topic.name}"`);
      } else {
        topic = await generateRandomTrendingTopic(primaryCountry);
        onProgress?.(`✨ Generated trending topic for ${primaryCountry.flag} ${primaryCountry.name}: "${topic.name}"`);
        onProgress?.(`   Trending because: ${topic.trendingReason}`);
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
    
    // Step 4: Generate image (optional, continue on failure) with country context
    let imageUrl: string | undefined;
    let extractedColorValue: number | undefined;
    try {
      onProgress?.('Generating deck image...');
      // Pass country context to image generation for relevant visuals
      const topicWithContext = countryContext ? `${topic.name} (${countryContext})` : topic.name;
      imageUrl = await generateDeckImage(topicWithContext);
      
      // Extract dominant color from the generated image
      if (imageUrl) {
        try {
          onProgress?.('🎨 Extracting dominant color from image...');
          const primaryColor = await extractPrimaryColor(imageUrl);
          extractedColorValue = primaryColor.colorValue;
          onProgress?.(`✅ Color extracted: ${primaryColor.name} (${primaryColor.hex})`);
        } catch (colorError) {
          console.warn('Color extraction failed, using fallback:', colorError);
          const fallbackColor = getRandomVibrantColor();
          extractedColorValue = fallbackColor.colorValue;
          onProgress?.(`⚠️ Using fallback color: ${fallbackColor.name}`);
        }
      }
    } catch (imageError) {
      console.warn('Image generation failed, continuing without image:', imageError);
      onProgress?.('Image generation failed, continuing without image...');
    }
    
    // Use extracted color from image, or fall back to AI suggestion, or default purple
    const finalColorValue = extractedColorValue || deckContent.colorSuggestion || 0xFF9C27B0;
    
    // Step 5: Save to Firestore with multiple countries
    onProgress?.('Saving deck to database...');
    const deckData = {
      name: deckContent.name,
      description: deckContent.description,
      cards: deckContent.cards,
      iconCodePoint: deckContent.iconSuggestion?.codePoint || 0xf005,
      iconFontFamily: deckContent.iconSuggestion?.fontFamily || 'FontAwesomeIcons',
      colorValue: finalColorValue,
      colorExtractedFromImage: !!extractedColorValue, // Flag to indicate color was extracted from image
      imageUrl: imageUrl || null,
      isPremium: topic.isPremium || false,
      countries: countryCodes, // Array of country codes
      country: countryCodes[0], // Keep first country for backward compatibility
      tags: deckContent.suggestedTags,
      priority: 0,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      generatedByAI: true,
      automatedGeneration: true,
      generationTopic: topic.name,
      generationCategory: topic.category
    };
    
    const docRef = await addDoc(collection(db, 'decks'), deckData);
    
    onProgress?.(`✅ Successfully created deck: "${deckContent.name}"`);
    
    return {
      success: true,
      deckId: docRef.id,
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
  try {
    const decksRef = collection(db, 'decks');
    const automatedQuery = query(decksRef, where('automatedGeneration', '==', true));
    const snapshot = await getDocs(automatedQuery);
    
    const stats: AutomationStats = {
      totalDecksCreated: snapshot.size,
      successfulGenerations: snapshot.size,
      failedGenerations: 0,
      countryDistribution: {}
    };
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const country = data.country || 'UNIVERSAL';
      stats.countryDistribution[country] = (stats.countryDistribution[country] || 0) + 1;
      
      // Get the latest creation date
      if (data.createdAt) {
        const createdAt = data.createdAt.toDate();
        if (!stats.lastGeneratedAt || createdAt > stats.lastGeneratedAt) {
          stats.lastGeneratedAt = createdAt;
        }
      }
    });
    
    return stats;
  } catch (error) {
    console.error('Error getting automation stats:', error);
    return {
      totalDecksCreated: 0,
      successfulGenerations: 0,
      failedGenerations: 0,
      countryDistribution: {}
    };
  }
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
    onProgress?.('\n🔬 GENERATING RESEARCH-BASED TOPIC...');
    onProgress?.('   Analyzing trends, cultural relevance, and audience appeal...');
    
    let researchedTopic: ResearchedTopic;
    const primaryCountry = countries.find(c => c.code !== 'UNIVERSAL') || countries[0];
    
    if (primaryCountry.code === 'UNIVERSAL') {
      onProgress?.('   🌍 Researching GLOBAL trends...');
      researchedTopic = await generateUniversalResearchedTopic(targetAudience);
    } else {
      onProgress?.(`   ${primaryCountry.flag} Researching trends in ${primaryCountry.name}...`);
      const topics = await generateResearchedTopics(primaryCountry, 1, targetAudience);
      researchedTopic = topics[0];
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
    let extractedColorValue: number | undefined;
    
    for (const difficulty of difficulties) {
      try {
        const difficultyEmoji = difficulty === 'easy' ? '🟢' : difficulty === 'medium' ? '🟡' : '🔴';
        onProgress?.(`${difficultyEmoji} Generating ${difficulty.toUpperCase()} mode cards...`);
        
        const deckContent = await generateDeckContent(researchedTopic.name, difficulty, countryContext);
        onProgress?.(`   ✅ ${deckContent.cards.length} cards generated`);
        
        cardsByDifficulty[difficulty] = deckContent.cards;
        
        if (difficulty === 'easy') {
          primaryDeckContent = deckContent;
          
          try {
            onProgress?.(`   🎨 Generating deck image...`);
            const topicWithContext = countryContext ? `${researchedTopic.name} (${countryContext})` : researchedTopic.name;
            imageUrl = await generateDeckImage(topicWithContext);
            onProgress?.(`   ✅ Image generated`);
            
            // Extract dominant color from the generated image
            if (imageUrl) {
              try {
                onProgress?.(`   🎨 Extracting dominant color from image...`);
                const primaryColor = await extractPrimaryColor(imageUrl);
                extractedColorValue = primaryColor.colorValue;
                onProgress?.(`   ✅ Color extracted: ${primaryColor.name} (${primaryColor.hex})`);
              } catch (colorError) {
                console.warn('Color extraction failed, using fallback:', colorError);
                const fallbackColor = getRandomVibrantColor();
                extractedColorValue = fallbackColor.colorValue;
                onProgress?.(`   ⚠️ Using fallback color: ${fallbackColor.name}`);
              }
            }
          } catch (imageError) {
            console.warn('Image generation failed:', imageError);
            onProgress?.(`   ⚠️ Image generation failed, continuing...`);
          }
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
    
    // Use extracted color from image, or fall back to AI suggestion, or default purple
    const finalColorValue = extractedColorValue || primaryDeckContent.colorSuggestion || 0xFF9C27B0;
    
    // Create enhanced description with research
    const enhancedDescription = `${primaryDeckContent.description}\n\n🔥 ${researchedTopic.trendingReason}\n\n💡 ${researchedTopic.whyItWorks}`;
    
    // Save ONE deck to Firestore with research metadata
    onProgress?.(`\n💾 Saving researched deck with metadata...`);
    const deckData = {
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
      colorValue: finalColorValue,
      colorExtractedFromImage: !!extractedColorValue, // Flag to indicate color was extracted from image
      imageUrl: imageUrl || null,
      isPremium: researchedTopic.isPremium || false,
      countries: countryCodes,
      country: countryCodes[0],
      tags: [...(primaryDeckContent.suggestedTags || []), 'researched', 'premium-quality', 'multi-difficulty'],
      priority: 0,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
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
    
    const docRef = await addDoc(collection(db, 'decks'), deckData);
    deckIds.push(docRef.id);
    
    generatedDecks.push({
      id: docRef.id,
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
    if (!topic) {
      onProgress?.('🔥 Generating AMAZING trending topic with AI...');
      
      const primaryCountry = countries.find(c => c.code !== 'UNIVERSAL') || countries[0];
      
      // Generate multiple topics and validate them
      const maxAttempts = 3; // Try up to 3 times to get a quality topic
      let validatedTopic: AIGeneratedTopic | null = null;
      
      for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          onProgress?.(`   Attempt ${attempt}/${maxAttempts}: Generating topic candidates...`);
          
          // Generate 3 topics to choose from
          let candidateTopics: AIGeneratedTopic[];
          
          if (primaryCountry.code === 'UNIVERSAL') {
            // For universal, generate one topic at a time
            candidateTopics = [await generateUniversalTopic()];
          } else {
            // Generate multiple topics for the country
            candidateTopics = await generateTrendingTopics(primaryCountry, 3);
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
    let extractedColorValue: number | undefined;
    
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
          
          // Generate image once with country context
          try {
            onProgress?.(`   🎨 Generating deck image...`);
            const topicWithContext = countryContext ? `${topic.name} (${countryContext})` : topic.name;
            imageUrl = await generateDeckImage(topicWithContext);
            onProgress?.(`   ✅ Image generated`);
            
            // Extract dominant color from the generated image
            if (imageUrl) {
              try {
                onProgress?.(`   🎨 Extracting dominant color from image...`);
                const primaryColor = await extractPrimaryColor(imageUrl);
                extractedColorValue = primaryColor.colorValue;
                onProgress?.(`   ✅ Color extracted: ${primaryColor.name} (${primaryColor.hex})`);
              } catch (colorError) {
                console.warn('Color extraction failed, using fallback:', colorError);
                const fallbackColor = getRandomVibrantColor();
                extractedColorValue = fallbackColor.colorValue;
                onProgress?.(`   ⚠️ Using fallback color: ${fallbackColor.name}`);
              }
            }
          } catch (imageError) {
            console.warn('Image generation failed, continuing without image:', imageError);
            onProgress?.(`   ⚠️ Image generation failed, continuing...`);
          }
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
    
    // Use extracted color from image, or fall back to AI suggestion, or default purple
    const finalColorValue = extractedColorValue || primaryDeckContent.colorSuggestion || 0xFF9C27B0;
    
    // Save ONE deck to Firestore with all difficulty modes
    onProgress?.(`\n💾 Saving deck with 3 difficulty modes...`);
    const deckData = {
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
      colorValue: finalColorValue,
      colorExtractedFromImage: !!extractedColorValue, // Flag to indicate color was extracted from image
      imageUrl: imageUrl || null,
      isPremium: topic.isPremium || false,
      countries: countryCodes,
      country: countryCodes[0],
      tags: [...(primaryDeckContent.suggestedTags || []), 'multi-difficulty'],
      priority: 0,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      generatedByAI: true,
      automatedGeneration: true,
      generationTopic: topic.name,
      generationCategory: topic.category,
      baseTopic: topic.name
    };
    
    const docRef = await addDoc(collection(db, 'decks'), deckData);
    deckIds.push(docRef.id);
    
    generatedDecks.push({
      id: docRef.id,
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


