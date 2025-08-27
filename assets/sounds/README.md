# Sound Assets

This directory contains sound effects for the Heads Up game.

## ⚠️ IMPORTANT: Sound Files Missing!

The sound files are not included in the repository. You need to add them manually.

## Required Sound Files

### 🎵 Supported Formats

- **WAV files** (.wav) - Uncompressed, high quality, larger size
- **MP3 files** (.mp3) - Compressed, smaller size

The app will automatically try both formats!

### Game Actions (Priority)

1. **correct** OR **ting** - A pleasant "ting" or bell sound for correct answers
   - Accepts: `correct.wav`, `correct.mp3`, `ting.wav`, `ting.mp3`
2. **pass** OR **page_tear** - A paper tearing/ripping sound for passed cards
   - Accepts: `pass.wav`, `pass.mp3`, `page_tear.wav`, `page_tear.mp3`

### Other Sounds

- **countdown** - Countdown timer sound (3, 2, 1)
- **time_up** - Time's up notification sound
- **click** - UI button click sound
- **success** - General success/achievement sound
- **victory** - Victory/game complete celebration sound

All sounds accept both .wav and .mp3 formats!

## Where to Get Sound Files

### Free Sound Resources:

1. **Freesound.org** - Free sounds with various licenses
2. **Zapsplat.com** - Free sounds (requires free account)
3. **Mixkit.co** - Royalty-free sound effects
4. **Freesoundslibrary.com** - No attribution required

### Recommended Searches:

- For correct sound: "bell ting", "success chime", "correct ding"
- For pass sound: "paper tear", "page flip", "whoosh"
- For countdown: "beep countdown", "timer tick"
- For time up: "alarm bell", "buzzer", "time's up"

## Sound Guidelines

- Keep sounds short (under 1 second for action sounds)
- Use clear, distinct sounds that provide good feedback
- File format: MP3 (for compatibility)
- Bitrate: 128kbps or higher
- Volume: Normalized, not too loud

## Quick Setup Instructions

1. Download the required sound files from the resources above
2. Place them in this directory (`assets/sounds/`)
3. Name them exactly as specified above
4. Run `flutter pub get` to refresh assets
5. Restart the app

## Implementation Notes

- The AudioService will automatically fallback to alternative sounds if primary sounds are not found
- Correct action: Tries ting.mp3 first, falls back to correct.mp3
- Pass action: Tries page_tear.mp3 first, falls back to pass.mp3
- Sound can be toggled on/off in Settings
