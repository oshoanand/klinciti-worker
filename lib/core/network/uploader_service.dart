// import 'dart:io';

// import 'package:dio/dio.dart';
// import 'package:flutter_image_compress/flutter_image_compress.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:path_provider/path_provider.dart';

// import 'api_client.dart';
// import 'api_exceptions.dart'; // Ensure this exists in your project

// /// Provider for the UploaderService
// final uploaderServiceProvider = Provider<UploaderService>((ref) {
//   final apiClient = ref.watch(apiClientProvider);
//   return UploaderService(apiClient);
// });

// class UploaderService {
//   final ApiClient _apiClient;

//   UploaderService(this._apiClient);

//   /// Uploads a file directly to the cloud (MinIO/S3) using a Presigned URL.
//   /// Safely handles images (with compression) mimicking the web behavior.
//   Future<String> uploadFileDirectly({
//     required File file,
//     required String endpoint,
//     Map<String, dynamic>? payloadData,
//     bool compress = true,
//     String imageContext = 'profile', // 'profile', 'jobs', 'banner', 'chats'
//     bool isGetRequest = false, // ✅ Set to true when using with the Chat backend
//   }) async {
//     try {
//       File fileToUpload = file;
//       String originalName = file.path.split('/').last.toLowerCase();
//       String finalFileName = originalName;

//       // 1. Client-Side Compression (Images only, skip GIFs)
//       final isImage = _isImageExtension(originalName);
//       final isGif = originalName.endsWith('.gif');

//       if (compress && isImage && !isGif) {
//         final isProfile = imageContext == 'profile';
//         final isBanner = imageContext == 'banner';

//         // Match Web quality and sizing thresholds
//         final int targetWidth = isProfile ? 600 : 1920;
//         final int quality = isProfile ? 70 : (isBanner ? 90 : 80);

//         try {
//           // Force .jpg extension for standardized cloud delivery
//           final baseName = originalName.split('.').first;
//           finalFileName = '$baseName.jpg';

//           // Get a temporary directory to save the compressed file
//           final tempDir = await getTemporaryDirectory();
//           final targetPath =
//               '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$finalFileName';

//           final XFile? compressedFile =
//               await FlutterImageCompress.compressAndGetFile(
//                 file.absolute.path,
//                 targetPath,
//                 quality: quality,
//                 minWidth: targetWidth,
//                 minHeight: targetWidth,
//                 format: CompressFormat.jpeg,
//               );

//           if (compressedFile != null) {
//             fileToUpload = File(compressedFile.path);
//           }
//         } catch (error) {
//           // Fallback to original file if compression fails
//           print(
//             'Client-side compression failed, proceeding with original file: $error',
//           );
//           finalFileName = originalName;
//         }
//       }

//       // 2. Build the exact payload
//       final requestBody = {...?payloadData, 'fileName': finalFileName};

//       // 3. Request the Presigned URL from the Fastify Backend
//       // Support both GET and POST depending on the endpoint design
//       final Response presignedResponse;
//       if (isGetRequest) {
//         presignedResponse = await _apiClient.dio.get(
//           endpoint,
//           queryParameters: requestBody,
//         );
//       } else {
//         presignedResponse = await _apiClient.dio.post(
//           endpoint,
//           data: requestBody,
//         );
//       }

//       // ✅ Map backend response safely ('url' is from our Fastify chat backend)
//       final String uploadUrl =
//           presignedResponse.data['url'] ??
//           presignedResponse.data['uploadUrl'] ??
//           presignedResponse.data['presignedUrl'];

//       // final String publicUrl = presignedResponse.data['publicUrl'];
//       // final String mimeType =
//       //     presignedResponse.data['mimeType'] ?? _inferMimeType(finalFileName);

//       final String publicUrl = presignedResponse.data['publicUrl'];
//       final String mimeType =
//           presignedResponse.data['mimeType'] ??
//           presignedResponse.data['headers']?['Content-Type'] ??
//           _inferMimeType(finalFileName);

