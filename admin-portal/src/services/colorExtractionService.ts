/**
 * Color Extraction Service
 * Extracts dominant colors from AI-generated deck images
 * The extracted color is used as the deck's primary color
 */

interface RGB {
  r: number;
  g: number;
  b: number;
}

interface ColorResult {
  hex: string;
  rgb: RGB;
  colorValue: number; // Flutter-compatible 0xAARRGGBB format
  vibrance: number;
  name: string; // Descriptive color name
}

/**
 * COMPREHENSIVE Color Palette for deck cards
 * Includes Material, Vibrant colors
 * RANDOMIZED selection to ensure variety
 */

// Material Colors (16)
const MATERIAL_COLORS: ColorResult[] = [
  { hex: '#F44336', rgb: { r: 244, g: 67, b: 54 }, colorValue: 0xFFF44336, vibrance: 1, name: 'Red' },
  { hex: '#E91E63', rgb: { r: 233, g: 30, b: 99 }, colorValue: 0xFFE91E63, vibrance: 1, name: 'Pink' },
  { hex: '#9C27B0', rgb: { r: 156, g: 39, b: 176 }, colorValue: 0xFF9C27B0, vibrance: 1, name: 'Purple' },
  { hex: '#673AB7', rgb: { r: 103, g: 58, b: 183 }, colorValue: 0xFF673AB7, vibrance: 1, name: 'Deep Purple' },
  { hex: '#3F51B5', rgb: { r: 63, g: 81, b: 181 }, colorValue: 0xFF3F51B5, vibrance: 1, name: 'Indigo' },
  { hex: '#2196F3', rgb: { r: 33, g: 150, b: 243 }, colorValue: 0xFF2196F3, vibrance: 1, name: 'Blue' },
  { hex: '#03A9F4', rgb: { r: 3, g: 169, b: 244 }, colorValue: 0xFF03A9F4, vibrance: 1, name: 'Light Blue' },
  { hex: '#00BCD4', rgb: { r: 0, g: 188, b: 212 }, colorValue: 0xFF00BCD4, vibrance: 1, name: 'Cyan' },
  { hex: '#009688', rgb: { r: 0, g: 150, b: 136 }, colorValue: 0xFF009688, vibrance: 1, name: 'Teal' },
  { hex: '#4CAF50', rgb: { r: 76, g: 175, b: 80 }, colorValue: 0xFF4CAF50, vibrance: 1, name: 'Green' },
  { hex: '#8BC34A', rgb: { r: 139, g: 195, b: 74 }, colorValue: 0xFF8BC34A, vibrance: 1, name: 'Light Green' },
  { hex: '#CDDC39', rgb: { r: 205, g: 220, b: 57 }, colorValue: 0xFFCDDC39, vibrance: 1, name: 'Lime' },
  { hex: '#FFEB3B', rgb: { r: 255, g: 235, b: 59 }, colorValue: 0xFFFFEB3B, vibrance: 1, name: 'Yellow' },
  { hex: '#FFC107', rgb: { r: 255, g: 193, b: 7 }, colorValue: 0xFFFFC107, vibrance: 1, name: 'Amber' },
  { hex: '#FF9800', rgb: { r: 255, g: 152, b: 0 }, colorValue: 0xFFFF9800, vibrance: 1, name: 'Orange' },
  { hex: '#FF5722', rgb: { r: 255, g: 87, b: 34 }, colorValue: 0xFFFF5722, vibrance: 1, name: 'Deep Orange' },
];

