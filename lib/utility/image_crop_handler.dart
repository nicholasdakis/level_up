import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Helper class to crop images on Web, Android, iOS
class ImageCropHelper {
  /// Crop the image. Returns a [CroppedFile]
  static Future<CroppedFile?> cropPicture({
    Uint8List? webBytes,
    File? mobileFile,
    required BuildContext context,
  }) async {
    if (kIsWeb) {
      if (webBytes == null) return null;

      // Create a blob URL so cropperjs can load the image
      final blob = html.Blob([webBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: url,
        uiSettings: [
          WebUiSettings(
            context: context,
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

  /// Convert a [CroppedFile] to bytes safely
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
    // AlertDialog for web version (mobile uses native cropping)
    return AlertDialog(
      backgroundColor: Colors.black,
      content: Container(
        width: 500,
        height: 500,
        color: Colors.black,
        child: widget.cropper,
      ),
      // Dialog buttons
      actions: [
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
    );
  }
}
