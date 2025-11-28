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
 * Predefined vibrant color palette for fallback
 * These are eye-catching colors suitable for deck cards
 */
const VIBRANT_FALLBACK_COLORS: ColorResult[] = [
  { hex: '#E91E63', rgb: { r: 233, g: 30, b: 99 }, colorValue: 0xFFE91E63, vibrance: 1, name: 'Pink' },
  { hex: '#9C27B0', rgb: { r: 156, g: 39, b: 176 }, colorValue: 0xFF9C27B0, vibrance: 1, name: 'Purple' },
  { hex: '#673AB7', rgb: { r: 103, g: 58, b: 183 }, colorValue: 0xFF673AB7, vibrance: 1, name: 'Deep Purple' },
  { hex: '#3F51B5', rgb: { r: 63, g: 81, b: 181 }, colorValue: 0xFF3F51B5, vibrance: 1, name: 'Indigo' },
  { hex: '#2196F3', rgb: { r: 33, g: 150, b: 243 }, colorValue: 0xFF2196F3, vibrance: 1, name: 'Blue' },
  { hex: '#00BCD4', rgb: { r: 0, g: 188, b: 212 }, colorValue: 0xFF00BCD4, vibrance: 1, name: 'Cyan' },
  { hex: '#009688', rgb: { r: 0, g: 150, b: 136 }, colorValue: 0xFF009688, vibrance: 1, name: 'Teal' },
  { hex: '#4CAF50', rgb: { r: 76, g: 175, b: 80 }, colorValue: 0xFF4CAF50, vibrance: 1, name: 'Green' },
  { hex: '#FF9800', rgb: { r: 255, g: 152, b: 0 }, colorValue: 0xFFFF9800, vibrance: 1, name: 'Orange' },
  { hex: '#FF5722', rgb: { r: 255, g: 87, b: 34 }, colorValue: 0xFFFF5722, vibrance: 1, name: 'Deep Orange' },
  { hex: '#F44336', rgb: { r: 244, g: 67, b: 54 }, colorValue: 0xFFF44336, vibrance: 1, name: 'Red' },
];

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
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous'; // Enable CORS for Firebase Storage images
    
    img.onload = () => {
      try {
        // Create canvas to read pixel data
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        
        if (!ctx) {
          console.warn('Canvas context not available, using fallback colors');
          resolve(VIBRANT_FALLBACK_COLORS.slice(0, numColors));
          return;
        }
        
        // Scale down for performance (sample at most 100x100 pixels)
        const maxSize = 100;
        const scale = Math.min(1, maxSize / Math.max(img.width, img.height));
        canvas.width = Math.floor(img.width * scale);
        canvas.height = Math.floor(img.height * scale);
        
        // Draw image to canvas
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        
        // Get pixel data
        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const pixels: RGB[] = [];
        
        // Sample pixels (skip every 2nd pixel for performance)
        for (let i = 0; i < imageData.data.length; i += 8) {
          const r = imageData.data[i];
          const g = imageData.data[i + 1];
          const b = imageData.data[i + 2];
          const a = imageData.data[i + 3];
          
          // Skip transparent pixels
          if (a < 128) continue;
          
          pixels.push({ r, g, b });
        }
        
        if (pixels.length === 0) {
          console.warn('No pixels extracted, using fallback colors');
          resolve(VIBRANT_FALLBACK_COLORS.slice(0, numColors));
          return;
        }
        
        // Quantize colors using k-means
        const dominantRgbs = quantizeColors(pixels, numColors * 2); // Get more than needed to filter
        
        // Convert to ColorResult and filter
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
        
        // If we didn't get enough colors, add fallbacks
        if (results.length < numColors) {
          const fallbacksNeeded = numColors - results.length;
          const shuffledFallbacks = [...VIBRANT_FALLBACK_COLORS]
            .sort(() => Math.random() - 0.5)
            .slice(0, fallbacksNeeded);
          results = [...results, ...shuffledFallbacks];
        }
        
        console.log(`🎨 Extracted ${results.length} dominant colors from image`);
        results.forEach((c, i) => {
          console.log(`   ${i + 1}. ${c.name} (${c.hex}) - Vibrance: ${c.vibrance.toFixed(2)}`);
        });
        
        resolve(results);
        
      } catch (error) {
        console.error('Error extracting colors:', error);
        resolve(VIBRANT_FALLBACK_COLORS.slice(0, numColors));
      }
    };
    
    img.onerror = (error) => {
      console.error('Failed to load image for color extraction:', error);
      // Return fallback colors instead of rejecting
      resolve(VIBRANT_FALLBACK_COLORS.slice(0, numColors));
    };
    
    // Handle timeout
    const timeout = setTimeout(() => {
      console.warn('Image load timeout, using fallback colors');
      resolve(VIBRANT_FALLBACK_COLORS.slice(0, numColors));
    }, 10000); // 10 second timeout
    
    img.onload = function() {
      clearTimeout(timeout);
      // Re-run the original onload logic
      try {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        
        if (!ctx) {
          console.warn('Canvas context not available, using fallback colors');
          resolve(VIBRANT_FALLBACK_COLORS.slice(0, numColors));
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
          console.warn('No pixels extracted, using fallback colors');
          resolve(VIBRANT_FALLBACK_COLORS.slice(0, numColors));
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
        
        if (results.length < numColors) {
          const fallbacksNeeded = numColors - results.length;
          const shuffledFallbacks = [...VIBRANT_FALLBACK_COLORS]
            .sort(() => Math.random() - 0.5)
            .slice(0, fallbacksNeeded);
          results = [...results, ...shuffledFallbacks];
        }
        
        console.log(`🎨 Extracted ${results.length} dominant colors from image`);
        results.forEach((c, i) => {
          console.log(`   ${i + 1}. ${c.name} (${c.hex}) - Vibrance: ${c.vibrance.toFixed(2)}`);
        });
        
        resolve(results);
        
      } catch (error) {
        console.error('Error extracting colors:', error);
        resolve(VIBRANT_FALLBACK_COLORS.slice(0, numColors));
      }
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
 * Get a random vibrant fallback color
 * Used when image extraction fails
 */
export const getRandomVibrantColor = (): ColorResult => {
  const index = Math.floor(Math.random() * VIBRANT_FALLBACK_COLORS.length);
  return VIBRANT_FALLBACK_COLORS[index];
};

export type { ColorResult, RGB };