// Vibrant Colors (12)
const VIBRANT_COLORS: ColorResult[] = [
  { hex: '#FF006E', rgb: { r: 255, g: 0, b: 110 }, colorValue: 0xFFFF006E, vibrance: 1, name: 'Hot Pink' },
  { hex: '#FB5607', rgb: { r: 251, g: 86, b: 7 }, colorValue: 0xFFFB5607, vibrance: 1, name: 'Vibrant Orange' },
  { hex: '#FFBE0B', rgb: { r: 255, g: 190, b: 11 }, colorValue: 0xFFFFBE0B, vibrance: 1, name: 'Golden Yellow' },
  { hex: '#8338EC', rgb: { r: 131, g: 56, b: 236 }, colorValue: 0xFF8338EC, vibrance: 1, name: 'Electric Purple' },
  { hex: '#3A86FF', rgb: { r: 58, g: 134, b: 255 }, colorValue: 0xFF3A86FF, vibrance: 1, name: 'Bright Blue' },
  { hex: '#06FFB4', rgb: { r: 6, g: 255, b: 180 }, colorValue: 0xFF06FFB4, vibrance: 1, name: 'Neon Mint' },
  { hex: '#FF4365', rgb: { r: 255, g: 67, b: 101 }, colorValue: 0xFFFF4365, vibrance: 1, name: 'Coral Red' },
  { hex: '#00D9FF', rgb: { r: 0, g: 217, b: 255 }, colorValue: 0xFF00D9FF, vibrance: 1, name: 'Cyan Blue' },
  { hex: '#FFC300', rgb: { r: 255, g: 195, b: 0 }, colorValue: 0xFFFFC300, vibrance: 1, name: 'Bright Gold' },
  { hex: '#FF5E5B', rgb: { r: 255, g: 94, b: 91 }, colorValue: 0xFFFF5E5B, vibrance: 1, name: 'Salmon Red' },
  { hex: '#23F0C7', rgb: { r: 35, g: 240, b: 199 }, colorValue: 0xFF23F0C7, vibrance: 1, name: 'Turquoise' },
  { hex: '#FFD23F', rgb: { r: 255, g: 210, b: 63 }, colorValue: 0xFFFFD23F, vibrance: 1, name: 'Sunny Yellow' },
];

// Pastel Colors (12) - softer, lighter options
const PASTEL_COLORS: ColorResult[] = [
  { hex: '#FFB3BA', rgb: { r: 255, g: 179, b: 186 }, colorValue: 0xFFFFB3BA, vibrance: 0.7, name: 'Pastel Pink' },
  { hex: '#FFDFBA', rgb: { r: 255, g: 223, b: 186 }, colorValue: 0xFFFFDFBA, vibrance: 0.7, name: 'Pastel Peach' },
  { hex: '#FFFFBA', rgb: { r: 255, g: 255, b: 186 }, colorValue: 0xFFFFFFBA, vibrance: 0.7, name: 'Pastel Yellow' },
  { hex: '#BAFFC9', rgb: { r: 186, g: 255, b: 201 }, colorValue: 0xFFBAFFC9, vibrance: 0.7, name: 'Pastel Green' },
  { hex: '#BAE1FF', rgb: { r: 186, g: 225, b: 255 }, colorValue: 0xFFBAE1FF, vibrance: 0.7, name: 'Pastel Blue' },
  { hex: '#E0BBE4', rgb: { r: 224, g: 187, b: 228 }, colorValue: 0xFFE0BBE4, vibrance: 0.7, name: 'Pastel Lavender' },
  { hex: '#FEC8D8', rgb: { r: 254, g: 200, b: 216 }, colorValue: 0xFFFEC8D8, vibrance: 0.7, name: 'Pastel Rose' },
  { hex: '#D4A5A5', rgb: { r: 212, g: 165, b: 165 }, colorValue: 0xFFD4A5A5, vibrance: 0.7, name: 'Pastel Mauve' },
  { hex: '#A8DADC', rgb: { r: 168, g: 218, b: 220 }, colorValue: 0xFFA8DADC, vibrance: 0.7, name: 'Pastel Teal' },
  { hex: '#E6F3FF', rgb: { r: 230, g: 243, b: 255 }, colorValue: 0xFFE6F3FF, vibrance: 0.7, name: 'Pastel Ice Blue' },
  { hex: '#FFF0F3', rgb: { r: 255, g: 240, b: 243 }, colorValue: 0xFFFFF0F3, vibrance: 0.7, name: 'Pastel Blush' },
  { hex: '#E8DFF5', rgb: { r: 232, g: 223, b: 245 }, colorValue: 0xFFE8DFF5, vibrance: 0.7, name: 'Pastel Lilac' },
];

