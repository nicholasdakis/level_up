import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../globals.dart';

class ProfileImageService {
  // 100 KB target, always compress regardless of input size
  static const int maxBytes = 100 * 1024;
  // Max dimension for the longest side in pixels
  static const int maxDimension = 256;

  // Compresses a web image (Uint8List) to fit within maxBytes at maxDimension
  static Future<Uint8List> compressWeb(Uint8List image) async {
    return await FlutterImageCompress.compressWithList(
      image,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: 75,
      format: CompressFormat.jpeg,
    );
  }

  // Compresses a mobile image (File) to fit within maxBytes at maxDimension
  static Future<Uint8List> compressMobile(File file) async {
    Uint8List? compressed = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: 75,
      format: CompressFormat.jpeg,
    );
    return compressed!;
  }

  // Checks if the image is within the size limit after compression, showing a snackbar if not
  static Future<bool> checkSize(
    File? file,
    BuildContext? context, {
    bool isWeb = false,
    Uint8List? webBytes, // The optional parameters are only used for web
  }) async {
    // Handle Web
    if (isWeb) {
      // Check the size of the web image bytes
      if (webBytes != null && webBytes.lengthInBytes > maxBytes) {
        webBytes = await compressWeb(webBytes);
        // If still too big:
        if (context != null && webBytes.lengthInBytes > maxBytes) {
          double sizeInMbWeb = webBytes.lengthInBytes / (1024 * 1024);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Profile picture must be 0.75 MB or less. This image is ${sizeInMbWeb.toStringAsFixed(2)} MB after compression.",
              ),
              duration: snackBarDuration,
            ),
          );
          return false; // file too large
        }
      }
      return true;
    }

    // Handle Mobile (File check)
    if (file == null) return false; // safety check

    Uint8List fileBytes = await compressMobile(file);
    int fileSize = fileBytes.lengthInBytes;

    if (fileSize > maxBytes) {
      if (context != null) {
        double sizeInMbMobile = fileSize / (1024 * 1024);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Profile picture must be 0.75 MB or less. This image is ${sizeInMbMobile.toStringAsFixed(2)} MB after compression.",
            ),
            duration: snackBarDuration,
          ),
        );
      }
      return false; // early exit if file too large
    }

    return true;
  }
}
