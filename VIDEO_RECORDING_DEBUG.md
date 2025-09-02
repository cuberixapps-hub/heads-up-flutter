# Video Recording Debug Guide

## Testing Steps

### 1. Test Camera Access

1. Launch the app on your iPhone
2. On the home screen, tap the camera icon in the top app bar
3. This opens the Test Camera Screen where you can:
   - Check if permissions are granted
   - See if the camera initializes properly
   - Test start/stop recording functionality
   - View the file path where videos are saved

### 2. Enable Recording in Settings

1. Go to Settings screen (gear icon)
2. Ensure "Record Reactions" toggle is ON
3. This preference defaults to ON but verify it's enabled

### 3. Test During Gameplay

1. Start a regular game (not team mode for now)
2. Watch the debug console for these messages:
   ```
   Checking camera preference...
   Camera enabled preference: true
   Initializing camera service...
   Camera initialized successfully
   _startVideoRecording called. Camera enabled: true
   Starting video recording...
   Video recording started successfully
   ```

### 4. After Game Ends

1. Check console for:
   ```
   _stopRecordingAndNavigate called. Is recording: true
   Stopping video recording...
   Recording result received. Video path: /path/to/video
   Recording result stored in GameProvider
   ```
2. On Results screen, look for:
   ```
   VideoSection initState called
   Video recording result: Found
   Video path: /path/to/video
   Duration: X seconds
   ```

## Common Issues & Solutions

### Issue: Camera not initializing

- **Symptoms**: "Camera initialization failed" in console
- **Solutions**:
  1. Check iOS Settings > Heads Up > Camera & Microphone permissions
  2. Delete and reinstall the app to trigger permission prompts
  3. Try on a real device (not simulator)

### Issue: Recording not starting

- **Symptoms**: No "Video recording started" message
- **Solutions**:
  1. Verify "Record Reactions" is enabled in settings
  2. Check camera permissions in iOS settings
  3. Ensure enough storage space on device

### Issue: Video not showing in results

- **Symptoms**: No video section in results screen
- **Solutions**:
  1. Check if recording actually started during gameplay
  2. Verify recording was stopped properly
  3. Check console for any error messages

## Debug Console Commands

While the app is running, you can monitor the console output:

```bash
# If running via Xcode
# Check the Xcode console output

# If running via flutter run
# The debug messages will appear in the terminal
```

## Permissions Check

Ensure these permissions are granted in iOS Settings:

- Camera: Required for video recording
- Microphone: Required for audio in videos
- Photos: Required for saving videos to gallery

## Test Scenarios

1. **Fresh Install Test**:

   - Delete app
   - Install fresh
   - Accept all permissions
   - Test recording

2. **Permission Denied Test**:

   - Deny camera permission
   - Try to play game
   - Should skip recording gracefully

3. **Mid-Game Interruption Test**:
   - Start game with recording
   - Switch apps mid-game
   - Return and complete game
   - Check if video is saved

## Video File Locations

Videos are temporarily stored in:

- iOS: App's temporary directory
- Path format: `/tmp/reaction_[timestamp].mp4`

After processing, they can be:

- Saved to Photos app
- Shared via share sheet
- Deleted from temporary storage

## Next Steps

Once basic recording works:

1. Test on different devices
2. Test with different game modes
3. Verify memory usage is reasonable
4. Test edge cases (low storage, interruptions)
