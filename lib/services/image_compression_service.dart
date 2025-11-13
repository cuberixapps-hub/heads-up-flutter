import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'firebase_service.dart';

class ImageCompressionService {
  static final ImageCompressionService _instance = ImageCompressionService._internal();
  factory ImageCompressionService() => _instance;
  ImageCompressionService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  // Configuration
  static const int maxWidth = 800;
  static const int maxHeight = 800;
  static const int targetQuality = 85;
  static const int maxSizeKB = 200;
  
  /// Compress an image file
  Future<File?> compressImageFile(
    File file, {
    int quality = targetQuality,
    int maxWidth = maxWidth,
    int maxHeight = maxHeight,
  }) async {
    try {
      // Get original file size
      final originalSize = await file.length();
      
      // Generate output path
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.webp',
      );
      
      // Compress the image
      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.webp,
      );
      
      if (result == null) {
        debugPrint('Failed to compress image');
        return null;
      }
      
      final compressedFile = File(result.path);
      final compressedSize = await compressedFile.length();
      
      // If compressed file is still too large, try with lower quality
      if (compressedSize > maxSizeKB * 1024 && quality > 60) {
        return compressImageFile(
          file,
          quality: quality - 10,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
      }
      
      // Log compression results
      await _firebaseService.logEvent('image_compressed', parameters: {
        'original_size_kb': originalSize ~/ 1024,
        'compressed_size_kb': compressedSize ~/ 1024,
        'compression_ratio': ((1 - compressedSize / originalSize) * 100).round(),
        'quality': quality,
        'format': 'webp',
      });
      
      debugPrint('Image compressed: ${originalSize ~/ 1024}KB -> ${compressedSize ~/ 1024}KB');
      
      return compressedFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Image compression failed',
      );
      return null;
    }
  }
  
  /// Compress image bytes (for camera/picked images)
  Future<Uint8List?> compressImageBytes(
    Uint8List bytes, {
    int quality = targetQuality,
    int maxWidth = maxWidth,
    int maxHeight = maxHeight,
  }) async {
    try {
      final originalSize = bytes.length;
      
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.webp,
      );
      
      final compressedSize = result.length;
      
      // If compressed file is still too large, try with lower quality
      if (compressedSize > maxSizeKB * 1024 && quality > 60) {
        return compressImageBytes(
          bytes,
          quality: quality - 10,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
      }
      
      // Log compression results
      await _firebaseService.logEvent('image_compressed', parameters: {
        'original_size_kb': originalSize ~/ 1024,
        'compressed_size_kb': compressedSize ~/ 1024,
        'compression_ratio': ((1 - compressedSize / originalSize) * 100).round(),
        'quality': quality,
        'format': 'webp',
      });
      
      debugPrint('Image bytes compressed: ${originalSize ~/ 1024}KB -> ${compressedSize ~/ 1024}KB');
      
      return result;
    } catch (e) {
      debugPrint('Error compressing image bytes: $e');
      await _firebaseService.crashlytics.recordError(
        e,
        null,
        reason: 'Image bytes compression failed',
      );
      return null;
    }
  }
  
  /// Get image dimensions
  Future<ImageDimensions?> getImageDimensions(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decodedImage = await ui.instantiateImageCodec(bytes);
      final frame = await decodedImage.getNextFrame();
      final image = frame.image;
      
      return ImageDimensions(
        width: image.width,
        height: image.height,
      );
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
      return null;
    }
  }
  
  /// Check if image needs compression based on file size
  Future<bool> needsCompression(File file) async {
    try {
      final size = await file.length();
      return size > maxSizeKB * 1024;
    } catch (e) {
      return true; // Compress by default if we can't determine size
    }
  }
  
  /// Auto-compress image if needed
  Future<File> autoCompress(File file) async {
    final needsComp = await needsCompression(file);
    
    if (!needsComp) {
      debugPrint('Image doesn\'t need compression: ${await file.length() ~/ 1024}KB');
      return file;
    }
    
    final compressed = await compressImageFile(file);
    return compressed ?? file; // Return original if compression fails
  }
  
  /// Compress multiple images in batch
  Future<List<File?>> compressMultipleImages(
    List<File> files, {
    void Function(int current, int total)? onProgress,
  }) async {
    final results = <File?>[];
    
    for (int i = 0; i < files.length; i++) {
      onProgress?.call(i + 1, files.length);
      final compressed = await autoCompress(files[i]);
      results.add(compressed);
    }
    
    return results;
  }
  
  /// Clean up temporary compressed files
  Future<void> cleanupTempFiles() async {
    try {
      final dir = await getTemporaryDirectory();
      final tempFiles = dir.listSync()
          .where((file) => file.path.contains('_compressed'))
          .toList();
      
      for (final file in tempFiles) {
        await file.delete();
      }
      
      debugPrint('Cleaned up ${tempFiles.length} temporary compressed files');
    } catch (e) {
      debugPrint('Error cleaning up temp files: $e');
    }
  }
}

class ImageDimensions {
  final int width;
  final int height;
  
  ImageDimensions({required this.width, required this.height});
  
  double get aspectRatio => width / height;
  
  bool get isLandscape => width > height;
  bool get isPortrait => height > width;
  bool get isSquare => width == height;
}
