// Example usage of the updated aiImageService with OpenAI Image API

import { generateDeckImage, generateImageVariations, DallE3Options } from './aiImageService';

/**
 * EXAMPLE 1: Basic Usage (with defaults)
 * - Quality: standard
 * - Size: 1024x1792 (portrait)
 * - Style: vivid
 * - Response format: url
 */
async function example1_BasicUsage() {
  const imageUrl = await generateDeckImage('Famous Athletes');
  console.log('Generated image URL:', imageUrl);
}

/**
 * EXAMPLE 2: High-Quality Image Generation
 * Use 'high' quality for better detail (costs more)
 */
async function example2_HighQuality() {
  const options: DallE3Options = {
    quality: 'high', // High definition for premium quality
  };
  
  const imageUrl = await generateDeckImage(
    'Famous Athletes',
    'premium luxury',
    options
  );
  console.log('HD image URL:', imageUrl);
}

/**
 * EXAMPLE 3: Natural Style (more realistic)
 * Use modern clean style for contemporary results
 */
async function example3_NaturalStyle() {
  const options: DallE3Options = {
    quality: 'medium'
  };
  
  const imageUrl = await generateDeckImage(
    'World Landmarks',
    'sleek modern',
    options
  );
  console.log('Modern style image URL:', imageUrl);
}

/**
 * EXAMPLE 4: Square Images
 * Generate 1024x1024 square images instead of portrait
 */
async function example4_SquareImages() {
  const options: DallE3Options = {
    size: '1024x1024' // Square format
  };
  
  const imageUrl = await generateDeckImage(
    'Space Exploration',
    'cinematic dramatic',
    options
  );
  console.log('Square image URL:', imageUrl);
}

/**
 * EXAMPLE 5: Landscape Images
 * Generate 1536x1024 landscape images
 */
async function example5_LandscapeImages() {
  const options: DallE3Options = {
    size: '1536x1024' // Landscape format
  };
  
  const imageUrl = await generateDeckImage(
    'Movie Quotes',
    'sleek modern',
    options
  );
  console.log('Landscape image URL:', imageUrl);
}

/**
 * EXAMPLE 6: Base64 Response Format
 * Get image as base64 JSON instead of URL
 * (useful for immediate processing without downloading)
 */
async function example6_Base64Response() {
  const options: DallE3Options = {
    quality: 'medium'
  };
  
  const imageUrl = await generateDeckImage(
    'Historical Figures',
    'premium luxury',
    options
  );
  console.log('Image uploaded to Firebase:', imageUrl);
}

/**
 * EXAMPLE 7: Multiple Variations
 * Generate 3 different style variations of the same topic
 */
async function example7_MultipleVariations() {
  const options: DallE3Options = {
    quality: 'medium'
  };
  
  // Generates 3 variations: sleek modern, bold dynamic, premium luxury
  const imageUrls = await generateImageVariations(
    'Famous Athletes',
    3,
    options
  );
  
  console.log('Variation 1 (sleek modern):', imageUrls[0]);
  console.log('Variation 2 (bold dynamic):', imageUrls[1]);
  console.log('Variation 3 (premium luxury):', imageUrls[2]);
}

/**
 * EXAMPLE 8: Premium Configuration
 * High-quality for premium content
 */
async function example8_PremiumConfig() {
  const options: DallE3Options = {
    quality: 'high',     // Best quality
    size: '1024x1536'    // Portrait for mobile
  };
  
  const imageUrl = await generateDeckImage(
    'Music Legends',
    'premium luxury',
    options
  );
  console.log('Premium image URL:', imageUrl);
}

/**
 * EXAMPLE 9: Budget-Friendly Configuration
 * Standard quality for cost optimization
 */
async function example9_BudgetFriendly() {
  const options: DallE3Options = {
    quality: 'medium',   // Lower cost
    size: '1024x1024'    // Smaller size
  };
  
  const imageUrl = await generateDeckImage(
    'Science Trivia',
    'sleek modern',
    options
  );
  console.log('Budget-friendly image URL:', imageUrl);
}

/**
 * EXAMPLE 10: Error Handling
 * Handle generation failures gracefully
 */
async function example10_ErrorHandling() {
  try {
    const options: DallE3Options = {
      quality: 'high'
    };
    
    const imageUrl = await generateDeckImage(
      'Tech Innovations',
      'bold dynamic',
      options
    );
    
    console.log('Success! Image URL:', imageUrl);
  } catch (error) {
    console.error('Image generation failed:', error);
    
    // Fallback to a default image
    const defaultImageUrl = 'https://via.placeholder.com/1024x1365/9C27B0/ffffff?text=Heads+Up!';
    console.log('Using fallback image:', defaultImageUrl);
  }
}

/**
 * EXAMPLE 11: Batch Generation with Different Configs
 * Generate multiple images with different configurations
 */
async function example11_BatchGeneration() {
  const topics = [
    { name: 'Famous Athletes', style: 'bold dynamic' },
    { name: 'Movie Stars', style: 'sleek modern' },
    { name: 'Tech Companies', style: 'cinematic dramatic' }
  ];
  
  const standardOptions: DallE3Options = { quality: 'medium' };
  const hdOptions: DallE3Options = { quality: 'high' };
  
  // Generate standard quality for first two
  const standardImages = await Promise.all([
    generateDeckImage(topics[0].name, topics[0].style, standardOptions),
    generateDeckImage(topics[1].name, topics[1].style, standardOptions)
  ]);
  
  // Generate HD quality for premium topic
  const hdImage = await generateDeckImage(
    topics[2].name,
    topics[2].style,
    hdOptions
  );
  
  console.log('Standard images:', standardImages);
  console.log('HD image:', hdImage);
}

/**
 * EXAMPLE 12: A/B Testing Different Styles
 * Generate the same topic with different style parameters
 */
async function example12_ABTesting() {
  const topic = 'Famous Athletes';
  
  // Test A: Bold Dynamic style
  const boldImage = await generateDeckImage(topic, 'bold dynamic', {
    quality: 'medium'
  });
  
  // Test B: Sleek Modern style
  const modernImage = await generateDeckImage(topic, 'sleek modern', {
    quality: 'medium'
  });
  
  console.log('Bold Dynamic style:', boldImage);
  console.log('Sleek Modern style:', modernImage);
  
  // User feedback can determine which style performs better
}

// Export all examples
export {
  example1_BasicUsage,
  example2_HighQuality,
  example3_NaturalStyle,
  example4_SquareImages,
  example5_LandscapeImages,
  example6_Base64Response,
  example7_MultipleVariations,
  example8_PremiumConfig,
  example9_BudgetFriendly,
  example10_ErrorHandling,
  example11_BatchGeneration,
  example12_ABTesting
};