//       // 4. Upload directly to Cloud Storage via PUT request
//       // ✅ We use a fresh, unauthenticated Dio instance to bypass JWT interceptors (prevents MinIO Auth errors)
//       final uploadDio = Dio();
//       final fileLength = await fileToUpload.length();

//       final uploadResult = await uploadDio.put(
//         uploadUrl,
//         data: fileToUpload.openRead(),
//         options: Options(
//           headers: {
//             Headers.contentLengthHeader: fileLength,
//             Headers.contentTypeHeader: mimeType,
//           },
//           sendTimeout: null, // Remove timeouts for large uploads
//           receiveTimeout: null,
//         ),
//       );

//       if (uploadResult.statusCode != 200 && uploadResult.statusCode != 201) {
//         throw Exception(
//           'Failed to upload file to storage bucket: ${uploadResult.statusCode}',
//         );
//       }

//       // Clean up the temporary compressed file to free up cache space
//       if (fileToUpload.path != file.path && await fileToUpload.exists()) {
//         await fileToUpload.delete();
//       }

//       // 5. Return the public URL
//       return publicUrl;
//     } on DioException catch (e) {
//       throw ApiException.fromDioException(e);
//     } catch (e) {
//       throw ApiException('Ошибка при загрузке файла: $e');
//     }
//   }

//   /// Helper to determine if the file is an image based on extension
//   bool _isImageExtension(String name) {
//     final lower = name.toLowerCase();
//     return lower.endsWith('.png') ||
//         lower.endsWith('.jpg') ||
//         lower.endsWith('.jpeg') ||
//         lower.endsWith('.webp') ||
//         lower.endsWith('.gif');
//   }

//   /// Determines the MIME type based on file extension
//   String _inferMimeType(String name) {
//     final lowerName = name.toLowerCase();
//     if (lowerName.endsWith('.png')) return 'image/png';
//     if (lowerName.endsWith('.webp')) return 'image/webp';
//     if (lowerName.endsWith('.gif')) return 'image/gif';
//     if (lowerName.endsWith('.pdf')) return 'application/pdf';
//     return 'image/jpeg'; // Default for compressed images
//   }
// }

import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';
import 'api_exceptions.dart';

typedef JsonMap = Map<String, dynamic>;

/// Provider for the UploaderService
final uploaderServiceProvider = Provider<UploaderService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UploaderService(apiClient);
});

class UploaderService {
  final ApiClient _apiClient;

