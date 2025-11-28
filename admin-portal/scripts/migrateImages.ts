/**
 * Firebase Image Migration Script
 * 
 * This script migrates existing deck images from large PNG format (1024×1365) 
 * to optimized WebP format (600×800) to improve app loading performance.
 * 
 * Usage:
 *   npm install
 *   npm run migrate-images
 * 
 * What it does:
 * 1. Fetches all decks from Firestore
 * 2. For each deck with an imageUrl:
 *    - Downloads the original image
 *    - Processes through compression pipeline (600×800 WebP under 200KB)
 *    - Uploads optimized version to Firebase Storage
 *    - Updates Firestore document with new URL
 * 3. Logs progress and results
 */

import { initializeApp } from 'firebase/app';
import { getFirestore, collection, getDocs, doc, updateDoc } from 'firebase/firestore';
import { getStorage, ref, getDownloadURL, uploadBytes } from 'firebase/storage';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Firebase configuration
const firebaseConfig = {
  apiKey: process.env.VITE_FIREBASE_API_KEY,
  authDomain: process.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: process.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.VITE_FIREBASE_APP_ID,
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const firestore = getFirestore(app);
const storage = getStorage(app);

/**
 * Check if image is already optimized
 */
function isOptimized(imageUrl: string): boolean {
  return imageUrl.includes('600x800.webp') || imageUrl.includes('_optimized.');
}

/**
 * Resize and compress image to 600×800 WebP
 */
async function optimizeImage(imageUrl: string): Promise<Blob> {
  // Fetch the original image
  const response = await fetch(imageUrl);
  if (!response.ok) {
    throw new Error(`Failed to fetch image: ${response.statusText}`);
  }
  
  const blob = await response.blob();
  
  // Create an image element
  const img = new Image();
  img.crossOrigin = 'anonymous';
  
  // Load the image
  await new Promise<void>((resolve, reject) => {
    img.onload = () => resolve();
    img.onerror = reject;
    img.src = URL.createObjectURL(blob);
  });
  
  // Create canvas for cropping and resizing
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  
  if (!ctx) {
    throw new Error('Could not get canvas context');
  }
  
  // Set target dimensions (600×800 for optimal mobile display)
  const targetWidth = 600;
  const targetHeight = 800;
  canvas.width = targetWidth;
  canvas.height = targetHeight;
  
  // Calculate crop to maintain 3:4 aspect ratio
  const sourceWidth = img.width;
  const sourceHeight = img.height;
  const sourceRatio = sourceWidth / sourceHeight;
  const targetRatio = targetWidth / targetHeight; // 0.75
  
  let cropX = 0;
  let cropY = 0;
  let cropWidth = sourceWidth;
  let cropHeight = sourceHeight;
  
  if (sourceRatio < targetRatio) {
    // Source is taller - crop height
    cropHeight = sourceWidth / targetRatio;
    cropY = (sourceHeight - cropHeight) / 2;
  } else {
    // Source is wider - crop width
    cropWidth = sourceHeight * targetRatio;
    cropX = (sourceWidth - cropWidth) / 2;
  }
  
  // Draw cropped and resized image
  ctx.drawImage(
    img,
    cropX, cropY, cropWidth, cropHeight,
    0, 0, targetWidth, targetHeight
  );
  
  // Convert to WebP blob with quality tuning to stay under 200KB
  return new Promise<Blob>((resolve, reject) => {
    const tryCompress = (quality: number) => {
      canvas.toBlob((blob) => {
        if (blob) {
          const sizeKB = blob.size / 1024;
          if (sizeKB > 200 && quality > 0.5) {
            console.log(`  Image size ${sizeKB.toFixed(1)}KB, reducing quality to ${(quality - 0.05).toFixed(2)}`);
            tryCompress(quality - 0.05);
          } else {
            console.log(`  Final image: ${sizeKB.toFixed(1)}KB at quality ${quality.toFixed(2)}`);
            resolve(blob);
          }
        } else {
          reject(new Error('Failed to create blob from canvas'));
        }
      }, 'image/webp', quality);
    };
    
    tryCompress(0.88);
  });
}

/**
 * Migrate a single deck's image
 */
async function migrateDeckImage(deckId: string, deckName: string, imageUrl: string): Promise<string> {
  console.log(`\n📸 Migrating image for deck: ${deckName}`);
  console.log(`  Original URL: ${imageUrl}`);
  
  // Check if already optimized
  if (isOptimized(imageUrl)) {
    console.log(`  ✅ Already optimized, skipping`);
    return imageUrl;
  }
  
  try {
    // Download and optimize image
    console.log(`  🔄 Downloading and optimizing...`);
    const optimizedBlob = await optimizeImage(imageUrl);
    
    // Generate new filename
    const timestamp = Date.now();
    const cleanName = deckName.toLowerCase().replace(/[^a-z0-9]/g, '-').substring(0, 50);
    const filename = `optimized/${cleanName}_${timestamp}_600x800.webp`;
    
    // Upload to Firebase Storage
    console.log(`  ⬆️  Uploading to Firebase Storage...`);
    const storageRef = ref(storage, `deck-images/${filename}`);
    const uploadResult = await uploadBytes(storageRef, optimizedBlob, {
      contentType: 'image/webp',
      customMetadata: {
        originalUrl: imageUrl,
        optimizedAt: new Date().toISOString(),
        size: '600x800',
        format: 'webp',
        sizeKB: Math.round(optimizedBlob.size / 1024).toString(),
      },
    });
    
    // Get new download URL
    const newUrl = await getDownloadURL(uploadResult.ref);
    console.log(`  ✅ Optimized URL: ${newUrl}`);
    console.log(`  💾 Size: ${Math.round(optimizedBlob.size / 1024)}KB`);
    
    return newUrl;
  } catch (error) {
    console.error(`  ❌ Error migrating image:`, error);
    throw error;
  }
}

/**
 * Main migration function
 */
async function migrateAllImages() {
  console.log('🚀 Starting image migration...\n');
  console.log('========================================');
  
  try {
    // Fetch all decks
    console.log('📚 Fetching all decks from Firestore...');
    const decksSnapshot = await getDocs(collection(firestore, 'decks'));
    console.log(`Found ${decksSnapshot.size} decks\n`);
    
    let processed = 0;
    let skipped = 0;
    let migrated = 0;
    let failed = 0;
    
    for (const deckDoc of decksSnapshot.docs) {
      const deckData = deckDoc.data();
      const deckId = deckDoc.id;
      const deckName = deckData.name || 'Unknown';
      const imageUrl = deckData.imageUrl;
      
      processed++;
      console.log(`\n[${processed}/${decksSnapshot.size}] Processing: ${deckName}`);
      
      // Skip if no image
      if (!imageUrl) {
        console.log(`  ⏭️  No image URL, skipping`);
        skipped++;
        continue;
      }
      
      // Skip if already optimized
      if (isOptimized(imageUrl)) {
        console.log(`  ✅ Already optimized, skipping`);
        skipped++;
        continue;
      }
      
      try {
        // Migrate the image
        const newUrl = await migrateDeckImage(deckId, deckName, imageUrl);
        
        // Update Firestore document
        console.log(`  📝 Updating Firestore document...`);
        await updateDoc(doc(firestore, 'decks', deckId), {
          imageUrl: newUrl,
          originalImageUrl: imageUrl, // Keep original as backup
          optimizedAt: new Date().toISOString(),
        });
        
        console.log(`  ✅ Migration complete for ${deckName}`);
        migrated++;
        
        // Small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 1000));
      } catch (error) {
        console.error(`  ❌ Failed to migrate ${deckName}:`, error);
        failed++;
      }
    }
    
    // Print summary
    console.log('\n========================================');
    console.log('🏁 Migration Complete!\n');
    console.log(`📊 Summary:`);
    console.log(`  Total Processed: ${processed}`);
    console.log(`  Successfully Migrated: ${migrated}`);
    console.log(`  Already Optimized: ${skipped}`);
    console.log(`  Failed: ${failed}`);
    console.log('========================================\n');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

// Run migration
migrateAllImages()
  .then(() => {
    console.log('✅ Script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Script failed:', error);
    process.exit(1);
  });




