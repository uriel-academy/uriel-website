import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageCompressionService {
  static final ImageCompressionService _instance = ImageCompressionService._internal();
  factory ImageCompressionService() => _instance;
  ImageCompressionService._internal();

  // Limits
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int maxWidthPixels = 1920;
  static const int maxHeightPixels = 1080;
  static const int jpegQuality = 85;

  /// Validate and compress image bytes
  /// Returns compressed bytes or null if invalid
  Future<Uint8List?> processImage(Uint8List bytes, {
    String? fileName,
    required Function(String) onError,
  }) async {
    try {
      // Validate file size
      final originalSize = bytes.length;
      debugPrint('📸 Processing image: ${_formatBytes(originalSize)}');

      if (originalSize > 50 * 1024 * 1024) { // 50MB absolute limit
        onError('Image too large! Maximum size is 50MB. Your image: ${_formatBytes(originalSize)}');
        return null;
      }

      // Decode image
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        onError('Invalid image format. Please use JPG, PNG, GIF, or WebP.');
        return null;
      }

      debugPrint('📐 Original dimensions: ${image.width}x${image.height}');

      // Resize if too large
      bool needsResize = image.width > maxWidthPixels || image.height > maxHeightPixels;
      if (needsResize) {
        debugPrint('🔄 Resizing image...');
        
        // Calculate aspect ratio
        double aspectRatio = image.width / image.height;
        int newWidth = maxWidthPixels;
        int newHeight = (newWidth / aspectRatio).round();
        
        if (newHeight > maxHeightPixels) {
          newHeight = maxHeightPixels;
          newWidth = (newHeight * aspectRatio).round();
        }
        
        image = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
        
        debugPrint('✅ Resized to: ${image.width}x${image.height}');
      }

      // Compress to JPEG
      final compressed = Uint8List.fromList(
        img.encodeJpg(image, quality: jpegQuality)
      );

      final compressedSize = compressed.length;
      final reductionPercent = ((originalSize - compressedSize) / originalSize * 100).toStringAsFixed(1);
      
      debugPrint('✅ Compressed: ${_formatBytes(originalSize)} → ${_formatBytes(compressedSize)} ($reductionPercent% reduction)');

      // Final size check
      if (compressedSize > maxFileSizeBytes) {
        // Try more aggressive compression
        final moreCompressed = Uint8List.fromList(
          img.encodeJpg(image, quality: 70)
        );
        
        if (moreCompressed.length > maxFileSizeBytes) {
          onError('Image still too large after compression. Please use a smaller image.');
          return null;
        }
        
        debugPrint('🔽 Applied aggressive compression: ${_formatBytes(moreCompressed.length)}');
        return moreCompressed;
      }

      return compressed;

    } catch (e) {
      debugPrint('❌ Image processing error: $e');
      onError('Failed to process image: ${e.toString()}');
      return null;
    }
  }

  /// Quick validation without processing
  bool isValidSize(int bytes) {
    return bytes <= 50 * 1024 * 1024; // 50MB max
  }

  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Get compression info without processing
  String getCompressionInfo(int originalBytes) {
    if (originalBytes <= maxFileSizeBytes) {
      return 'Image size OK';
    }
    
    final estimatedCompressed = originalBytes * 0.3; // Rough estimate
    if (estimatedCompressed <= maxFileSizeBytes) {
      return 'Will be compressed to ~${_formatBytes(estimatedCompressed.toInt())}';
    }
    
    return 'Too large - please use smaller image';
  }
}