// Combined palette - Material + Vibrant (Pastels excluded for better contrast)
const ALL_COLORS: ColorResult[] = [...MATERIAL_COLORS, ...VIBRANT_COLORS];

// All colors including pastels (for special use cases)
const ALL_COLORS_WITH_PASTELS: ColorResult[] = [...MATERIAL_COLORS, ...VIBRANT_COLORS, ...PASTEL_COLORS];

// Track recently used colors to ensure variety
let recentlyUsedColorIndices: number[] = [];
const MAX_RECENT_COLORS = 10; // Remember last 10 colors to avoid repetition

/**
 * Get a random color that hasn't been used recently
 * This ensures variety in deck colors
 */
const getRandomUniqueColor = (): ColorResult => {
  // Get available indices (not recently used)
  const availableIndices = ALL_COLORS
    .map((_, i) => i)
    .filter(i => !recentlyUsedColorIndices.includes(i));
  
  // If all colors have been used recently, reset the tracker
  if (availableIndices.length === 0) {
    recentlyUsedColorIndices = [];
    return ALL_COLORS[Math.floor(Math.random() * ALL_COLORS.length)];
  }
  
  // Pick a random available index
  const randomIndex = availableIndices[Math.floor(Math.random() * availableIndices.length)];
  
  // Track this color as recently used
  recentlyUsedColorIndices.push(randomIndex);
  if (recentlyUsedColorIndices.length > MAX_RECENT_COLORS) {
    recentlyUsedColorIndices.shift(); // Remove oldest
  }
  
  return ALL_COLORS[randomIndex];
};

/**
 * Convert RGB to HSL for color analysis
 */
const rgbToHsl = (r: number, g: number, b: number): { h: number; s: number; l: number } => {
  r /= 255;
  g /= 255;
  b /= 255;

  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h = 0;
  let s = 0;
  const l = (max + min) / 2;

  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

    switch (max) {
      case r:
        h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
        break;
      case g:
        h = ((b - r) / d + 2) / 6;
        break;
      case b:
        h = ((r - g) / d + 4) / 6;
        break;
    }
  }

  return { h: h * 360, s: s * 100, l: l * 100 };
};

/**
 * Calculate vibrance score for a color
 * Higher saturation and mid-range lightness = more vibrant
 */
const calculateVibrance = (rgb: RGB): number => {
  const { s, l } = rgbToHsl(rgb.r, rgb.g, rgb.b);
  
  // Penalize very dark or very light colors
  let lightnessPenalty = 1;
  if (l < 20) lightnessPenalty = l / 20;
  else if (l > 80) lightnessPenalty = (100 - l) / 20;
  
  // Saturation is the main driver of vibrance
  const saturationScore = s / 100;
  
  return saturationScore * lightnessPenalty;
};

/**
 * Get a descriptive name for a color based on its hue
 */
const getColorName = (rgb: RGB): string => {
  const { h, s, l } = rgbToHsl(rgb.r, rgb.g, rgb.b);
  
  // Handle grayscale
  if (s < 10) {
    if (l < 20) return 'Black';
    if (l > 80) return 'White';
    return 'Gray';
  }
  
  // Map hue to color names
  if (h < 15 || h >= 345) return 'Red';
  if (h < 45) return 'Orange';
  if (h < 70) return 'Yellow';
  if (h < 150) return 'Green';
  if (h < 195) return 'Cyan';
  if (h < 255) return 'Blue';
  if (h < 285) return 'Purple';
  if (h < 345) return 'Pink';
  
  return 'Unknown';
};

