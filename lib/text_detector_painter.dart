import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'coordinates_translator.dart';

class TextRecognizerPainter extends CustomPainter {
  TextRecognizerPainter(
    this.recognizedText,
    this.imageSize,
    this.rotation,
    this.cameraLensDirection,
  );

  final RecognizedText recognizedText;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.lightGreenAccent;

    final Paint background = Paint()..color = Color(0x99000000);

    for (final textBlock in recognizedText.blocks) {
      int discountedPrice = calculateDiscountedPrice(textBlock.text, 0.2);
      if (discountedPrice == 0) {
        continue;
      }
      final ParagraphBuilder builder = ParagraphBuilder(
        ParagraphStyle(
            textAlign: TextAlign.left,
            fontSize: 20,
            textDirection: TextDirection.ltr),
      );
      // 기존 가격
      builder.pushStyle(
          ui.TextStyle(color: Colors.lightGreenAccent, background: background));
      builder.addText("${textBlock.text}\n");

      // 할인된 가격
      builder.pushStyle(
          ui.TextStyle(color: Colors.red, background: background));
      builder.addText('${formatWithCommas(discountedPrice)}원');
      builder.pop();

      final left = translateX(
        textBlock.boundingBox.left,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final top = translateY(
        textBlock.boundingBox.top,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final right = translateX(
        textBlock.boundingBox.right,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      // final bottom = translateY(
      //   textBlock.boundingBox.bottom,
      //   size,
      //   imageSize,
      //   rotation,
      //   cameraLensDirection,
      // );
      //
      // canvas.drawRect(
      //   Rect.fromLTRB(left, top, right, bottom),
      //   paint,
      // );

      final List<Offset> cornerPoints = <Offset>[];
      for (final point in textBlock.cornerPoints) {
        double x = translateX(
          point.x.toDouble(),
          size,
          imageSize,
          rotation,
          cameraLensDirection,
        );
        double y = translateY(
          point.y.toDouble(),
          size,
          imageSize,
          rotation,
          cameraLensDirection,
        );

        if (Platform.isAndroid) {
          switch (cameraLensDirection) {
            case CameraLensDirection.front:
              switch (rotation) {
                case InputImageRotation.rotation0deg:
                case InputImageRotation.rotation90deg:
                  break;
                case InputImageRotation.rotation180deg:
                  x = size.width - x;
                  y = size.height - y;
                  break;
                case InputImageRotation.rotation270deg:
                  x = translateX(
                    point.y.toDouble(),
                    size,
                    imageSize,
                    rotation,
                    cameraLensDirection,
                  );
                  y = size.height -
                      translateY(
                        point.x.toDouble(),
                        size,
                        imageSize,
                        rotation,
                        cameraLensDirection,
                      );
                  break;
              }
              break;
            case CameraLensDirection.back:
              switch (rotation) {
                case InputImageRotation.rotation0deg:
                case InputImageRotation.rotation270deg:
                  break;
                case InputImageRotation.rotation180deg:
                  x = size.width - x;
                  y = size.height - y;
                  break;
                case InputImageRotation.rotation90deg:
                  x = size.width -
                      translateX(
                        point.y.toDouble(),
                        size,
                        imageSize,
                        rotation,
                        cameraLensDirection,
                      );
                  y = translateY(
                    point.x.toDouble(),
                    size,
                    imageSize,
                    rotation,
                    cameraLensDirection,
                  );
                  break;
              }
              break;
            case CameraLensDirection.external:
              break;
          }
        }

        cornerPoints.add(Offset(x, y));
      }

      // Add the first point to close the polygon
      cornerPoints.add(cornerPoints.first);
      canvas.drawPoints(PointMode.polygon, cornerPoints, paint);

      canvas.drawParagraph(
        builder.build()
          ..layout(ParagraphConstraints(
            width: (right - left).abs() * 2,
          )),
        Offset(
            Platform.isAndroid &&
                    cameraLensDirection == CameraLensDirection.front
                ? right
                : left,
            top),
      );
    }
  }

  @override
  bool shouldRepaint(TextRecognizerPainter oldDelegate) {
    return oldDelegate.recognizedText != recognizedText;
  }

  int calculateDiscountedPrice(String priceStr, double discountRate) {
    if (!isNumericOnly(priceStr.replaceAll(',', ''))) {
      return 0;
    }
    // "52,300" → 52300
    int price = int.parse(priceStr.replaceAll(',', ''));

    // 20% 할인 → 80% 계산
    int discounted = (price * (1 - discountRate)).round();

    return discounted;
  }

  String formatWithCommas(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  bool isNumericOnly(String input) {
    // 문자열이 비어 있지 않고 오직 숫자로만 구성되어 있는 경우 true
    return RegExp(r'^\d+$').hasMatch(input);
  }
}
