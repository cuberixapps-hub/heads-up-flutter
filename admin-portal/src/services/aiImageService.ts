import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { storage } from '../config/firebase';
import { getOpenAIClient, handleAIError, withRetry } from './aiConfig';
import { AIErrorCode } from '../types/ai';

// Default fallback image URL (can be customized)
const DEFAULT_DECK_IMAGE = 'https://via.placeholder.com/1024x1024/9C27B0/ffffff?text=Heads+Up!';

/**
 * Generate a deck cover image using DALL-E 3
 * @param topic The deck topic/theme
 * @param style Optional style modifier (e.g., "cartoon", "realistic", "minimalist")
 * @returns Promise<string> The Firebase Storage URL of the generated image
 */
export const generateDeckImage = async (
  topic: string,
  style: string = 'vibrant, colorful, game-style illustration'
): Promise<string> => {
  try {
    const openai = getOpenAIClient();
    
    // Create a descriptive prompt for DALL-E 3
    const prompt = `Create a ${style} cover image for a Heads Up game deck about "${topic}". 
    The image should be fun, engaging, and clearly represent the theme. 
    Include relevant visual elements and vibrant colors. 
    Make it suitable for a mobile game card deck cover.
    Avoid any text or words in the image.`;
    
    console.log('Generating image with prompt:', prompt);
    
    // Call DALL-E 3 API with retry logic
    const response = await withRetry(async () => {
      return await openai.images.generate({
        model: 'dall-e-3',
        prompt,
        n: 1,
        size: '1024x1024',
        quality: 'standard',
        response_format: 'url',
      });
    });
    
    const imageUrl = response.data[0]?.url;
    
    if (!imageUrl) {
      throw new Error('No image URL returned from OpenAI');
    }
    
    // Download the image and upload to Firebase Storage
    const uploadedUrl = await uploadImageToFirebase(imageUrl, topic);
    
    return uploadedUrl;
    
  } catch (error: any) {
    console.error('Image generation error:', error);
    
    // Handle specific AI errors
    const aiError = handleAIError(error);
    
    // For image generation failures, return default image instead of throwing
    if (aiError.code === AIErrorCode.API_KEY_MISSING || 
        aiError.code === AIErrorCode.RATE_LIMIT) {
      console.warn('Falling back to default image due to:', aiError.message);
      return DEFAULT_DECK_IMAGE;
    }
    
    // Re-throw other errors
    throw aiError;
  }
};

/**
 * Upload an image from URL to Firebase Storage
 * @param imageUrl The source image URL
 * @param topic The deck topic (used for naming)
 * @returns Promise<string> The Firebase Storage download URL
 */
const uploadImageToFirebase = async (
  imageUrl: string, 
  topic: string
): Promise<string> => {
  try {
    // Fetch the image
    const response = await fetch(imageUrl);
    
    if (!response.ok) {
      throw new Error(`Failed to fetch image: ${response.statusText}`);
    }
    
    const blob = await response.blob();
    
    // Generate a unique filename
    const timestamp = Date.now();
    const cleanTopic = topic.toLowerCase().replace(/[^a-z0-9]/g, '-').substring(0, 50);
    const filename = `ai-generated/${cleanTopic}_${timestamp}.png`;
    
    // Create storage reference
    const storageRef = ref(storage, `deck-images/${filename}`);
    
    // Upload the blob
    const uploadResult = await uploadBytes(storageRef, blob, {
      contentType: 'image/png',
      customMetadata: {
        generatedBy: 'dalle-3',
        topic: topic,
        generatedAt: new Date().toISOString(),
      },
    });
    
    // Get the download URL
    const downloadUrl = await getDownloadURL(uploadResult.ref);
    
    console.log('Image uploaded successfully:', downloadUrl);
    return downloadUrl;
    
  } catch (error) {
    console.error('Firebase upload error:', error);
    
    // If Firebase upload fails, return the original URL as fallback
    console.warn('Failed to upload to Firebase, using original URL');
    return imageUrl;
  }
};

/**
 * Generate multiple image variations for a topic
 * @param topic The deck topic
 * @param count Number of variations to generate (max 3)
 * @returns Promise<string[]> Array of image URLs
 */
export const generateImageVariations = async (
  topic: string,
  count: number = 3
): Promise<string[]> => {
  const styles = [
    'vibrant, colorful, game-style illustration',
    'modern, minimalist design with bold colors',
    'playful, cartoon-style artwork',
  ];
  
  const promises = styles.slice(0, count).map(style => 
    generateDeckImage(topic, style).catch(() => DEFAULT_DECK_IMAGE)
  );
  
  return Promise.all(promises);
};

/**
 * Validate if image generation is available
 */
export const isImageGenerationAvailable = (): boolean => {
  try {
    getOpenAIClient();
    return true;
  } catch {
    return false;
  }
};
