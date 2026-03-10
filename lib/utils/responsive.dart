import 'package:flutter/widgets.dart';

/// Responsive utility for scaling UI elements based on screen size.
/// Design baseline: iPhone 16 Pro Max (440 x 956 logical pixels)
///
/// All UI elements (sizes, paddings, margins, font sizes, icon sizes, border radius,
/// etc.) should be defined using their iPhone 16 Pro Max values and scaled through
/// this utility so every smaller iPhone renders the same visual proportions.
class Responsive {
  static double _screenWidth = 0;
  static double _screenHeight = 0;
  static double _scaleFactor = 1;
  static double _verticalScaleFactor = 1;
  static double _textScaleFactor = 1;
  static bool _initialized = false;

  // Design baseline dimensions (iPhone 16 Pro Max logical pixels)
  static const double _baselineWidth = 440.0;
  static const double _baselineHeight = 956.0;

  /// Initialize responsive utility with screen dimensions.
  /// Call this once in your MaterialApp's builder or at the root widget.
  static void init(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Skip if dimensions haven't changed
    if (_initialized && size.width == _screenWidth && size.height == _screenHeight) {
      return;
    }

    _screenWidth = size.width;
    _screenHeight = size.height;

    // Primary scale factor based on width ratio
    _scaleFactor = _screenWidth / _baselineWidth;

    // Vertical scale factor based on height ratio
    _verticalScaleFactor = _screenHeight / _baselineHeight;

    // Text scaling uses the minimum of width and height scaling
    // with dampening to keep text readable on very small screens
    final rawTextScale =
        (_scaleFactor < _verticalScaleFactor) ? _scaleFactor : _verticalScaleFactor;
    _textScaleFactor = rawTextScale.clamp(0.75, 1.25);

    _initialized = true;

    debugPrint('📱 Responsive Initialized:');
    debugPrint(
      '   Screen: ${_screenWidth.toStringAsFixed(1)} x ${_screenHeight.toStringAsFixed(1)}',
    );
    debugPrint('   Scale Factor: ${_scaleFactor.toStringAsFixed(3)}');
    debugPrint('   Vertical Scale: ${_verticalScaleFactor.toStringAsFixed(3)}');
    debugPrint('   Text Scale: ${_textScaleFactor.toStringAsFixed(3)}');
  }

  /// Scale a horizontal / width value based on design baseline width.
  static double w(double designWidth) {
    return designWidth * _scaleFactor;
  }

  /// Scale a vertical / height value based on design baseline height.
  static double h(double designHeight) {
    return designHeight * _verticalScaleFactor;
  }

  /// Scale font size – uses the minimum of width & height factors clamped
  /// for readability so text never gets too tiny or too large.
  static double sp(double fontSize) {
    return fontSize * _textScaleFactor;
  }

  /// Scale general sizes (padding, margin, radius, icon sizes, etc.)
  /// Uses width-based scaling since most UI elements reference horizontal space.
  static double s(double size) {
    return size * _scaleFactor;
  }

  /// Scale a value by the average of width and height factors.
  /// Useful for elements that must look proportional in both axes (e.g. circles).
  static double avg(double size) {
    return size * ((_scaleFactor + _verticalScaleFactor) / 2);
  }

  /// Get screen width
  static double get screenWidth => _screenWidth;

  /// Get screen height
  static double get screenHeight => _screenHeight;

  /// Get width-based scale factor
  static double get scale => _scaleFactor;

  /// Get height-based scale factor
  static double get verticalScale => _verticalScaleFactor;

  /// Get text scale factor
  static double get textScale => _textScaleFactor;

  /// Check if device is small (iPhone SE, iPhone 13 mini, etc.)
  static bool get isSmallDevice => _screenWidth < 375;

  /// Check if device is medium (iPhone 16, iPhone 15, etc.)
  static bool get isMediumDevice => _screenWidth >= 375 && _screenWidth < 414;

  /// Check if device is large (iPhone 16 Plus, iPhone 15 Pro Max, etc.)
  static bool get isLargeDevice => _screenWidth >= 414;

  /// Check if device is extra large (iPad, etc.)
  static bool get isTablet => _screenWidth >= 600;
}

/// Extension on num for easy responsive access
extension ResponsiveExtension on num {
  /// Width scaling
  double get w => Responsive.w(toDouble());

  /// Height scaling
  double get h => Responsive.h(toDouble());

  /// Font size scaling
  double get sp => Responsive.sp(toDouble());

  /// General size scaling (padding, margin, radius, icon size)
  double get s => Responsive.s(toDouble());

  /// Average of width + height scaling (good for circles / squares)
  double get avg => Responsive.avg(toDouble());
}
