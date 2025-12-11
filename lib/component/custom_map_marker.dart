import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class CustomMapMarker {
  /// Creates a custom bubble marker with price information
  static Future<BitmapDescriptor> createPriceBubbleMarker({
    required String price,
    required String currency,
    required int count,
    required Color backgroundColor,
    double width = 100,
    double height = 80,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Draw bubble background
    final Paint bubblePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw rounded rectangle bubble
    final RRect bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height - 20),
      Radius.circular(12),
    );
    
    canvas.drawRRect(bubbleRect, bubblePaint);
    canvas.drawRRect(bubbleRect, borderPaint);

    // Draw pointer/tail
    final Path pointerPath = Path()
      ..moveTo(width / 2 - 10, height - 20)
      ..lineTo(width / 2, height)
      ..lineTo(width / 2 + 10, height - 20)
      ..close();
    
    canvas.drawPath(pointerPath, bubblePaint);
    canvas.drawPath(pointerPath, borderPaint);

    // Draw text - count
    if (count > 1) {
      final TextPainter countPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      countPainter.text = TextSpan(
        text: '$count items',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      );
      countPainter.layout();
      countPainter.paint(
        canvas,
        Offset((width - countPainter.width) / 2, 8),
      );
    }

    // Draw text - price
    final TextPainter pricePainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    pricePainter.text = TextSpan(
      text: '$currency$price',
      style: TextStyle(
        fontSize: count > 1 ? 16 : 18,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    pricePainter.layout();
    pricePainter.paint(
      canvas,
      Offset(
        (width - pricePainter.width) / 2,
        count > 1 ? 28 : (height - 20 - pricePainter.height) / 2,
      ),
    );

    // Convert canvas to image
    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(
          width.toInt(),
          height.toInt(),
        );

    // Convert image to bytes
    final ByteData? byteData = await markerAsImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List imageBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(imageBytes);
  }

  /// Creates a simple cluster marker with count badge
  static Future<BitmapDescriptor> createClusterMarker({
    required int count,
    required Color color,
    double size = 60,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Draw shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawCircle(
      Offset(size / 2, size / 2 + 2),
      size / 2 - 2,
      shadowPaint,
    );

    // Draw circle
    final Paint circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 2,
      circlePaint,
    );
    
    // Draw border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 2,
      borderPaint,
    );

    // Draw count text
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: '$count',
      style: TextStyle(
        fontSize: count > 99 ? 16 : 20,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    // Convert to image
    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(
          size.toInt(),
          size.toInt(),
        );

    final ByteData? byteData = await markerAsImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List imageBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(imageBytes);
  }
  
  /// Creates an enhanced cluster marker with price information
  static Future<BitmapDescriptor> createEnhancedClusterMarker({
    required int count,
    required String avgPrice,
    required String currency,
    required Color color,
    double size = 80,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Draw shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5);
    
    canvas.drawCircle(
      Offset(size / 2, size / 2 + 3),
      size / 2,
      shadowPaint,
    );

    // Draw outer circle (glow effect)
    final Paint glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      glowPaint,
    );

    // Draw main circle
    final Paint circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 6,
      circlePaint,
    );
    
    // Draw border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 6,
      borderPaint,
    );

    // Draw count text (top)
    final TextPainter countPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    countPainter.text = TextSpan(
      text: '$count',
      style: TextStyle(
        fontSize: 22,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    countPainter.layout();
    countPainter.paint(
      canvas,
      Offset(
        (size - countPainter.width) / 2,
        size / 2 - countPainter.height - 2,
      ),
    );

    // Draw separator line
    final Paint linePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1;
    
    canvas.drawLine(
      Offset(size * 0.3, size / 2),
      Offset(size * 0.7, size / 2),
      linePaint,
    );

    // Draw price text (bottom)
    final TextPainter pricePainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    pricePainter.text = TextSpan(
      text: '$currency$avgPrice',
      style: TextStyle(
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
    pricePainter.layout();
    pricePainter.paint(
      canvas,
      Offset(
        (size - pricePainter.width) / 2,
        size / 2 + 4,
      ),
    );

    // Convert to image
    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(
          size.toInt(),
          size.toInt(),
        );

    final ByteData? byteData = await markerAsImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List imageBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(imageBytes);
  }

  /// Creates a marker with circular service image and price badge
  static Future<BitmapDescriptor> createServiceImageMarker({
    required String imageUrl,
    required String price,
    required String currency,
    double size = 80,
    Color borderColor = Colors.white,
    Color priceBgColor = const Color(0xFF5F60B9),
  }) async {
    try {
      // Load image from network
      ui.Image? serviceImage = await _loadNetworkImage(imageUrl);
      
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final double imageSize = size * 0.75; // 75% of total size for image
      final double priceHeight = size * 0.25; // 25% for price badge

      // Draw shadow for depth
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawCircle(
        Offset(size / 2, imageSize / 2 + 2),
        imageSize / 2,
        shadowPaint,
      );

      // Draw circular image
      if (serviceImage != null) {
        canvas.save();
        
        // Clip to circle
        final Path circlePath = Path()
          ..addOval(Rect.fromCircle(
            center: Offset(size / 2, imageSize / 2),
            radius: imageSize / 2,
          ));
        canvas.clipPath(circlePath);

        // Draw image
        paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(
            (size - imageSize) / 2,
            0,
            imageSize,
            imageSize,
          ),
          image: serviceImage,
          fit: BoxFit.cover,
        );
        
        canvas.restore();
      } else {
        // Fallback if image fails to load - draw colored circle with icon
        final Paint fallbackPaint = Paint()
          ..color = priceBgColor
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(
          Offset(size / 2, imageSize / 2),
          imageSize / 2,
          fallbackPaint,
        );

        // Draw service icon
        final TextPainter iconPainter = TextPainter(
          textDirection: TextDirection.ltr,
        );
        iconPainter.text = TextSpan(
          text: String.fromCharCode(Icons.shopping_bag.codePoint),
          style: TextStyle(
            fontSize: imageSize * 0.4,
            fontFamily: Icons.shopping_bag.fontFamily,
            color: Colors.white,
          ),
        );
        iconPainter.layout();
        iconPainter.paint(
          canvas,
          Offset(
            (size - iconPainter.width) / 2,
            (imageSize - iconPainter.height) / 2,
          ),
        );
      }

      // Draw white border around image
      final Paint borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawCircle(
        Offset(size / 2, imageSize / 2),
        imageSize / 2,
        borderPaint,
      );

      // Draw price badge at bottom
      final double badgeY = imageSize - 5;
      final double badgeHeight = priceHeight + 10;
      final RRect priceBadge = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size * 0.1,
          badgeY,
          size * 0.8,
          badgeHeight,
        ),
        Radius.circular(badgeHeight / 2),
      );

      // Badge shadow
      final Paint badgeShadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawRRect(priceBadge.shift(Offset(0, 1)), badgeShadowPaint);

      // Badge background
      final Paint badgePaint = Paint()
        ..color = priceBgColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(priceBadge, badgePaint);

      // Badge border
      final Paint badgeBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(priceBadge, badgeBorderPaint);

      // Draw price text
      final TextPainter pricePainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      pricePainter.text = TextSpan(
        text: '$currency$price',
        style: TextStyle(
          fontSize: priceHeight * 0.6,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
      pricePainter.layout();
      pricePainter.paint(
        canvas,
        Offset(
          (size - pricePainter.width) / 2,
          badgeY + (badgeHeight - pricePainter.height) / 2,
        ),
      );

      // Convert to image
      final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(
            size.toInt(),
            (imageSize + badgeHeight).toInt(),
          );

      final ByteData? byteData = await markerAsImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List imageBytes = byteData!.buffer.asUint8List();

      return BitmapDescriptor.fromBytes(imageBytes);
    } catch (e) {
      print('Error creating service image marker: $e');
      // Return default marker on error
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  /// Loads an image from network URL
  static Future<ui.Image?> _loadNetworkImage(String url) async {
    try {
      if (url.isEmpty) return null;
      
      final http.Response response = await http.get(Uri.parse(url))
          .timeout(Duration(seconds: 5));
      
      if (response.statusCode != 200) return null;
      
      final Uint8List bytes = response.bodyBytes;
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 150, // Resize for performance
        targetHeight: 150,
      );
      
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      return frameInfo.image;
    } catch (e) {
      print('Error loading network image: $e');
      return null;
    }
  }

  /// Creates a marker with circular service image (simple version without price)
  static Future<BitmapDescriptor> createCircularImageMarker({
    required String imageUrl,
    double size = 60,
    Color borderColor = Colors.white,
    Color backgroundColor = const Color(0xFF5F60B9),
  }) async {
    try {
      ui.Image? serviceImage = await _loadNetworkImage(imageUrl);
      
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);

      // Draw shadow
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawCircle(
        Offset(size / 2, size / 2 + 2),
        size / 2,
        shadowPaint,
      );

      if (serviceImage != null) {
        // Clip to circle
        canvas.save();
        final Path circlePath = Path()
          ..addOval(Rect.fromCircle(
            center: Offset(size / 2, size / 2),
            radius: size / 2 - 2,
          ));
        canvas.clipPath(circlePath);

        // Draw image
        paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(0, 0, size, size),
          image: serviceImage,
          fit: BoxFit.cover,
        );
        
        canvas.restore();
      } else {
        // Fallback colored circle
        final Paint fallbackPaint = Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(
          Offset(size / 2, size / 2),
          size / 2 - 2,
          fallbackPaint,
        );
      }

      // Border
      final Paint borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size / 2 - 2,
        borderPaint,
      );

      // Convert to image
      final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(
            size.toInt(),
            size.toInt(),
          );

      final ByteData? byteData = await markerAsImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List imageBytes = byteData!.buffer.asUint8List();

      return BitmapDescriptor.fromBytes(imageBytes);
    } catch (e) {
      print('Error creating circular image marker: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  /// Gets color based on price range or count
  static Color getColorByValue(num value, {bool isPrice = true}) {
    if (isPrice) {
      if (value < 100) return Colors.green;
      if (value < 500) return Colors.blue;
      if (value < 1000) return Colors.orange;
      return Colors.red;
    } else {
      // For count
      if (value < 5) return Colors.green;
      if (value < 10) return Colors.blue;
      if (value < 20) return Colors.orange;
      return Colors.red;
    }
  }
}

