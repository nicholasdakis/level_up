import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import '../utility/responsive.dart';
import '../globals.dart';
import 'dart:io';
import 'dart:ui' as ui;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

// Helper class to crop images on Web, Android, iOS
class ImageCropHelper {
  // Returns true if running on a mobile web browser (iOS/Android browser)
  // Treated separately to web as to not pass customDialogBuilder for this case
  static bool get _isMobileWeb {
    if (!kIsWeb) return false;
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('android');
  }

  // Resizes image bytes so the longest side is at most [maxDimension] pixels.
  // Prevents cropperjs from not working on large phone photos (3-4mb+)
  static Future<Uint8List> _resizeIfNeeded(
    Uint8List bytes, {
    int maxDimension = 500,
  }) async {
    // First decode at full size to get intrinsic dimensions
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final w = image.width;
    final h = image.height;
    image.dispose();
    codec.dispose();

    // Only resize if actually needed
    if (w <= maxDimension && h <= maxDimension) return bytes;

    // Scale down preserving aspect ratio
    final isWide = w > h;
    final resizedCodec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: isWide ? maxDimension : null,
      targetHeight: isWide ? null : maxDimension,
    );
    final resizedFrame = await resizedCodec.getNextFrame();
    final resizedImage = resizedFrame.image;
    final byteData = await resizedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    resizedImage.dispose();
    resizedCodec.dispose();

    return byteData!.buffer.asUint8List();
  }

  /// Crop the image. Returns a [CroppedFile]
  static Future<CroppedFile?> cropPicture({
    Uint8List? webBytes,
    File? mobileFile,
    required BuildContext context,
  }) async {
    if (kIsWeb) {
      if (webBytes == null) return null;

      // Resize before cropping to prevent cropperjs from not working with large images
      final resized = await _resizeIfNeeded(webBytes);

      // Create a blob URL so cropperjs can load the image
      final blob = html.Blob([resized]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      CroppedFile? croppedFile;

      if (_isMobileWeb) {
        // On mobile browsers, skip customDialogBuilder — it doesn't render correctly.
        // Use WebUiSettings directly with aspect ratio lock instead.
        croppedFile = await ImageCropper().cropImage(
          sourcePath: url,
          uiSettings: [
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.page,
              size: CropperSize(
                width: Responsive.width(context, 400).toInt(),
                height: Responsive.height(context, 600).toInt(),
              ),
              viewwMode:
                  WebViewMode.mode_1, // restricts crop box to image bounds
              dragMode: WebDragMode.crop, // drag moves crop box, not image
              initialAspectRatio: 1, // start as square
              cropBoxResizable: false, // lock aspect ratio
              checkCrossOrigin: false,
            ),
          ],
        );
      } else {
        // Desktop web — custom dialog works fine
        croppedFile = await ImageCropper().cropImage(
          sourcePath: url,
          uiSettings: [
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
              viewwMode: WebViewMode.mode_1,
              dragMode: WebDragMode.crop,
              initialAspectRatio: 1, // start as square
              cropBoxResizable: false, // lock aspect ratio
              checkCrossOrigin: false,
              customDialogBuilder: (cropper, initCropper, crop, rotate, scale) {
                // CroppedDialog is only setup for Web (mobile uses native cropping screen)
                return _CropperDialog(
                  cropper: cropper,
                  initCropper: initCropper,
                  crop: crop,
                );
              },
            ),
          ],
        );
      }

      // Clean up blob URL
      html.Url.revokeObjectUrl(url);

      return croppedFile;
    } else {
      if (mobileFile == null) return null;

      return await ImageCropper().cropImage(
        sourcePath: mobileFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.original,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.original,
            ],
          ),
        ],
      );
    }
  }

  // Convert a [CroppedFile] to bytes safely
  static Future<Uint8List?> getBytes(CroppedFile? cropped) async {
    if (cropped == null) return null;
    return await cropped.readAsBytes();
  }
}

class _CropperDialog extends StatefulWidget {
  final Widget cropper;
  final VoidCallback initCropper;
  final Future<String?> Function() crop;

  const _CropperDialog({
    required this.cropper,
    required this.initCropper,
    required this.crop,
  });

  @override
  State<_CropperDialog> createState() => _CropperDialogState();
}

class _CropperDialogState extends State<_CropperDialog> {
  @override
  void initState() {
    super.initState();
    widget.initCropper(); // Called here so cropperjs initializes correctly
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: frostedGlassCard(
        context,
        padding: EdgeInsets.all(Responsive.scale(context, 16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: Responsive.width(context, 500),
              height: Responsive.height(context, 500),
              color: Colors.black,
              child: widget.cropper,
            ),
            SizedBox(height: Responsive.height(context, 12)),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final result = await widget.crop();
                      Navigator.of(context).pop(result);
                    },
                    child: const Text('Crop'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
