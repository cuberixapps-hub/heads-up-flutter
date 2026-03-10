// Note: For uploading images, use supabaseStorageService.ts
// This file contains compression utilities only

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
 * Upload compressed image to Supabase Storage
 * @deprecated Use uploadDeckImage from supabaseStorageService.ts instead
 * This function is kept for backward compatibility
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
  // Redirect to Supabase storage service
  const { uploadDeckImage } = await import('./supabaseStorageService');
  return uploadDeckImage(file, deckId, onProgress);
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
