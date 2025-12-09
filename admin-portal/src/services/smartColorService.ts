/**
 * Smart Color Service
 * Intelligently selects vibrant, varied colors for decks based on topics
 * Then coordinates with image generation to create matching visuals
 */

export interface SmartColor {
  name: string;
  hex: string;
  colorValue: number; // Flutter-compatible 0xAARRGGBB format
  promptDescription: string; // Description for image generation prompt
  category: string;
}

/**
 * Rich, vibrant color palette with variety
 * Each color has a prompt description for coordinating with image generation
 */
const VIBRANT_PALETTE: SmartColor[] = [
  // 🔵 Blues - Cool & Calm
  { name: 'Electric Blue', hex: '#0066FF', colorValue: 0xFF0066FF, promptDescription: 'electric blue and cyan', category: 'blue' },
  { name: 'Ocean Blue', hex: '#006994', colorValue: 0xFF006994, promptDescription: 'deep ocean blue and aqua', category: 'blue' },
  { name: 'Sky Blue', hex: '#00BFFF', colorValue: 0xFF00BFFF, promptDescription: 'bright sky blue and white', category: 'blue' },
  { name: 'Royal Blue', hex: '#4169E1', colorValue: 0xFF4169E1, promptDescription: 'royal blue and gold accents', category: 'blue' },
  { name: 'Sapphire', hex: '#0F52BA', colorValue: 0xFF0F52BA, promptDescription: 'sapphire blue with silver', category: 'blue' },
  
  // 🟢 Greens - Fresh & Natural
  { name: 'Emerald', hex: '#50C878', colorValue: 0xFF50C878, promptDescription: 'emerald green and gold', category: 'green' },
  { name: 'Forest Green', hex: '#228B22', colorValue: 0xFF228B22, promptDescription: 'deep forest green and earth tones', category: 'green' },
  { name: 'Lime', hex: '#32CD32', colorValue: 0xFF32CD32, promptDescription: 'vibrant lime green and black', category: 'green' },
  { name: 'Teal', hex: '#008080', colorValue: 0xFF008080, promptDescription: 'rich teal and turquoise', category: 'green' },
  { name: 'Mint', hex: '#3EB489', colorValue: 0xFF3EB489, promptDescription: 'fresh mint green and white', category: 'green' },
  
  // 🟠 Oranges - Warm & Energetic
  { name: 'Tangerine', hex: '#FF9966', colorValue: 0xFFFF9966, promptDescription: 'warm tangerine orange and coral', category: 'orange' },
  { name: 'Sunset Orange', hex: '#FF6B35', colorValue: 0xFFFF6B35, promptDescription: 'sunset orange and golden yellow', category: 'orange' },
  { name: 'Amber', hex: '#FFBF00', colorValue: 0xFFFFBF00, promptDescription: 'rich amber gold and bronze', category: 'orange' },
  { name: 'Copper', hex: '#B87333', colorValue: 0xFFB87333, promptDescription: 'warm copper and metallic gold', category: 'orange' },
  { name: 'Peach', hex: '#FFCBA4', colorValue: 0xFFFFCBA4, promptDescription: 'soft peach and cream tones', category: 'orange' },
  
  // 🟡 Yellows - Bright & Cheerful
  { name: 'Golden Yellow', hex: '#FFD700', colorValue: 0xFFFFD700, promptDescription: 'brilliant golden yellow', category: 'yellow' },
  { name: 'Canary', hex: '#FFEF00', colorValue: 0xFFFFEF00, promptDescription: 'bright canary yellow and black', category: 'yellow' },
  { name: 'Honey', hex: '#EB9605', colorValue: 0xFFEB9605, promptDescription: 'warm honey gold and amber', category: 'yellow' },
  { name: 'Lemon', hex: '#FFF44F', colorValue: 0xFFFFF44F, promptDescription: 'zesty lemon yellow and green', category: 'yellow' },
  
  // 🔴 Reds - Bold & Passionate (but varied!)
  { name: 'Crimson', hex: '#DC143C', colorValue: 0xFFDC143C, promptDescription: 'deep crimson red and black', category: 'red' },
  { name: 'Cherry', hex: '#DE3163', colorValue: 0xFFDE3163, promptDescription: 'cherry red and cream', category: 'red' },
  { name: 'Scarlet', hex: '#FF2400', colorValue: 0xFFFF2400, promptDescription: 'bold scarlet and gold', category: 'red' },
  { name: 'Coral', hex: '#FF7F50', colorValue: 0xFFFF7F50, promptDescription: 'warm coral and turquoise', category: 'red' },
  
  // 🟣 Purples - Royal & Creative (varied shades!)
  { name: 'Violet', hex: '#8B00FF', colorValue: 0xFF8B00FF, promptDescription: 'rich violet and silver', category: 'purple' },
  { name: 'Amethyst', hex: '#9966CC', colorValue: 0xFF9966CC, promptDescription: 'amethyst purple and gold', category: 'purple' },
  { name: 'Grape', hex: '#6F2DA8', colorValue: 0xFF6F2DA8, promptDescription: 'deep grape purple and pink', category: 'purple' },
  { name: 'Lavender', hex: '#B57EDC', colorValue: 0xFFB57EDC, promptDescription: 'soft lavender and white', category: 'purple' },
  { name: 'Plum', hex: '#8E4585', colorValue: 0xFF8E4585, promptDescription: 'plum purple and cream', category: 'purple' },
  
  // 🩷 Pinks - Fun & Playful (limited use!)
  { name: 'Hot Pink', hex: '#FF69B4', colorValue: 0xFFFF69B4, promptDescription: 'hot pink and electric blue', category: 'pink' },
  { name: 'Magenta', hex: '#FF00FF', colorValue: 0xFFFF00FF, promptDescription: 'vibrant magenta and cyan', category: 'pink' },
  { name: 'Rose', hex: '#FF007F', colorValue: 0xFFFF007F, promptDescription: 'rose pink and gold', category: 'pink' },
  
  // 🤎 Earth Tones - Grounded & Sophisticated
  { name: 'Chocolate', hex: '#7B3F00', colorValue: 0xFF7B3F00, promptDescription: 'rich chocolate brown and cream', category: 'brown' },
  { name: 'Sienna', hex: '#A0522D', colorValue: 0xFFA0522D, promptDescription: 'warm sienna and terracotta', category: 'brown' },
  { name: 'Bronze', hex: '#CD7F32', colorValue: 0xFFCD7F32, promptDescription: 'metallic bronze and gold', category: 'brown' },
  
  // ⚫ Dark & Dramatic
  { name: 'Charcoal', hex: '#36454F', colorValue: 0xFF36454F, promptDescription: 'sleek charcoal and silver', category: 'dark' },
  { name: 'Navy', hex: '#000080', colorValue: 0xFF000080, promptDescription: 'deep navy and gold trim', category: 'dark' },
  { name: 'Midnight', hex: '#191970', colorValue: 0xFF191970, promptDescription: 'midnight blue with stars', category: 'dark' },
  
  // 🌈 Special & Unique
  { name: 'Turquoise', hex: '#40E0D0', colorValue: 0xFF40E0D0, promptDescription: 'tropical turquoise and coral', category: 'special' },
  { name: 'Cyan', hex: '#00FFFF', colorValue: 0xFF00FFFF, promptDescription: 'neon cyan and magenta', category: 'special' },
  { name: 'Vermillion', hex: '#E34234', colorValue: 0xFFE34234, promptDescription: 'vermillion orange-red and black', category: 'special' },
  { name: 'Indigo', hex: '#4B0082', colorValue: 0xFF4B0082, promptDescription: 'deep indigo and starlight', category: 'special' },
  { name: 'Chartreuse', hex: '#7FFF00', colorValue: 0xFF7FFF00, promptDescription: 'electric chartreuse and black', category: 'special' },
];

