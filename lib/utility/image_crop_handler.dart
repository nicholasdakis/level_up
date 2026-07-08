import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import '../utility/responsive.dart';
import '../globals.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'image_crop_stub_helper.dart'
    if (dart.library.html) 'image_crop_web_helper.dart'
    as web_helper;

// Helper class to crop images on Web, Android, iOS
class ImageCropHelper {
  // Resizes image bytes so the longest side is at most [maxDimension] pixels.
  // Prevents cropperjs from not working on large phone photos (3-4mb+)
  static Future<Uint8List> _resizeIfNeeded(
    Uint8List bytes, {
    int maxDimension = 500,
  }) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final w = image.width;
    final h = image.height;
    image.dispose();
    codec.dispose();

    if (w <= maxDimension && h <= maxDimension) return bytes;

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
    required Color appColor,
  }) async {
    if (kIsWeb) {
      if (webBytes == null) return null;

      final resized = await _resizeIfNeeded(webBytes);
      final url = web_helper.createBlobUrl(resized);

      CroppedFile? croppedFile;

      if (web_helper.isWebMobileBrowser) {
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
              viewwMode: WebViewMode.mode_1,
              dragMode: WebDragMode.crop,
              initialAspectRatio: 1,
              cropBoxResizable: false,
              checkCrossOrigin: false,
            ),
          ],
        );
      } else {
        croppedFile = await ImageCropper().cropImage(
          sourcePath: url,
          uiSettings: [
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
              viewwMode: WebViewMode.mode_1,
              dragMode: WebDragMode.crop,
              initialAspectRatio: 1,
              cropBoxResizable: false,
              checkCrossOrigin: false,
              customDialogBuilder: (cropper, initCropper, crop, rotate, scale) {
                return _CropperDialog(
                  cropper: cropper,
                  initCropper: initCropper,
                  crop: crop,
                  appColor: appColor,
                );
              },
            ),
          ],
        );
      }

      web_helper.revokeBlobUrl(url);

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
  final Color appColor;

  const _CropperDialog({
    required this.cropper,
    required this.initCropper,
    required this.crop,
    required this.appColor,
  });

  @override
  State<_CropperDialog> createState() => _CropperDialogState();
}

class _CropperDialogState extends State<_CropperDialog> {
  @override
  void initState() {
    super.initState();
    widget.initCropper();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: frostedGlassCard(
              context,
              color: widget.appColor,
              padding: EdgeInsets.all(Responsive.scale(context, 16)),
              backgroundColor: Colors.white.withAlpha(10),
              border: Border.all(color: Colors.white.withAlpha(22), width: 1),
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
                          child: Text('Cancel', style: dialogButtonStyle()),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final result = await widget.crop();
                            Navigator.of(context).pop(result);
                          },
                          child: Text(
                            'Crop',
                            style: dialogButtonStyle(confirm: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
