import 'package:flutter/widgets.dart';

/// Responsive utility for scaling UI elements based on screen size.
/// Design baseline: iPhone 16 Plus (430 x 932 logical pixels)
class Responsive {
  static late double _screenWidth;
  static late double _screenHeight;
  static late double _scaleFactor;
  static late double _textScaleFactor;
  
  // Design baseline dimensions (iPhone 16 Plus)
  static const double _baselineWidth = 430.0;
  static const double _baselineHeight = 932.0;
  
  /// Initialize responsive utility with screen dimensions
  /// Call this once in your MaterialApp's builder or at the root widget
  static void init(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _screenWidth = size.width;
    _screenHeight = size.height;
    
    // Calculate scale factor based on width (primary scaling dimension)
    _scaleFactor = _screenWidth / _baselineWidth;
    
    // For text, use a slightly dampened scaling to avoid text being too small/large
    // This ensures better readability across different screen sizes
    _textScaleFactor = (_scaleFactor - 1) * 0.5 + 1;
    
    debugPrint('📱 Responsive Initialized:');
    debugPrint('   Screen: ${_screenWidth.toStringAsFixed(1)} x ${_screenHeight.toStringAsFixed(1)}');
    debugPrint('   Scale Factor: ${_scaleFactor.toStringAsFixed(3)}');
    debugPrint('   Text Scale: ${_textScaleFactor.toStringAsFixed(3)}');
  }
  
  /// Scale width based on design baseline
  static double w(double designWidth) {
    return designWidth * _scaleFactor;
  }
  
  /// Scale height based on design baseline
  static double h(double designHeight) {
    return designHeight * (_screenHeight / _baselineHeight);
  }
  
  /// Scale font size with dampened scaling for better readability
  static double sp(double fontSize) {
    return fontSize * _textScaleFactor;
  }
  
  /// Scale general sizes (padding, margin, radius, etc.)
  static double s(double size) {
    return size * _scaleFactor;
  }
  
  /// Get screen width
  static double get screenWidth => _screenWidth;
  
  /// Get screen height
  static double get screenHeight => _screenHeight;
  
  /// Get scale factor
  static double get scale => _scaleFactor;
  
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
  
  /// General size scaling
  double get s => Responsive.s(toDouble());
}




