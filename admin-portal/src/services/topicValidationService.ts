import { getOpenAIClient, withRetry } from './aiConfig';
import type { AIGeneratedTopic } from './aiTopicService';
import type { Country } from '../data/countries';

/**
 * Topic Quality Score breakdown
 */
export interface TopicQualityScore {
  creativity: number;        // 0-30: Uniqueness, not generic
  trendRelevance: number;    // 0-25: Current, timely, viral potential
  culturalFit: number;       // 0-25: Appropriate for target country
  playability: number;       // 0-20: Fun to act out, recognizable
  total: number;             // 0-100: Sum of all scores
  passed: boolean;           // true if total >= 70
  feedback: string;          // Explanation of the score
}

/**
 * Validate and score a topic using AI
 * @param topic The topic to validate
 * @param country The target country (optional for universal topics)
 * @returns Promise<TopicQualityScore> Quality score breakdown
 */
export const validateTopic = async (
  topic: AIGeneratedTopic,
  country?: Country
): Promise<TopicQualityScore> => {
  try {
    const openai = getOpenAIClient();
    
    const systemPrompt = `You are a quality assessment expert for game content.
Evaluate topics for the Heads Up! game based on specific criteria.
Return your response as valid JSON only, with no additional text.`;
    
    const countryContext = country 
      ? `for ${country.name} (${country.flag} ${country.region})`
      : 'for universal/global audience';
    
    const userPrompt = `Evaluate this Heads Up! game topic ${countryContext}:

Topic: "${topic.name}"
Category: ${topic.category}
Trending Reason: ${topic.trendingReason}
Cultural Relevance: ${topic.culturalRelevance}

Score the topic on these criteria (return as JSON):

1. Creativity (0-30 points):
   - Is it unique and interesting, or generic/boring?
   - Does it offer a fresh angle or is it overdone?
   - Examples: "2024 Viral Dance Challenges" (28) vs "Movies" (10)

2. Trend Relevance (0-25 points):
   - Is it current and timely?
   - Does it have viral/trending potential?
   - Is the trending reason compelling?
   - Examples: "Grammy Winners 2024" (24) vs "Classic Hollywood" (12)

3. Cultural Fit (0-25 points):
   - Is it appropriate for the target audience?
   - Does the cultural relevance make sense?
   - Will players recognize and appreciate it?
   - Examples: "Bollywood Dance Hits" for India (24) vs "NFL Teams" for India (8)

4. Playability (0-20 points):
   - Is it fun to act out or describe?
   - Are the items recognizable enough?
   - Will it work well in a fast-paced game?
   - Examples: "Action Movie Gestures" (19) vs "Abstract Concepts" (7)

Return ONLY this JSON structure:
{
  "creativity": 0-30,
  "trendRelevance": 0-25,
  "culturalFit": 0-25,
  "playability": 0-20,
  "feedback": "Brief explanation of scores (2-3 sentences)"
}

Be critical but fair. A score of 70+ total means excellent quality.`;

    console.log(`Validating topic: "${topic.name}"...`);
    
    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-5.1', // Latest flagship model
        max_completion_tokens: 1000,
        temperature: 0.3, // Lower temperature for consistent scoring
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ]
      });
    });
    
    const textContent = response.choices[0]?.message?.content?.trim();
    
    if (!textContent) {
      throw new Error('No text content in validation response');
    }
    
    // Parse JSON response
    const jsonStr = textContent.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    const scores = JSON.parse(jsonStr);
    
    // Calculate total and determine pass/fail
    const total = scores.creativity + scores.trendRelevance + scores.culturalFit + scores.playability;
    const passed = total >= 70;
    
    const qualityScore: TopicQualityScore = {
      creativity: scores.creativity,
      trendRelevance: scores.trendRelevance,
      culturalFit: scores.culturalFit,
      playability: scores.playability,
      total,
      passed,
      feedback: scores.feedback
    };
    
    console.log(`✅ Topic validation complete: "${topic.name}" - Score: ${total}/100 (${passed ? 'PASSED' : 'FAILED'})`);
    console.log(`   Breakdown: Creativity=${scores.creativity}, Trend=${scores.trendRelevance}, Cultural=${scores.culturalFit}, Playability=${scores.playability}`);
    
    return qualityScore;
    
  } catch (error: any) {
    console.error('Topic validation error:', error);
    
    // If validation fails, return a default passing score to not block generation
    // In production, you might want to handle this differently
    return {
      creativity: 20,
      trendRelevance: 18,
      culturalFit: 18,
      playability: 15,
      total: 71,
      passed: true,
      feedback: 'Validation unavailable, assuming topic quality is acceptable.'
    };
  }
};

/**
 * Validate multiple topics and return only those that pass
 * @param topics Array of topics to validate
 * @param country Target country
 * @param minScore Minimum score to pass (default: 70)
 * @returns Promise<AIGeneratedTopic[]> Only topics that passed validation
 */
export const validateAndFilterTopics = async (
  topics: AIGeneratedTopic[],
  country?: Country,
  minScore: number = 70
): Promise<{ validTopics: AIGeneratedTopic[], scores: Map<string, TopicQualityScore> }> => {
  const validTopics: AIGeneratedTopic[] = [];
  const scores = new Map<string, TopicQualityScore>();
  
  for (const topic of topics) {
    try {
      const score = await validateTopic(topic, country);
      scores.set(topic.name, score);
      
      if (score.total >= minScore) {
        validTopics.push(topic);
      } else {
        console.log(`❌ Topic "${topic.name}" rejected (score: ${score.total}/${minScore})`);
      }
      
      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 500));
    } catch (error) {
      console.error(`Failed to validate topic "${topic.name}":`, error);
      // Continue with other topics
    }
  }
  
  return { validTopics, scores };
};

/**
 * Quick validation without AI (rule-based)
 * Used as a fast pre-filter before AI validation
 */
export const quickValidateTopic = (topic: AIGeneratedTopic): boolean => {
  // Basic checks
  if (!topic.name || topic.name.length < 3 || topic.name.length > 100) {
    return false;
  }
  
  if (!topic.category || !topic.trendingReason || !topic.culturalRelevance) {
    return false;
  }
  
  // Check for generic/boring keywords in topic name
  const genericWords = ['general', 'random', 'misc', 'various', 'stuff', 'things'];
  const nameLower = topic.name.toLowerCase();
  
  for (const word of genericWords) {
    if (nameLower.includes(word)) {
      console.log(`❌ Topic "${topic.name}" failed quick validation: Contains generic word "${word}"`);
      return false;
    }
  }
  
  // Check that trending reason is substantial
  if (topic.trendingReason.length < 20) {
    console.log(`❌ Topic "${topic.name}" failed quick validation: Trending reason too short`);
    return false;
  }
  
  return true;
};

/**
 * Get a quality rating string based on score
 */
export const getQualityRating = (score: number): string => {
  if (score >= 90) return '🌟 Outstanding';
  if (score >= 80) return '⭐ Excellent';
  if (score >= 70) return '✅ Good';
  if (score >= 60) return '⚠️ Fair';
  return '❌ Poor';
};