/**
 * Convert RGB to Flutter-compatible color value (0xAARRGGBB)
 */
const rgbToColorValue = (rgb: RGB): number => {
  return (0xFF << 24) | (rgb.r << 16) | (rgb.g << 8) | rgb.b;
};

/**
 * Convert RGB to hex string
 */
const rgbToHex = (rgb: RGB): string => {
  const toHex = (n: number) => n.toString(16).padStart(2, '0').toUpperCase();
  return `#${toHex(rgb.r)}${toHex(rgb.g)}${toHex(rgb.b)}`;
};

/**
 * Check if a color is too dark or too light
 */
const isColorUsable = (rgb: RGB): boolean => {
  const { s, l } = rgbToHsl(rgb.r, rgb.g, rgb.b);
  
  // Reject very dark colors (hard to see)
  if (l < 15) return false;
  
  // Reject very light colors (hard to see on white)
  if (l > 90) return false;
  
  // Reject very desaturated colors (boring)
  if (s < 15 && l > 30 && l < 70) return false;
  
  return true;
};

/**
 * Simple k-means clustering for color quantization
 */
const quantizeColors = (pixels: RGB[], numClusters: number = 5): RGB[] => {
  if (pixels.length === 0) return [];
  
  // Initialize clusters with random pixels
  const clusters: RGB[] = [];
  const step = Math.floor(pixels.length / numClusters);
  for (let i = 0; i < numClusters; i++) {
    const idx = Math.min(i * step, pixels.length - 1);
    clusters.push({ ...pixels[idx] });
  }
  
  // Run k-means iterations
  const maxIterations = 10;
  for (let iter = 0; iter < maxIterations; iter++) {
    // Assign pixels to nearest cluster
    const assignments: RGB[][] = clusters.map(() => []);
    
    for (const pixel of pixels) {
      let minDist = Infinity;
      let nearestCluster = 0;
      
      for (let i = 0; i < clusters.length; i++) {
        const dist = Math.sqrt(
          Math.pow(pixel.r - clusters[i].r, 2) +
          Math.pow(pixel.g - clusters[i].g, 2) +
          Math.pow(pixel.b - clusters[i].b, 2)
        );
        
        if (dist < minDist) {
          minDist = dist;
          nearestCluster = i;
        }
      }
      
      assignments[nearestCluster].push(pixel);
    }
    
    // Update cluster centers
    for (let i = 0; i < clusters.length; i++) {
      if (assignments[i].length > 0) {
        clusters[i] = {
          r: Math.round(assignments[i].reduce((sum, p) => sum + p.r, 0) / assignments[i].length),
          g: Math.round(assignments[i].reduce((sum, p) => sum + p.g, 0) / assignments[i].length),
          b: Math.round(assignments[i].reduce((sum, p) => sum + p.b, 0) / assignments[i].length),
        };
      }
    }
  }
  
  return clusters;
};

/**
 * Extract dominant colors from an image URL
 * @param imageUrl URL of the image to analyze
 * @param numColors Number of dominant colors to extract (default 5)
 * @returns Promise<ColorResult[]> Array of dominant colors sorted by vibrance
 */
