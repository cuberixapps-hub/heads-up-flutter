import { storage } from '../config/firebase';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';

/**
 * Configuration for image compression
 * 
 * ⚙️ TARGET FILE SIZE:
 * - Change 'maxSizeKB' to adjust target file size
 * - Current: 200KB (good balance of quality and size)
 * - The compression will automatically adjust quality to hit this target
 * 
 * ⚙️ MAX DIMENSION:
 * - Images resized to this max dimension while maintaining aspect ratio
 * - Current: 1200px (on longest side)
 * - No cropping - aspect ratio is preserved
 */
const IMAGE_CONFIG = {
  maxDimension: 1200, // Max width or height in pixels
  initialQuality: 0.85, // Starting quality (85%)
  minQuality: 0.6, // Minimum quality (60%)
  maxSizeKB: 200, // Target file size in KB
  format: 'webp' as const,
};

/**
 * Compress an image file using Canvas API
 * Resizes to max dimension while maintaining aspect ratio, targets ~200KB
 * @param file - The input image file
 * @param onProgress - Optional progress callback
 * @returns Promise<Blob> - Compressed image blob
 */
export const compressImage = async (
  file: File,
  onProgress?: (progress: number) => void
): Promise<Blob> => {
  console.log(`🗜️ Starting compression for: ${file.name} (${Math.round(file.size / 1024)}KB)`);
  
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    
    reader.onload = (event) => {
      const img = new Image();
      
      img.onload = () => {
        const { width: srcWidth, height: srcHeight } = img;
        console.log(`📐 Original dimensions: ${srcWidth}x${srcHeight}`);
        
        // Resize to max dimension on longest side, maintaining aspect ratio
        const maxDimension = IMAGE_CONFIG.maxDimension;
        let targetWidth = srcWidth;
        let targetHeight = srcHeight;
        
        if (srcWidth > srcHeight) {
          // Landscape or square
          if (srcWidth > maxDimension) {
            targetWidth = maxDimension;
            targetHeight = Math.round((srcHeight / srcWidth) * maxDimension);
          }
        } else {
          // Portrait
          if (srcHeight > maxDimension) {
            targetHeight = maxDimension;
            targetWidth = Math.round((srcWidth / srcHeight) * maxDimension);
          }
        }
        
        console.log(`📏 Resizing to ${targetWidth}x${targetHeight} (maintaining aspect ratio, no cropping)`);
        
        // Create canvas with target dimensions
        const canvas = document.createElement('canvas');
        canvas.width = targetWidth;
        canvas.height = targetHeight;
        
        const ctx = canvas.getContext('2d', { alpha: false });
        if (!ctx) {
          reject(new Error('Failed to get canvas context'));
          return;
        }
        
        // Enable image smoothing for better quality when downscaling
        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = 'high';
        
        // Draw resized image (no cropping)
        ctx.drawImage(img, 0, 0, targetWidth, targetHeight);
        
        onProgress?.(50);
        
        // Convert to WebP blob with quality adjustment to target ~200KB
        const tryCompress = (quality: number) => {
          canvas.toBlob(
            (blob) => {
              if (!blob) {
                reject(new Error('Failed to compress image'));
                return;
              }
              
              const sizeKB = blob.size / 1024;
              
              // If size is over target and we can reduce quality, try again
              if (sizeKB > IMAGE_CONFIG.maxSizeKB && quality > IMAGE_CONFIG.minQuality) {
                console.log(`📦 Size ${Math.round(sizeKB)}KB, adjusting quality...`);
                tryCompress(quality - 0.05);
              } else {
                const originalSizeKB = Math.round(file.size / 1024);
                const compressedSizeKB = Math.round(blob.size / 1024);
                const compressionPercent = Math.round((1 - blob.size / file.size) * 100);
                
                console.log(`✅ Compression complete!`);
                console.log(`   Original: ${originalSizeKB}KB`);
                console.log(`   Compressed: ${compressedSizeKB}KB`);
                console.log(`   Reduction: ${compressionPercent}% smaller`);
                console.log(`   Quality: ${Math.round(quality * 100)}%`);
                
                onProgress?.(100);
                resolve(blob);
              }
            },
            `image/${IMAGE_CONFIG.format}`,
            quality
          );
        };
        
        // Start with initial quality
        tryCompress(IMAGE_CONFIG.initialQuality);
      };
      
      img.onerror = () => {
        reject(new Error('Failed to load image'));
      };
      
      img.src = event.target?.result as string;
    };
    
    reader.onerror = () => {
      reject(new Error('Failed to read file'));
    };
    
    reader.readAsDataURL(file);
  });
};

