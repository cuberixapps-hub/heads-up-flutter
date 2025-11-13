import { storage } from '../config/firebase';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';

/**
 * Configuration for image compression
 */
const IMAGE_CONFIG = {
  maxWidth: 800,
  maxHeight: 800,
  quality: 0.85,
  maxSizeKB: 200,
  format: 'webp' as const,
};

/**
 * Compress an image file using Canvas API
 * @param file - The input image file
 * @param onProgress - Optional progress callback
 * @returns Promise<Blob> - Compressed image blob
 */
export const compressImage = async (
  file: File,
  onProgress?: (progress: number) => void
): Promise<Blob> => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    
    reader.onload = (event) => {
      const img = new Image();
      
      img.onload = () => {
        // Calculate new dimensions
        let { width, height } = img;
        
        if (width > IMAGE_CONFIG.maxWidth || height > IMAGE_CONFIG.maxHeight) {
          const aspectRatio = width / height;
          
          if (width > height) {
            width = IMAGE_CONFIG.maxWidth;
            height = width / aspectRatio;
          } else {
            height = IMAGE_CONFIG.maxHeight;
            width = height * aspectRatio;
          }
        }
        
        // Create canvas
        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        
        const ctx = canvas.getContext('2d');
        if (!ctx) {
          reject(new Error('Failed to get canvas context'));
          return;
        }
        
        // Draw and compress image
        ctx.drawImage(img, 0, 0, width, height);
        
        // Convert to blob
        canvas.toBlob(
          async (blob) => {
            if (!blob) {
              reject(new Error('Failed to compress image'));
              return;
            }
            
            // Check if further compression is needed
            if (blob.size > IMAGE_CONFIG.maxSizeKB * 1024 && IMAGE_CONFIG.quality > 0.5) {
              // Recursively compress with lower quality
              const lowerQualityFile = new File([blob], file.name, { type: blob.type });
              IMAGE_CONFIG.quality -= 0.1;
              try {
                const furtherCompressed = await compressImage(lowerQualityFile, onProgress);
                resolve(furtherCompressed);
              } catch (error) {
                reject(error);
              }
              IMAGE_CONFIG.quality += 0.1; // Restore quality for next use
            } else {
              resolve(blob);
            }
          },
          IMAGE_CONFIG.format,
          IMAGE_CONFIG.quality
        );
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
    // Update progress - starting compression
    onProgress?.(10);
    
    // Compress the image
    const compressedBlob = await compressImage(file, (progress) => {
      // Map compression progress from 10% to 50%
      onProgress?.(10 + progress * 0.4);
    });
    
    onProgress?.(50);
    
    // Log compression results
    const originalSize = file.size;
    const compressedSize = compressedBlob.size;
    const compressionRatio = Math.round((1 - compressedSize / originalSize) * 100);
    
    console.log(`Image compressed: ${Math.round(originalSize / 1024)}KB -> ${Math.round(compressedSize / 1024)}KB (${compressionRatio}% reduction)`);
    
    // Generate unique filename
    const timestamp = Date.now();
    const extension = IMAGE_CONFIG.format;
    const filename = `${timestamp}_${file.name.replace(/\.[^/.]+$/, '')}.${extension}`;
    const storageRef = ref(storage, `deck-images/${deckId}/${filename}`);
    
    // Upload to Firebase Storage
    onProgress?.(60);
    
    const uploadResult = await uploadBytes(storageRef, compressedBlob, {
      contentType: `image/${IMAGE_CONFIG.format}`,
      customMetadata: {
        originalName: file.name,
        originalSize: originalSize.toString(),
        compressedSize: compressedSize.toString(),
        compressionRatio: compressionRatio.toString(),
        compressedAt: new Date().toISOString(),
      },
    });
    
    onProgress?.(90);
    
    // Get download URL
    const downloadURL = await getDownloadURL(uploadResult.ref);
    
    onProgress?.(100);
    
    return downloadURL;
  } catch (error) {
    console.error('Error uploading compressed image:', error);
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