export const extractDominantColors = async (
  imageUrl: string,
  numColors: number = 5
): Promise<ColorResult[]> => {
  return new Promise((resolve) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    
    // Handle timeout - use random vibrant color
    const timeout = setTimeout(() => {
      console.warn('Image load timeout, using random vibrant color');
      const randomColors = Array(numColors).fill(null).map(() => getRandomUniqueColor());
      resolve(randomColors);
    }, 10000);
    
    img.onload = function() {
      clearTimeout(timeout);
      try {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        
        if (!ctx) {
          console.warn('Canvas context not available, using random vibrant color');
          const randomColors = Array(numColors).fill(null).map(() => getRandomUniqueColor());
          resolve(randomColors);
          return;
        }
        
        const maxSize = 100;
        const scale = Math.min(1, maxSize / Math.max(img.width, img.height));
        canvas.width = Math.floor(img.width * scale);
        canvas.height = Math.floor(img.height * scale);
        
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        
        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const pixels: RGB[] = [];
        
        for (let i = 0; i < imageData.data.length; i += 8) {
          const r = imageData.data[i];
          const g = imageData.data[i + 1];
          const b = imageData.data[i + 2];
          const a = imageData.data[i + 3];
          
          if (a < 128) continue;
          
          pixels.push({ r, g, b });
        }
        
        if (pixels.length === 0) {
          console.warn('No pixels extracted, using random vibrant color');
          const randomColors = Array(numColors).fill(null).map(() => getRandomUniqueColor());
          resolve(randomColors);
          return;
        }
        
        const dominantRgbs = quantizeColors(pixels, numColors * 2);
        
        let results: ColorResult[] = dominantRgbs
          .filter(isColorUsable)
          .map(rgb => ({
            hex: rgbToHex(rgb),
            rgb,
            colorValue: rgbToColorValue(rgb),
            vibrance: calculateVibrance(rgb),
            name: getColorName(rgb),
          }))
          .sort((a, b) => b.vibrance - a.vibrance)
          .slice(0, numColors);
        
        // If we didn't get enough colors, add RANDOM vibrant colors (not always pink!)
        if (results.length < numColors) {
          const needed = numColors - results.length;
          for (let i = 0; i < needed; i++) {
            results.push(getRandomUniqueColor());
          }
        }
        
        console.log(`🎨 Extracted ${results.length} dominant colors from image`);
        results.forEach((c, i) => {
          console.log(`   ${i + 1}. ${c.name} (${c.hex}) - Vibrance: ${c.vibrance.toFixed(2)}`);
        });
        
        resolve(results);
        
      } catch (error) {
        console.error('Error extracting colors:', error);
        const randomColors = Array(numColors).fill(null).map(() => getRandomUniqueColor());
        resolve(randomColors);
      }
    };
    
    img.onerror = () => {
      clearTimeout(timeout);
      console.error('Failed to load image for color extraction, using random vibrant color');
      const randomColors = Array(numColors).fill(null).map(() => getRandomUniqueColor());
      resolve(randomColors);
    };
    
    img.src = imageUrl;
  });
};

/**
 * Extract the single most vibrant/dominant color from an image
 * This is the primary function used for deck color assignment
 * @param imageUrl URL of the image to analyze
 * @returns Promise<ColorResult> The most vibrant dominant color
 */
export const extractPrimaryColor = async (imageUrl: string): Promise<ColorResult> => {
  const colors = await extractDominantColors(imageUrl, 5);
  
  // Return the most vibrant color
  const primaryColor = colors[0];
  
  console.log(`🎨 Primary color extracted: ${primaryColor.name} (${primaryColor.hex})`);
  console.log(`   Color value for Flutter: 0x${primaryColor.colorValue.toString(16).toUpperCase()}`);
  
  return primaryColor;
};

/**
 * Get a random vibrant fallback color - ENSURES VARIETY
 * Used when image extraction fails
 */
export const getRandomVibrantColor = (): ColorResult => {
  const color = getRandomUniqueColor();
  console.log(`🎲 Random color selected: ${color.name} (${color.hex})`);
  return color;
};

/**
 * Color with prompt description for image generation
 */
export interface ColorForImageGeneration {
  color: ColorResult;
  promptDescription: string; // Description to include in image generation prompt
}

/**
 * Get color prompt description based on color name
 * This tells the image AI what color theme to use
 */