/**
 * Upload compressed image to Firebase Storage
 * This function ALWAYS compresses the image before uploading
 * @param file - The original image file
 * @param deckId - The deck ID for organization
 * @param onProgress - Optional progress callback
 * @returns Promise<string> - Download URL of the uploaded image
 */
export const uploadCompressedImage = async (
  file: File,
  deckId: string,
  onProgress?: (progress: number) => void
): Promise<string> => {
  try {
    console.log(`📤 Upload started for: ${file.name}`);
    console.log(`   Original size: ${Math.round(file.size / 1024)}KB`);
    
    // Update progress - starting compression
    onProgress?.(10);
    
    // COMPRESS THE IMAGE FIRST - this reduces size before Firebase upload
    const compressedBlob = await compressImage(file, (progress) => {
      // Map compression progress from 10% to 50%
      onProgress?.(10 + progress * 0.4);
    });
    
    onProgress?.(50);
    
    // Log compression results
    const originalSize = file.size;
    const compressedSize = compressedBlob.size;
    const compressionRatio = Math.round((1 - compressedSize / originalSize) * 100);
    
    console.log(`🎯 Compression Results:`);
    console.log(`   Before: ${Math.round(originalSize / 1024)}KB`);
    console.log(`   After: ${Math.round(compressedSize / 1024)}KB`);
    console.log(`   Saved: ${compressionRatio}% reduction`);
    
    // Generate unique filename
    const timestamp = Date.now();
    const extension = IMAGE_CONFIG.format;
    const filename = `${timestamp}_${file.name.replace(/\.[^/.]+$/, '')}.${extension}`;
    const storageRef = ref(storage, `deck-images/${deckId}/${filename}`);
    
    // Upload COMPRESSED blob to Firebase Storage
    console.log(`☁️ Uploading compressed image to Firebase...`);
    onProgress?.(60);
    
    const uploadResult = await uploadBytes(storageRef, compressedBlob, {
      contentType: `image/${IMAGE_CONFIG.format}`,
      customMetadata: {
        originalName: file.name,
        originalSize: originalSize.toString(),
        compressedSize: compressedSize.toString(),
        compressionRatio: compressionRatio.toString(),
        compressedAt: new Date().toISOString(),
        targetSize: `${IMAGE_CONFIG.maxSizeKB}KB`,
        format: IMAGE_CONFIG.format,
      },
    });
    
    onProgress?.(90);
    
    // Get download URL
    const downloadURL = await getDownloadURL(uploadResult.ref);
    
    onProgress?.(100);
    
    console.log(`✅ Upload complete! Compressed image uploaded to Firebase.`);
    console.log(`   URL: ${downloadURL}`);
    
    return downloadURL;
  } catch (error) {
    console.error('❌ Error uploading compressed image:', error);
    throw new Error('Failed to upload image. Please try again.');
  }
};

/**
 * Check if a file needs compression
 * @param file - The file to check
 * @returns boolean - True if compression is needed
 */
export const needsCompression = (file: File): boolean => {
  return file.size > IMAGE_CONFIG.maxSizeKB * 1024;
};

/**
 * Get image dimensions from a file
 * @param file - The image file
 * @returns Promise<{ width: number; height: number }> - Image dimensions
 */
export const getImageDimensions = async (
  file: File
): Promise<{ width: number; height: number }> => {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve({ width: img.width, height: img.height });
    };
    
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('Failed to load image'));
    };
    
    img.src = url;
  });
};

/**
 * Format file size for display
 * @param bytes - File size in bytes
 * @returns string - Formatted size string
 */
export const formatFileSize = (bytes: number): string => {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};
