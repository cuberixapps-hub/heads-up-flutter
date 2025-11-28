# DALL-E 3 Quick Reference Card

## 🚀 Basic Usage
```typescript
import { generateDeckImage } from './services/aiImageService';

const imageUrl = await generateDeckImage('Famous Athletes');
```

## 📊 All Parameters

### Quality
| Value | Description | Cost | Use Case |
|-------|-------------|------|----------|
| `standard` | Good quality | $ | Most thumbnails, testing |
| `hd` | High definition | $$$ | Featured content, marketing |

### Style
| Value | Description | Best For |
|-------|-------------|----------|
| `vivid` | Dramatic, hyper-real | Eye-catching designs |
| `natural` | Realistic, photographic | Professional look |

### Size
| Value | Aspect Ratio | Best For |
|-------|--------------|----------|
| `1024x1024` | 1:1 Square | Social media, avatars |
| `1024x1792` | 4:5 Portrait | Mobile app cards, stories |
| `1792x1024` | 5:4 Landscape | Banners, headers |

### Response Format
| Value | Description | Use Case |
|-------|-------------|----------|
| `url` | Temporary URL | Standard workflow |
| `b64_json` | Base64 encoded | Immediate processing |

## 💡 Common Patterns

### 1. Default (Recommended)
```typescript
const url = await generateDeckImage('Sports');
// Quality: standard, Size: portrait, Style: vivid
```

### 2. High Quality
```typescript
const url = await generateDeckImage('Premium Topic', 'retro pulp', {
  quality: 'hd'
});
```

### 3. Photorealistic
```typescript
const url = await generateDeckImage('World Landmarks', 'clean modern', {
  style: 'natural'
});
```

### 4. Square Thumbnail
```typescript
const url = await generateDeckImage('Tech Icons', 'modern', {
  size: '1024x1024'
});
```

### 5. Multiple Variations
```typescript
const urls = await generateImageVariations('Famous Athletes', 3, {
  quality: 'standard'
});
// Returns: [retro, modern, cyber] styles
```

## 💰 Cost Optimization

### Budget-Friendly
```typescript
{
  quality: 'standard',  // ✅ Lower cost
  style: 'natural',     // ✅ Less processing
  size: '1024x1024'     // ✅ Smaller size
}
```

### Premium
```typescript
{
  quality: 'hd',        // 💎 Best quality
  style: 'vivid',       // 💎 Most dramatic
  size: '1024x1792'     // 💎 Portrait
}
```

## 🎨 Style Presets

| Preset | Visual Style | Best Topics |
|--------|-------------|-------------|
| `retro pulp` | Vintage poster | Entertainment, sports |
| `clean modern` | Minimalist | Tech, business |
| `neon cyber` | Futuristic | Gaming, sci-fi |

## ⚡ Quick Recipes

### Recipe 1: Premium Featured Deck
```typescript
await generateDeckImage('Oscar Winners', 'retro pulp', {
  quality: 'hd',
  style: 'vivid',
  size: '1024x1792'
});
```

### Recipe 2: Budget Bulk Generation
```typescript
await generateDeckImage('Random Trivia', 'clean modern', {
  quality: 'standard',
  style: 'natural',
  size: '1024x1024'
});
```

### Recipe 3: Social Media Square
```typescript
await generateDeckImage('Daily Quiz', 'neon cyber', {
  quality: 'standard',
  style: 'vivid',
  size: '1024x1024'
});
```

### Recipe 4: Realistic Portrait
```typescript
await generateDeckImage('Historical Figures', 'clean modern', {
  quality: 'hd',
  style: 'natural',
  size: '1024x1792'
});
```

## 🔧 TypeScript Interface

```typescript
interface DallE3Options {
  quality?: 'standard' | 'hd';
  size?: '1024x1024' | '1024x1792' | '1792x1024';
  style?: 'vivid' | 'natural';
  response_format?: 'url' | 'b64_json';
}

// Usage
const options: DallE3Options = {
  quality: 'hd',
  style: 'vivid'
};
```

## ❌ Common Mistakes

### ❌ Don't
```typescript
// Trying to generate multiple images (DALL-E 3 only supports n=1)
n: 3  // ❌ Not supported

// Invalid size
size: '512x512'  // ❌ Not supported
```

### ✅ Do
```typescript
// Generate variations instead
await generateImageVariations('Topic', 3);

// Use supported sizes
size: '1024x1024'  // ✅
```

## 🐛 Troubleshooting

| Error | Solution |
|-------|----------|
| No image returned | Check API key, credits |
| Rate limit | Implement exponential backoff (built-in) |
| Prompt too long | Simplify prompt (handled automatically) |
| Quality issues | Try `hd` quality or different style |

## 📝 Default Values

When options are omitted:
- Quality: `standard`
- Size: `1024x1792` (portrait)
- Style: `vivid`
- Response format: `url`

## 🔗 Links

- **Official Docs**: https://platform.openai.com/docs/api-reference/images
- **Full Implementation Guide**: `OPENAI_IMAGE_API_IMPLEMENTATION.md`
- **Examples**: `src/services/aiImageService.examples.ts`
- **Summary**: `OPENAI_IMAGE_API_UPDATE_SUMMARY.md`

---

**💡 Pro Tip**: Start with `standard` quality for testing, then upgrade to `hd` for production featured content.

**⚡ Performance Tip**: Use `url` format for simplicity, `b64_json` only when needed for immediate processing.

**💰 Cost Tip**: Batch similar generations and use `standard` quality by default to optimize costs.