const getColorPromptDescription = (colorName: string, hex: string): string => {
  const descriptions: Record<string, string> = {
    // Material colors
    'Red': 'rich crimson red and warm coral tones',
    'Pink': 'vibrant pink and magenta hues',
    'Purple': 'deep royal purple and violet shades',
    'Deep Purple': 'luxurious deep purple and indigo tones',
    'Indigo': 'elegant indigo and navy blue palette',
    'Blue': 'brilliant blue and azure tones',
    'Light Blue': 'soft sky blue and aqua hues',
    'Cyan': 'vivid cyan and turquoise palette',
    'Teal': 'rich teal and ocean green tones',
    'Green': 'lush green and emerald hues',
    'Light Green': 'fresh lime green and spring tones',
    'Lime': 'electric lime and chartreuse palette',
    'Yellow': 'bright golden yellow and sunshine tones',
    'Amber': 'warm amber and honey gold hues',
    'Orange': 'vibrant orange and tangerine palette',
    'Deep Orange': 'bold deep orange and burnt sienna tones',
    
    // Vibrant colors
    'Hot Pink': 'electric hot pink and fuchsia neon tones',
    'Vibrant Orange': 'blazing vibrant orange and flame hues',
    'Golden Yellow': 'radiant golden yellow and marigold tones',
    'Electric Purple': 'electric purple and violet neon palette',
    'Bright Blue': 'brilliant bright blue and cobalt hues',
    'Neon Mint': 'glowing neon mint and seafoam green',
    'Coral Red': 'warm coral red and salmon pink tones',
    'Cyan Blue': 'vivid cyan blue and electric aqua',
    'Bright Gold': 'shimmering bright gold and brass tones',
    'Salmon Red': 'soft salmon red and peachy coral hues',
    'Turquoise': 'tropical turquoise and caribbean blue',
    'Sunny Yellow': 'cheerful sunny yellow and lemon tones',
    
    // Pastel colors
    'Pastel Pink': 'soft pastel pink and blush tones',
    'Pastel Peach': 'gentle pastel peach and apricot hues',
    'Pastel Yellow': 'light pastel yellow and cream tones',
    'Pastel Green': 'delicate pastel green and mint hues',
    'Pastel Blue': 'airy pastel blue and powder blue tones',
    'Pastel Lavender': 'dreamy pastel lavender and lilac hues',
    'Pastel Rose': 'romantic pastel rose and dusty pink',
    'Pastel Mauve': 'subtle pastel mauve and taupe tones',
    'Pastel Teal': 'calm pastel teal and seafoam hues',
    'Pastel Ice Blue': 'cool pastel ice blue and frost tones',
    'Pastel Blush': 'soft pastel blush and cream pink',
    'Pastel Lilac': 'gentle pastel lilac and violet hues',
  };
  
  return descriptions[colorName] || `${colorName.toLowerCase()} color theme (${hex})`;
};

/**
 * NEW: Select a random color for deck generation
 * Returns both the color data AND a prompt description for image generation
 * This is the NEW recommended way to handle deck colors
 */
export const selectRandomDeckColor = (): ColorForImageGeneration => {
  const color = getRandomUniqueColor();
  const promptDescription = getColorPromptDescription(color.name, color.hex);
  
  console.log(`🎨 Selected deck color: ${color.name} (${color.hex})`);
  console.log(`   Image prompt hint: "${promptDescription}"`);
  
  return {
    color,
    promptDescription
  };
};

/**
 * Select a random color INCLUDING pastels
 */
export const selectRandomDeckColorWithPastels = (): ColorForImageGeneration => {
  const randomIndex = Math.floor(Math.random() * ALL_COLORS_WITH_PASTELS.length);
  const color = ALL_COLORS_WITH_PASTELS[randomIndex];
  const promptDescription = getColorPromptDescription(color.name, color.hex);
  
  console.log(`🎨 Selected deck color (with pastels): ${color.name} (${color.hex})`);
  
  return {
    color,
    promptDescription
  };
};

export type { ColorResult, RGB };
