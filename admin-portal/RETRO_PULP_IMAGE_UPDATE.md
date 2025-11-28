# Retro Pulp Poster Image Prompt Update

## Summary

Updated the deck image generation system to use a **retro pulp poster aesthetic** with concise, formula-based prompts instead of the previous overly-explained modern style.

## Changes Made

### 1. Updated `generateImagePrompt()` Function

**Before:** Long, verbose prompts with modern, sleek aesthetic
**After:** Concise retro pulp poster prompts following a strict formula

**New Formula:**
```
App-store deck thumbnail, 3:4 poster (1024×1365), [retro/vintage/pulp] [DECK NAME IN CAPS]; [logo descriptions with visual effects], [color palette], [texture effects], [typography description].
```

**Key Guidelines:**
- DECK NAME always in CAPS
- Use accurate brand logos when relevant (Netflix N, NBA logo, TikTok, etc.)
- 2-3 color palettes only (e.g., "neon pink/teal on dark", "red/ink-black")
- **MANDATORY**: worn paper + halftone texture (e.g., "worn paper + halftone grain", "distressed paper + print dots")
- Bold, readable typography (e.g., "bold diagonal type", "chunky type")
- Always end with "clean safe margins" or "safe margins"

**Examples from the new system:**

- **Viral TikTok Trends**: "App-store deck thumbnail, 3:4 poster (1024×1365), retro pulp poster VIRAL TIKTOK TRENDS; TikTok logo centered with motion streaks, bold diagonal type, neon pink/teal on dark, worn paper + halftone grain, high contrast, clean safe margins."

- **Netflix Originals**: "App-store deck thumbnail, 3:4 poster (1024×1365), vintage pulp NETFLIX ORIGINALS; large Netflix 'N' ribbon logo with cinematic glow, red/ink-black palette, distressed paper, print dots, big readable headline."

- **Gaming Icons Mix**: "App-store deck thumbnail, 3:4 poster (1024×1365), retro pulp GAMING ICONS; grid of Fortnite, Minecraft, Roblox logos, chunky type, limited palette, halftone, paper scuffs, subtle shadow."

### 2. Updated `generateFallbackPrompt()` Function

The fallback template now follows the same retro pulp formula with randomized elements:
- Style variants: 'retro pulp', 'vintage pulp', 'retro pulp poster'
- 9 retro color palettes
- 5 texture combinations (all include halftone + worn paper)
- 9 typography styles (all bold and readable)

### 3. Updated Default Style Preference

Changed from `'sleek modern'` to `'retro pulp'` as the default style.

### 4. Updated `generateImageVariations()` Function

Style variations now include:
- 'retro pulp'
- 'vintage pulp'
- 'retro pulp poster'
- 'vintage pulp poster'
- 'pulp poster'

### 5. Fixed Image Cropping

Updated `cropImageTo1024x1365()` to correctly handle the source dimensions:
- **Source**: 1024x1536 (from gpt-image-1)
- **Target**: 1024x1365 (3:4 ratio for app store)
- **Crop**: 85.5px from top and bottom (center crop)

### 6. Updated Metadata

Changed upload metadata to reflect correct dimensions:
- `originalSize: '1024x1536'`
- `croppedSize: '1024x1365'`

## Technical Details

### ChatGPT System Prompt

The new system prompt instructs ChatGPT to:
1. Follow a strict formula
2. Keep prompts under 100 words
3. Always include mandatory elements (size, texture, safe margins)
4. Use accurate brand logos when applicable
5. Avoid faces/celebs (to dodge likeness issues)
6. Maintain 2-3 color palettes
7. Focus on bold, legible typography

### Temperature & Token Limits

- **Temperature**: 0.7 (balanced creativity)
- **Max Tokens**: 200 (shorter, more focused prompts)
- **Model**: gpt-4o-mini (fast and cost-effective)

## Benefits

1. **Concise Prompts**: Under 100 words vs. 200+ words previously
2. **Consistent Style**: All images follow the retro pulp aesthetic
3. **Better Quality**: More focused prompts = better image generation
4. **Readable on Mobile**: "Safe margins" ensures text is readable
5. **Brand-Safe**: Avoids celebrity faces, uses official logos only
6. **Texture-Rich**: Mandatory halftone + worn paper creates vintage feel

## File Modified

- `/admin-portal/src/services/aiImageService.ts`

## Next Steps

Test the new image generation with various deck topics to verify:
- Images have the retro pulp aesthetic
- Text is readable with safe margins
- Colors are limited to 2-3 per image
- Halftone and paper texture are visible
- Brand logos are accurate (when applicable)

---

**Date**: November 14, 2025  
**Status**: ✅ Complete - All linter errors resolved

