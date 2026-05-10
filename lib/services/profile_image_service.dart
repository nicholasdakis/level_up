import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ProfileImageService {
  // 750 KB size limit in bytes (to meet the 1 MB Postgres limit when converted to base64)
  static const int maxBytes = 750 * 1024;

  // Compresses a web image (Uint8List) if it exceeds the size limit
  static Future<Uint8List> compressWeb(Uint8List image) async {
    // No compression needed
    if (image.lengthInBytes <= maxBytes) return image;
    // Compress
    return await FlutterImageCompress.compressWithList(image, quality: 70);
  }

  // Compresses a mobile image (File) if it exceeds the size limit
  static Future<Uint8List> compressMobile(File file) async {
    // Read bytes from the file
    Uint8List bytes = await file.readAsBytes();
    // No compression needed
    if (bytes.lengthInBytes <= maxBytes) return bytes;
    // Compress using FlutterImageCompress
    Uint8List? compressed = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: 70,
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
              duration: Duration(milliseconds: 1500),
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
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
      return false; // early exit if file too large
    }

    return true;
  }
}
