# Fix Camera & Microphone Permissions

## Issue: App Not Asking for Permissions

If the app is not showing the permission dialog for camera and microphone, it's likely because:

1. **Permissions were previously denied** - iOS won't ask again automatically
2. **App needs to be completely reinstalled** - To reset permission state

## Solution Steps:

### Method 1: Delete and Reinstall App (Recommended)

1. **Delete the app** from your iPhone (long press icon → Remove App → Delete App)
2. **Stop Flutter** in terminal (press `q`)
3. **Run the app again**: `flutter run -d [your-device-id]`
4. When you tap the camera icon or start a game, you should see permission dialogs

### Method 2: Reset Permissions in iOS Settings

1. Go to **Settings** on your iPhone
2. Scroll down to **Heads Up** (your app)
3. Check if Camera and Microphone are listed:
   - If yes: Toggle them ON
   - If no: The app hasn't requested them yet

### Method 3: Reset All Location & Privacy

⚠️ This resets ALL app permissions on your device

1. Settings → General → Transfer or Reset iPhone
2. Reset → Reset Location & Privacy
3. Enter passcode
4. This will make all apps ask for permissions again

## Testing After Fix:

1. **Test with Camera Button**:

   - Open app
   - Tap camera icon in top right
   - Should see permission dialogs

2. **Test in Game**:
   - Ensure "Record Reactions" is ON in Settings
   - Start a game
   - Check console for messages

## Expected Console Output:

When permissions are working correctly:

```
flutter: Checking camera permissions...
flutter: Camera permission status: PermissionStatus.denied
flutter: Camera permission is denied, requesting...
flutter: Camera permission request result: PermissionStatus.granted
flutter: Checking microphone permissions...
flutter: Microphone permission status: PermissionStatus.denied
flutter: Microphone permission is denied, requesting...
flutter: Microphone permission request result: PermissionStatus.granted
flutter: All permissions granted!
```

## If Still Not Working:

1. **Check Info.plist** - Ensure permission descriptions are present
2. **Clean build**:

   ```bash
   flutter clean
   cd ios
   rm -rf Pods
   rm Podfile.lock
   pod install --repo-update
   cd ..
   flutter run
   ```

3. **Use Xcode**:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Clean Build Folder (Shift+Cmd+K)
   - Run from Xcode
   - Check Xcode console for any permission-related errors

## Debug Information:

The app now logs detailed permission status. Look for these in console:

- `Camera permission status: [status]`
- `Microphone permission status: [status]`

Possible statuses:

- `denied` - Not yet requested
- `granted` - Permission given
- `restricted` - Parental controls
- `permanentlyDenied` - User denied and must enable in Settings
- `provisional` - Temporary access
