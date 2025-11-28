# Image Migration Script

This script migrates existing deck images from large PNG format to optimized WebP format for better app performance.

## Prerequisites

1. Node.js installed (v18 or higher)
2. Firebase credentials configured in `.env` file

## Installation

```bash
cd admin-portal/scripts
npm install
```

## Usage

### Migrate All Images

```bash
npm run migrate-images
```

This will:
1. Fetch all decks from Firestore
2. For each deck with an image:
   - Download original image
   - Resize to 600×800
   - Convert to WebP format
   - Compress to under 200KB
   - Upload optimized version
   - Update Firestore document

### What Gets Migrated

- ✅ All existing deck images in Firebase Storage
- ✅ Maintains 3:4 aspect ratio with smart cropping
- ✅ Converts to WebP format for better compression
- ✅ Target size: 600×800 pixels
- ✅ Target file size: Under 200KB

### Safety Features

- Keeps original URL as backup in `originalImageUrl` field
- Skips already optimized images (checks for `600x800.webp` in URL)
- Adds retry logic and error handling
- Logs all operations for audit trail

## Expected Results

### Before
- Image Size: 1024×1365 PNG
- File Size: 500KB - 1MB
- Load Time: 2-5 seconds

### After
- Image Size: 600×800 WebP
- File Size: 80KB - 180KB
- Load Time: 0.3-0.8 seconds

## Monitoring

The script outputs:
- ✅ Successfully migrated images
- ⏭️ Skipped images (no URL or already optimized)
- ❌ Failed migrations with error details
- 📊 Final summary with counts

## Rollback

If needed, you can restore original images using the `originalImageUrl` field:

```javascript
// Revert a single deck
await updateDoc(doc(firestore, 'decks', deckId), {
  imageUrl: deckData.originalImageUrl
});
```

## Troubleshooting

### "Failed to fetch image"
- Check Firebase Storage permissions
- Ensure original images are accessible

### "Rate limit exceeded"
- Script has built-in delays between requests
- If still occurring, increase delay in script

### "Out of memory"
- Process images in smaller batches
- Reduce quality settings if needed

## Notes

- Migration is idempotent - safe to run multiple times
- Already optimized images are automatically skipped
- Original images remain in Storage (can be cleaned up later)
- Total migration time depends on number of decks (~1-2 seconds per image)




