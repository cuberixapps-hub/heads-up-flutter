import { supabase, DECK_IMAGES_BUCKET, isSupabaseConfigured } from '../config/supabase';
import { compressImage, formatFileSize } from './imageCompressionService';

// ===========================================
// Supabase Storage Service
// ===========================================

/**
 * Upload a deck image to Supabase Storage with compression
 * @param file - The image file to upload
 * @param deckId - The deck ID for organizing files
 * @param onProgress - Optional progress callback (0-100)
 * @returns The public URL of the uploaded image
 */
export async function uploadDeckImage(
  file: File,
  deckId: string,
  onProgress?: (progress: number) => void
): Promise<string> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase is not configured. Please set environment variables.');
  }

  console.log(`📤 Starting upload for: ${file.name} (${formatFileSize(file.size)})`);
  onProgress?.(10);

  try {
    // Step 1: Compress the image
    console.log('🗜️ Compressing image...');
    const compressedBlob = await compressImage(file, (compressionProgress) => {
      // Map compression progress from 10% to 50%
      onProgress?.(10 + compressionProgress * 0.4);
    });

    onProgress?.(50);

    // Log compression results
    const originalSize = file.size;
    const compressedSize = compressedBlob.size;
    const compressionRatio = Math.round((1 - compressedSize / originalSize) * 100);

    console.log(`✅ Compression complete:`);
    console.log(`   Before: ${formatFileSize(originalSize)}`);
    console.log(`   After: ${formatFileSize(compressedSize)}`);
    console.log(`   Saved: ${compressionRatio}%`);

    // Step 2: Generate unique filename
    const timestamp = Date.now();
    const sanitizedName = file.name.replace(/\.[^/.]+$/, '').replace(/[^a-zA-Z0-9]/g, '_');
    const filename = `${timestamp}_${sanitizedName}.webp`;
    const filePath = `${deckId}/${filename}`;

    onProgress?.(60);

    // Step 3: Upload to Supabase Storage
    console.log(`☁️ Uploading to Supabase Storage: ${filePath}`);
    
    const { data, error } = await supabase.storage
      .from(DECK_IMAGES_BUCKET)
      .upload(filePath, compressedBlob, {
        contentType: 'image/webp',
        cacheControl: '31536000', // 1 year cache
        upsert: true, // Overwrite if exists
      });

    if (error) {
      console.error('❌ Upload error:', error);
      throw new Error(`Failed to upload image: ${error.message}`);
    }

    onProgress?.(90);

    // Step 4: Get public URL
    const { data: urlData } = supabase.storage
      .from(DECK_IMAGES_BUCKET)
      .getPublicUrl(data.path);

    onProgress?.(100);

    console.log(`✅ Upload complete: ${urlData.publicUrl}`);
    
    return urlData.publicUrl;
  } catch (error) {
    console.error('❌ Error in uploadDeckImage:', error);
    throw error;
  }
}

/**
 * Delete a deck image from Supabase Storage
 * @param imageUrl - The full public URL of the image
 */
export async function deleteDeckImage(imageUrl: string): Promise<void> {
  if (!isSupabaseConfigured()) {
    console.warn('Supabase not configured, skipping delete');
    return;
  }

  try {
    // Extract path from URL
    // URL format: https://project.supabase.co/storage/v1/object/public/deck-images/deckId/filename.webp
    const bucketPath = `/storage/v1/object/public/${DECK_IMAGES_BUCKET}/`;
    const pathStart = imageUrl.indexOf(bucketPath);
    
    if (pathStart === -1) {
      console.warn('Could not parse image path from URL:', imageUrl);
      return;
    }

    const filePath = imageUrl.substring(pathStart + bucketPath.length);
    console.log(`🗑️ Deleting image: ${filePath}`);

    const { error } = await supabase.storage
      .from(DECK_IMAGES_BUCKET)
      .remove([filePath]);

    if (error) {
      console.error('Error deleting image:', error);
      throw error;
    }

    console.log('✅ Image deleted successfully');
  } catch (error) {
    console.error('Error in deleteDeckImage:', error);
    throw error;
  }
}

/**
 * Get the public URL for a file path
 * @param filePath - The path within the bucket (e.g., "deckId/filename.webp")
 * @returns The full public URL
 */
export function getPublicUrl(filePath: string): string {
  const { data } = supabase.storage
    .from(DECK_IMAGES_BUCKET)
    .getPublicUrl(filePath);

  return data.publicUrl;
}

/**
 * List all images for a deck
 * @param deckId - The deck ID
 * @returns Array of file metadata
 */
export async function listDeckImages(deckId: string): Promise<Array<{
  name: string;
  url: string;
  size: number;
  createdAt: string;
}>> {
  const { data, error } = await supabase.storage
    .from(DECK_IMAGES_BUCKET)
    .list(deckId);

  if (error) {
    console.error('Error listing images:', error);
    return [];
  }

  return (data || []).map(file => ({
    name: file.name,
    url: getPublicUrl(`${deckId}/${file.name}`),
    size: file.metadata?.size || 0,
    createdAt: file.created_at || '',
  }));
}

/**
 * Delete all images for a deck
 * @param deckId - The deck ID
 */
export async function deleteAllDeckImages(deckId: string): Promise<void> {
  try {
    const { data: files } = await supabase.storage
      .from(DECK_IMAGES_BUCKET)
      .list(deckId);

    if (files && files.length > 0) {
      const filePaths = files.map(file => `${deckId}/${file.name}`);
      
      const { error } = await supabase.storage
        .from(DECK_IMAGES_BUCKET)
        .remove(filePaths);

      if (error) {
        console.error('Error deleting deck images:', error);
        throw error;
      }

      console.log(`✅ Deleted ${files.length} images for deck ${deckId}`);
    }
  } catch (error) {
    console.error('Error in deleteAllDeckImages:', error);
    throw error;
  }
}