/**
 * Topic-to-color category mapping
 * Maps keywords to preferred color categories for variety
 */
const TOPIC_COLOR_PREFERENCES: Record<string, string[]> = {
  // Entertainment
  'movie': ['blue', 'red', 'dark', 'special'],
  'film': ['dark', 'red', 'blue', 'special'],
  'cinema': ['dark', 'red', 'purple', 'special'],
  'streaming': ['red', 'blue', 'dark', 'special'],
  'netflix': ['red', 'dark'],
  'disney': ['blue', 'purple', 'special'],
  'anime': ['pink', 'purple', 'blue', 'special'],
  'cartoon': ['yellow', 'blue', 'green', 'special'],
  
  // Music
  'music': ['purple', 'blue', 'pink', 'special'],
  'song': ['purple', 'blue', 'orange', 'special'],
  'singer': ['purple', 'pink', 'blue', 'special'],
  'concert': ['purple', 'pink', 'blue', 'dark'],
  'band': ['dark', 'red', 'purple', 'special'],
  'kpop': ['pink', 'purple', 'blue', 'special'],
  'hiphop': ['dark', 'yellow', 'red', 'special'],
  'rock': ['dark', 'red', 'purple', 'special'],
  
  // Sports
  'sport': ['blue', 'green', 'red', 'orange'],
  'football': ['green', 'brown', 'blue', 'red'],
  'soccer': ['green', 'blue', 'orange', 'red'],
  'basketball': ['orange', 'red', 'blue', 'dark'],
  'cricket': ['green', 'blue', 'orange', 'brown'],
  'tennis': ['green', 'yellow', 'blue', 'special'],
  'golf': ['green', 'blue', 'brown', 'special'],
  'swimming': ['blue', 'special', 'green'],
  'olympics': ['blue', 'yellow', 'red', 'green'],
  
  // Gaming
  'game': ['purple', 'blue', 'green', 'special'],
  'gaming': ['purple', 'green', 'blue', 'special'],
  'esport': ['purple', 'blue', 'dark', 'special'],
  'fortnite': ['purple', 'blue', 'special'],
  'minecraft': ['green', 'brown', 'blue'],
  'playstation': ['blue', 'dark', 'special'],
  'xbox': ['green', 'dark', 'special'],
  'nintendo': ['red', 'blue', 'yellow', 'special'],
  
  // Food
  'food': ['orange', 'red', 'yellow', 'green'],
  'cook': ['orange', 'red', 'yellow', 'brown'],
  'restaurant': ['brown', 'red', 'orange', 'green'],
  'pizza': ['red', 'orange', 'yellow', 'green'],
  'sushi': ['red', 'orange', 'green', 'dark'],
  'dessert': ['pink', 'brown', 'orange', 'special'],
  'coffee': ['brown', 'orange', 'green'],
  'fruit': ['orange', 'yellow', 'red', 'green'],
  
  // Nature & Animals
  'animal': ['green', 'brown', 'orange', 'blue'],
  'nature': ['green', 'blue', 'brown', 'special'],
  'ocean': ['blue', 'special', 'green'],
  'forest': ['green', 'brown', 'dark'],
  'safari': ['brown', 'orange', 'yellow', 'green'],
  'bird': ['blue', 'green', 'yellow', 'orange'],
  'fish': ['blue', 'special', 'green', 'orange'],
  'dog': ['brown', 'orange', 'blue', 'green'],
  'cat': ['orange', 'brown', 'purple', 'special'],
  
  // Travel & Places
  'travel': ['blue', 'green', 'orange', 'special'],
  'country': ['blue', 'green', 'red', 'special'],
  'city': ['dark', 'blue', 'orange', 'special'],
  'beach': ['blue', 'special', 'yellow', 'orange'],
  'mountain': ['blue', 'green', 'brown', 'dark'],
  'japan': ['red', 'pink', 'dark', 'special'],
  'india': ['orange', 'red', 'yellow', 'green'],
  'usa': ['blue', 'red', 'dark'],
  'europe': ['blue', 'green', 'brown', 'special'],
  
  // Technology
  'tech': ['blue', 'dark', 'special', 'purple'],
  'ai': ['special', 'blue', 'purple', 'dark'],
  'robot': ['special', 'blue', 'dark', 'purple'],
  'computer': ['blue', 'dark', 'special'],
  'phone': ['dark', 'blue', 'special', 'purple'],
  'social': ['blue', 'special', 'pink', 'purple'],
  'viral': ['special', 'pink', 'dark'],
  'instagram': ['pink', 'purple', 'orange', 'special'],
  
  // Celebrities & People
  'celebrity': ['purple', 'blue', 'special', 'dark'],
  'actor': ['dark', 'red', 'blue', 'purple'],
  'actress': ['purple', 'pink', 'blue', 'special'],
  'star': ['yellow', 'purple', 'blue', 'special'],
  'famous': ['purple', 'blue', 'dark', 'special'],
  
  // Fun & Party
  'party': ['pink', 'purple', 'special', 'yellow'],
  'fun': ['yellow', 'orange', 'pink', 'special'],
  'dance': ['pink', 'purple', 'special', 'yellow'],
  'festival': ['purple', 'pink', 'orange', 'special'],
  'holiday': ['red', 'green', 'yellow', 'special'],
  'christmas': ['red', 'green', 'yellow'],
  'halloween': ['orange', 'purple', 'dark', 'special'],
  'birthday': ['pink', 'purple', 'yellow', 'special'],
  
  // Education & Knowledge
  'science': ['blue', 'green', 'special', 'purple'],
  'history': ['brown', 'dark', 'blue', 'orange'],
  'geography': ['green', 'blue', 'brown', 'special'],
  'trivia': ['purple', 'blue', 'yellow', 'special'],
  'quiz': ['purple', 'blue', 'yellow', 'special'],
};

