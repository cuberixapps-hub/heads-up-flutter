# Tilt Sensor Fix Summary

## Problem Description

1. **Issue 1**: The gameplay sensors were incorrectly marking all cards as "correct" when the phone was kept tilted downward for a few seconds.
2. **Issue 2**: In landscape mode, tilting the phone left/right (sideways head tilt) was incorrectly triggering correct/pass actions instead of being ignored.

## Root Cause Analysis

### Issue 1 - Continuous Triggering:

1. **No Neutral Position Requirement**: The original code didn't require the phone to return to a neutral position between actions
2. **Improper State Reset**: The `_hasTriggeredAction` and `_canDetectTilt` flags were being reset after a delay, allowing continuous triggering if the phone remained tilted
3. **Missing Debounce**: No time-based debouncing between consecutive actions

### Issue 2 - Wrong Axis Detection in Landscape:

1. **Incorrect Axis Mapping**: The code was using Z-axis (deltaZ) for landscape mode, but Z-axis represents rotation around screen normal, not forward/backward tilt
2. **Misunderstanding of Accelerometer Axes**: When phone is in landscape, Y-axis still detects forward/backward tilt (nodding), while X-axis detects left/right tilt (head tilting)

## Solution Implemented

### For Issue 1 - Continuous Triggering:

#### 1. Neutral Position Detection

- Added `_isInNeutralPosition` flag to track when the phone is in neutral position
- Defined `_neutralThreshold` (15.0 degrees) to determine neutral zone
- Actions can only trigger when starting from neutral position

#### 2. Time-Based Debouncing

- Added `_lastActionTime` to track when the last action occurred
- Implemented `_minTimeBetweenActions` (500ms) to prevent rapid consecutive triggers
- Both tilt and manual controls respect this timing constraint

#### 3. Improved State Management

- Removed redundant state checks in action handlers
- State flags reset only when phone returns to neutral, not after a timer
- Proper state reset when pausing/resuming or switching control modes

### For Issue 2 - Incorrect Axis Detection:

#### 1. Fixed Axis Mapping for Landscape Mode

- Changed from using Z-axis to Y-axis for forward/backward tilt detection in landscape
- Y-axis correctly detects nodding motion regardless of phone orientation
- X-axis now properly used to filter out sideways head tilts

#### 2. Enhanced Sideways Tilt Filtering

- Added `sidewaysTilt` variable to track X-axis movement
- Different thresholds for landscape (8.0) and portrait (5.0) modes
- Ignores any input when significant sideways tilt is detected

#### 3. Added Debug Support

- Optional debug flag to log accelerometer values
- Helps diagnose tilt detection issues in production

## Key Changes

### New Variables Added

```dart
bool _isInNeutralPosition = true;
DateTime? _lastActionTime;
static const _minTimeBetweenActions = Duration(milliseconds: 500);
static const _neutralThreshold = 15.0;
static const _debugAccelerometer = false;
```

### Corrected Accelerometer Logic

```dart
// Landscape mode:
tiltAngle = deltaY * 10;  // Y-axis for forward/backward (nodding)
sidewaysTilt = deltaX;     // X-axis for left/right filtering

// Portrait mode:
tiltAngle = deltaY * 10;  // Y-axis for forward/backward
sidewaysTilt = deltaX;     // X-axis for left/right filtering
```

### Accelerometer Logic Flow

1. Check if tilt detection is enabled and calibrated
2. Calculate tilt angle relative to calibrated position
3. **NEW**: Filter out sideways tilts (X-axis movement)
4. If angle is within neutral threshold:
   - Mark as in neutral position
   - Reset trigger flag if returning from tilt
5. If outside neutral threshold:
   - Check if enough time has passed since last action
   - Check if starting from neutral position
   - Only then process the tilt action

### Benefits

- **Prevents Continuous Triggering**: Phone must return to neutral before next action
- **Eliminates False Positives**: Can't accidentally trigger multiple actions by holding tilt
- **Correct Axis Detection**: Properly detects forward/backward tilt in both orientations
- **Filters Unwanted Motion**: Ignores sideways tilts and rotations
- **Smooth Gameplay**: Natural feel with proper debouncing
- **Consistent Behavior**: Same timing logic for both tilt and manual controls

## Testing Recommendations

### For Continuous Triggering Fix:

1. Hold phone tilted backward (correct position) for several seconds - should only trigger once
2. Hold phone tilted forward (pass position) for several seconds - should only trigger once
3. Rapidly tilt back and forth - should respect minimum time between actions
4. Test switching between manual and tilt controls mid-game
5. Test pause/resume functionality with phone in various positions

### For Landscape Axis Fix:

1. **In Landscape Mode**: Tilt phone up/down (nodding) - should trigger correct/pass
2. **In Landscape Mode**: Tilt phone left/right (head tilting sideways) - should NOT trigger anything
3. **In Portrait Mode**: Verify forward/backward tilt still works correctly
4. Test diagonal tilts - should be ignored if sideways component is too large

## Technical Notes

- The neutral threshold (15°) provides a comfortable dead zone
- The 500ms debounce time prevents accidental double-triggers while maintaining responsiveness
- Sideways tilt thresholds: 8.0 for landscape, 5.0 for portrait (tuned for natural gameplay)
- Y-axis is the primary detection axis for forward/backward tilt in both orientations
- Z-axis is completely ignored as it represents rotation around screen normal
- Debug mode available for troubleshooting accelerometer values in production
