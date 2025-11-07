<!-- 70ad800a-cc62-4ba2-aa5b-a245a4d24e6f 2cf19e39-e9dc-4c03-8d80-4425f97b1f44 -->
# Firebase Storage Image Upload Implementation

## Overview

Add Firebase Storage integration to the admin portal, enabling deck image uploads with preview and validation.

## Implementation Steps

### 1. Update Firebase Configuration

**File: `admin-portal/src/config/firebase.ts`**

Add Firebase Storage import and export:

```typescript
import { getStorage } from 'firebase/storage';

export const storage = getStorage(app);
```

### 2. Install Firebase Storage Package (if not installed)

**Directory: `admin-portal/`**

Run: `npm install firebase` (likely already installed, but ensures storage module is available)

### 3. Update DeckForm Component

**File: `admin-portal/src/components/DeckForm.tsx`**

**Add imports:**

```typescript
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { storage } from '../config/firebase';
import { Upload, X } from 'lucide-react';
```

**Add new state variables:**

```typescript
const [imageFile, setImageFile] = useState<File | null>(null);
const [imagePreview, setImagePreview] = useState<string | null>(deck?.imageUrl || null);
const [isUploading, setIsUploading] = useState(false);
const [uploadError, setUploadError] = useState<string>('');
```

**Add image upload handler:**

```typescript
const handleImageUpload = async (file: File) => {
  // Validate file type
  const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
  if (!validTypes.includes(file.type)) {
    setUploadError('Please upload a JPG, PNG, or WebP image');
    return;
  }

  // Validate file size (10MB)
  if (file.size > 10 * 1024 * 1024) {
    setUploadError('Image must be less than 10MB');
    return;
  }

  setUploadError('');
  setIsUploading(true);

  try {
    // Generate unique filename
    const timestamp = Date.now();
    const filename = `${timestamp}_${file.name}`;
    
    // Use temporary ID if creating new deck, or existing ID if editing
    const deckId = deck?.id || `temp_${timestamp}`;
    const storageRef = ref(storage, `deck-images/${deckId}/${filename}`);
    
    // Upload file
    await uploadBytes(storageRef, file);
    
    // Get download URL
    const downloadURL = await getDownloadURL(storageRef);
    
    setImageUrl(downloadURL);
    setImagePreview(downloadURL);
    setImageFile(file);
    setIsUploading(false);
  } catch (error) {
    console.error('Error uploading image:', error);
    setUploadError('Failed to upload image. Please try again.');
    setIsUploading(false);
  }
};

const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
  const file = e.target.files?.[0];
  if (file) {
    handleImageUpload(file);
  }
};

const removeImage = () => {
  setImageFile(null);
  setImagePreview(null);
  setImageUrl('');
};
```

**Update the image URL section in JSX:**

Replace the existing imageUrl form-group with:

```tsx
<div className="form-group">
  <label>Deck Image</label>
  
  {/* Upload Button */}
  <div style={{ marginBottom: '12px' }}>
    <input
      type="file"
      id="imageUpload"
      accept="image/jpeg,image/jpg,image/png,image/webp"
      onChange={handleFileSelect}
      style={{ display: 'none' }}
      disabled={isUploading}
    />
    <button
      type="button"
      onClick={() => document.getElementById('imageUpload')?.click()}
      disabled={isUploading}
      style={{
        padding: '10px 16px',
        backgroundColor: isUploading ? '#ccc' : '#4CAF50',
        color: 'white',
        border: 'none',
        borderRadius: '6px',
        cursor: isUploading ? 'not-allowed' : 'pointer',
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
      }}
    >
      <Upload size={18} />
      {isUploading ? 'Uploading...' : 'Upload Image'}
    </button>
  </div>

  {/* Image Preview */}
  {imagePreview && (
    <div style={{ position: 'relative', display: 'inline-block', marginBottom: '12px' }}>
      <img
        src={imagePreview}
        alt="Deck preview"
        style={{
          width: '200px',
          height: '120px',
          objectFit: 'cover',
          borderRadius: '8px',
          border: '2px solid #e0e0e0',
        }}
      />
      <button
        type="button"
        onClick={removeImage}
        style={{
          position: 'absolute',
          top: '-8px',
          right: '-8px',
          backgroundColor: '#f44336',
          color: 'white',
          border: 'none',
          borderRadius: '50%',
          width: '24px',
          height: '24px',
          cursor: 'pointer',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <X size={16} />
      </button>
    </div>
  )}

  {/* Error Message */}
  {uploadError && (
    <div style={{ color: '#f44336', fontSize: '14px', marginBottom: '8px' }}>
      {uploadError}
    </div>
  )}

  {/* URL Input (editable after upload) */}
  <div>
    <label htmlFor="imageUrl" style={{ fontSize: '13px', color: '#666' }}>
      Or paste image URL
    </label>
    <input
      type="url"
      id="imageUrl"
      value={imageUrl}
      onChange={(e) => {
        setImageUrl(e.target.value);
        setImagePreview(e.target.value);
      }}
      placeholder="https://example.com/image.jpg"
      disabled={isUploading}
    />
    <small style={{ color: '#666', fontSize: '12px' }}>
      Accepted: JPG, PNG, WebP (max 10MB)
    </small>
  </div>
</div>
```

### 4. Update Firebase Storage Rules

**Firebase Console > Storage > Rules**

Add rule to allow authenticated uploads to deck-images:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /deck-images/{deckId}/{filename} {
      allow read: if true; // Public read for all images
      allow write: if request.auth != null // Only authenticated users can upload
                   && request.resource.size < 10 * 1024 * 1024 // 10MB limit
                   && request.resource.contentType.matches('image/(jpeg|jpg|png|webp)');
    }
  }
}
```

## Key Features

- File upload button with file picker
- Real-time image preview after upload
- Remove image button (X icon on preview)
- Upload progress indication (button shows "Uploading...")
- File type validation (JPG, PNG, WebP only)
- File size validation (max 10MB)
- Error messages for validation failures
- URL remains editable after upload
- Images organized in Firebase Storage: `deck-images/{deckId}/filename`
- Public read access, authenticated write access

## Testing

1. Create a new deck and upload an image
2. Verify image appears in Firebase Storage under `deck-images/temp_{timestamp}/`
3. Edit existing deck and upload image - should store under `deck-images/{deckId}/`
4. Test validation by uploading invalid file types
5. Test validation by uploading files > 10MB
6. Verify image URL is saved in Firestore
7. Verify uploaded image displays in Flutter app