  // Fresh, unauthenticated Dio instance to bypass JWT interceptors (prevents MinIO S3 signature errors)
  final Dio _uploadDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 90),
      receiveTimeout: const Duration(seconds: 90),
    ),
  );

  UploaderService(this._apiClient);

  /// Uploads a file directly to the cloud (MinIO/S3) using a Presigned URL.
  /// Safely handles camera & gallery images (with compression).
  Future<String> uploadFileDirectly({
    required File file,
    required String endpoint,
    JsonMap? payloadData,
    bool compress = true,
    String imageContext =
        'profile', // 'profile', 'avatar', 'kyc', 'jobs', 'banner', 'chats'
    bool isGetRequest = false,
  }) async {
    File fileToUpload = file;

    try {
      String originalName = file.path
          .split(Platform.pathSeparator)
          .last
          .toLowerCase();
      if (!originalName.contains('.')) {
        originalName = '$originalName.jpg';
      }
      String finalFileName = originalName;

      // 1. Client-Side Compression (Images only, skip GIFs)
      final isImage = _isImageExtension(originalName);
      final isGif = originalName.endsWith('.gif');

      if (compress && isImage && !isGif) {
        final isProfile = imageContext == 'profile' || imageContext == 'avatar';
        final isBanner = imageContext == 'banner';
        final isKyc = imageContext == 'kyc';

        final int targetWidth = isProfile ? 600 : 1920;
        final int quality = isProfile
            ? 75
            : (isBanner ? 90 : (isKyc ? 82 : 80));

        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final safeCompressedName = 'img_${imageContext}_$timestamp.jpg';

          final tempDir = await getTemporaryDirectory();
          final targetPath = '${tempDir.path}/$safeCompressedName';

          final XFile? compressedFile =
              await FlutterImageCompress.compressAndGetFile(
                file.absolute.path,
                targetPath,
                quality: quality,
                minWidth: targetWidth,
                minHeight: targetWidth,
                format: CompressFormat.jpeg,
              );

          if (compressedFile != null) {
            fileToUpload = File(compressedFile.path);
            // Only switch filename to .jpg after confirming compression succeeded
            finalFileName = safeCompressedName;
          }
        } catch (error) {
          log(
            '⚠️ Client-side compression failed, proceeding with original file: $error',
          );
          finalFileName = originalName;
        }
      }

      // 2. Build the exact payload for Fastify
      final requestBody = <String, dynamic>{
        ...?payloadData,
        'fileName': finalFileName,
      };

      // 3. Request the Presigned URL from the Fastify Backend
      final Response presignedResponse;
      if (isGetRequest) {
        presignedResponse = await _apiClient.dio.get(
          endpoint,
          queryParameters: requestBody,
        );
      } else {
        presignedResponse = await _apiClient.dio.post(
          endpoint,
          data: requestBody,
        );
      }

      final responseMap = presignedResponse.data is Map
          ? JsonMap.from(presignedResponse.data as Map)
          : JsonMap();

      final String? uploadUrl =
          (responseMap['url'] ??
                  responseMap['uploadUrl'] ??
                  responseMap['presignedUrl'])
              ?.toString();

      final String? publicUrl =
          (responseMap['publicUrl'] ?? responseMap['fileUrl'])?.toString();

      if (uploadUrl == null ||
          uploadUrl.isEmpty ||
          publicUrl == null ||
          publicUrl.isEmpty) {
        throw Exception('Сервер не вернул ссылку для загрузки файла');
      }

      final headersMap = responseMap['headers'] is Map
          ? JsonMap.from(responseMap['headers'] as Map)
          : null;

      final String mimeType =
          (responseMap['mimeType'] ??
                  headersMap?['Content-Type'] ??
                  _inferMimeType(finalFileName))
              .toString();

      // 4. Upload binary bytes directly to MinIO via PUT request
      // Using Uint8List avoids chunked transfer encoding issues on S3/MinIO PUT
      final Uint8List fileBytes = await fileToUpload.readAsBytes();

      final uploadResult = await _uploadDio.put(
        uploadUrl,
        data: fileBytes,
        options: Options(
          headers: {
            Headers.contentLengthHeader: fileBytes.length,
            Headers.contentTypeHeader: mimeType,
          },
          responseType: ResponseType.plain,
        ),
      );

      final statusCode = uploadResult.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        throw Exception(
          'Ошибка загрузки в облачное хранилище (код: $statusCode)',
        );
      }

      // Clean up the temporary compressed file to free up cache space
      if (fileToUpload.path != file.path && await fileToUpload.exists()) {
        await fileToUpload.delete();
      }

      log('✅ Uploaded to MinIO: $publicUrl (${fileBytes.length} bytes)');
      return publicUrl;
    } on DioException catch (e) {
      log(
        '❌ UploaderService DioException: ${e.response?.statusCode} - ${e.response?.data}',
      );
      throw ApiException.fromDioException(e);
    } catch (e) {
      log('❌ UploaderService Error: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка при загрузке файла: $e');
    }
  }

  /// Helper to determine if the file is an image based on extension
  bool _isImageExtension(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.endsWith('.gif');
  }

  /// Determines the MIME type based on file extension
  String _inferMimeType(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    if (lowerName.endsWith('.gif')) return 'image/gif';
    if (lowerName.endsWith('.heic') || lowerName.endsWith('.heif')) {
      return 'image/heic';
    }
    if (lowerName.endsWith('.pdf')) return 'application/pdf';
    if (lowerName.endsWith('.mp4')) return 'video/mp4';
    if (lowerName.endsWith('.mp3')) return 'audio/mpeg';
    if (lowerName.endsWith('.wav')) return 'audio/wav';
    return 'image/jpeg';
  }
}