/**
 * Track recently used colors to ensure variety
 */
let recentlyUsedColors: string[] = [];
const MAX_RECENT_COLORS = 8; // Don't repeat same color in last 8 decks

/**
 * Get colors from preferred categories for a topic
 */
const getColorsForTopic = (topic: string): SmartColor[] => {
  const topicLower = topic.toLowerCase();
  let preferredCategories: string[] = [];
  
  // Find matching topic preferences
  for (const [keyword, categories] of Object.entries(TOPIC_COLOR_PREFERENCES)) {
    if (topicLower.includes(keyword)) {
      preferredCategories = [...new Set([...preferredCategories, ...categories])];
    }
  }
  
  // If no preferences found, use all categories
  if (preferredCategories.length === 0) {
    preferredCategories = ['blue', 'green', 'orange', 'yellow', 'purple', 'special'];
  }
  
  // Get colors from preferred categories
  return VIBRANT_PALETTE.filter(color => preferredCategories.includes(color.category));
};

/**
 * Select a smart color for a deck topic
 * Ensures variety by avoiding recently used colors
 * @param topic The deck topic/theme
 * @returns SmartColor The selected color with all metadata
 */
export const selectSmartColor = (topic: string): SmartColor => {
  // Get colors appropriate for this topic
  const topicColors = getColorsForTopic(topic);
  
  // Filter out recently used colors
  const availableColors = topicColors.filter(
    color => !recentlyUsedColors.includes(color.name)
  );
  
  // If all colors were recently used, reset and use all topic colors
  const colorsToChooseFrom = availableColors.length > 0 ? availableColors : topicColors;
  
  // Randomly select from available colors
  const selectedIndex = Math.floor(Math.random() * colorsToChooseFrom.length);
  const selectedColor = colorsToChooseFrom[selectedIndex];
  
  // Track this color as recently used
  recentlyUsedColors.unshift(selectedColor.name);
  if (recentlyUsedColors.length > MAX_RECENT_COLORS) {
    recentlyUsedColors = recentlyUsedColors.slice(0, MAX_RECENT_COLORS);
  }
  
  console.log(`🎨 Smart color selected for "${topic}": ${selectedColor.name} (${selectedColor.hex})`);
  console.log(`   Color palette for image: ${selectedColor.promptDescription}`);
  
  return selectedColor;
};

/**
 * Get the color prompt description for image generation
 * This should be incorporated into the image generation prompt
 */
export const getColorPromptForImage = (color: SmartColor): string => {
  return `COLOR PALETTE: Use ${color.promptDescription} as the dominant colors. Make the overall image match this ${color.name} color scheme.`;
};

/**
 * Reset the recently used colors (for testing)
 */
export const resetRecentColors = (): void => {
  recentlyUsedColors = [];
};

/**
 * Get all available colors (for debugging/display)
 */
export const getAllColors = (): SmartColor[] => {
  return [...VIBRANT_PALETTE];
};

/**
 * Get a specific color by name
 */
export const getColorByName = (name: string): SmartColor | undefined => {
  return VIBRANT_PALETTE.find(c => c.name.toLowerCase() === name.toLowerCase());
};

export { VIBRANT_PALETTE };



