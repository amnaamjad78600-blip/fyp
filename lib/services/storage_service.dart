import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // =====================================================
  //  PRIMARY: FIREBASE STORAGE (actual .jpg/.png files)
  // =====================================================

  /// Upload user's analysis photo to Firebase Storage
  /// Returns the download URL of the uploaded file
  Future<String?> uploadAnalysisImage(File image, String uid) async {
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String ext = image.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final String contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final String path = 'users/$uid/analysis_images/$timestamp.$ext';

      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(
        image,
        SettableMetadata(contentType: contentType),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      print("✅ Analysis image uploaded to Firebase Storage: $path");
      return downloadUrl;
    } catch (e) {
      print("⚠️ Firebase Storage upload failed: $e");
      // Fallback to base64 if Firebase Storage fails
      return _convertToBase64(image);
    }
  }

  /// Upload profile image to Firebase Storage
  Future<String?> uploadProfileImage(File image, String uid) async {
    try {
      final String ext = image.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final String contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final String path = 'users/$uid/profile/profile_photo.$ext';

      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(
        image,
        SettableMetadata(contentType: contentType),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      print("✅ Profile image uploaded to Firebase Storage: $path");
      return downloadUrl;
    } catch (e) {
      print("⚠️ Firebase Storage upload failed, using base64 fallback: $e");
      return _convertToBase64(image);
    }
  }

  /// Download AI recommended outfit image from URL and upload to Firebase Storage
  Future<String?> uploadRecommendedOutfitImage(
      String imageUrl, String uid, String outfitTitle) async {
    try {
      // Download the image from Unsplash URL
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return imageUrl;

      final Uint8List imageBytes = response.bodyBytes;

      // Determine extension from contentType or URL
      String contentType = response.headers['content-type'] ?? 'image/jpeg';
      String ext = 'jpg';
      if (contentType.contains('image/png') || imageUrl.toLowerCase().contains('.png')) {
        ext = 'png';
        contentType = 'image/png';
      } else {
        contentType = 'image/jpeg';
      }

      // Clean the title for use as filename
      final String cleanTitle = outfitTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String path = 'users/$uid/recommended_outfits/${cleanTitle}_$timestamp.$ext';

      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putData(
        imageBytes,
        SettableMetadata(contentType: contentType),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      print("✅ Recommended outfit image uploaded: $path");
      return downloadUrl;
    } catch (e) {
      print("⚠️ Failed to upload recommended image: $e");
      return imageUrl; // Return original URL as fallback
    }
  }

  /// Download AI recommended outfit image ONCE, upload to Firebase Storage, and save locally in parallel
  Future<String?> uploadAndBackupRecommendedOutfit(
      String imageUrl, String uid, String outfitTitle) async {
    try {
      // 1. Download the image from Unsplash URL ONCE
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return imageUrl;

      final Uint8List imageBytes = response.bodyBytes;

      // Determine extension from contentType or URL
      String contentType = response.headers['content-type'] ?? 'image/jpeg';
      String ext = 'jpg';
      if (contentType.contains('image/png') || imageUrl.toLowerCase().contains('.png')) {
        ext = 'png';
        contentType = 'image/png';
      } else {
        contentType = 'image/jpeg';
      }

      // Clean the title for use as filename
      final String cleanTitle = outfitTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // 2. Perform Local Backup Future
      final Future<String?> localBackupFuture = () async {
        try {
          final dir = await _getBackupDir(uid, 'recommended_outfits');
          final String localPath = '${dir.path}/${cleanTitle}_$timestamp.$ext';
          final file = File(localPath);
          await file.writeAsBytes(imageBytes);
          print("💾 [Optimized] Recommended outfit backed up locally: $localPath");
          return localPath;
        } catch (e) {
          print("⚠️ [Optimized] Local backup of recommended outfit failed: $e");
          return null;
        }
      }();

      // 3. Perform Firebase Storage Upload Future
      final String path = 'users/$uid/recommended_outfits/${cleanTitle}_$timestamp.$ext';
      final ref = _storage.ref().child(path);
      
      final uploadTaskFuture = ref.putData(
        imageBytes,
        SettableMetadata(contentType: contentType),
      );

      // Wait for both upload and local backup to complete concurrently
      final results = await Future.wait([
        uploadTaskFuture.then((task) => task.ref.getDownloadURL()),
        localBackupFuture,
      ]);

      final String downloadUrl = results[0] as String;
      print("✅ [Optimized] Recommended outfit image uploaded and backed up: $path");
      return downloadUrl;
    } catch (e) {
      print("⚠️ [Optimized] Failed to upload and backup recommended image: $e");
      return imageUrl; // Return original URL as fallback
    }
  }

  // =====================================================
  //  BACKUP: LOCAL DEVICE STORAGE (.jpg/.png files)
  // =====================================================

  /// Get the local backup directory path
  Future<Directory> _getBackupDir(String uid, String subfolder) async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/ai_fashion_backup/$uid/$subfolder');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Save analysis image locally as .jpg/.png backup
  Future<String?> backupAnalysisImageLocally(File image, String uid) async {
    try {
      final dir = await _getBackupDir(uid, 'analysis_images');
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String ext = image.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final String localPath = '${dir.path}/analysis_$timestamp.$ext';

      await image.copy(localPath);
      print("💾 Analysis image backed up locally: $localPath");
      return localPath;
    } catch (e) {
      print("⚠️ Local backup failed: $e");
      return null;
    }
  }

  /// Save profile image locally as .jpg/.png backup
  Future<String?> backupProfileImageLocally(File image, String uid) async {
    try {
      final dir = await _getBackupDir(uid, 'profile');
      final String ext = image.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final String localPath = '${dir.path}/profile_photo.$ext';

      await image.copy(localPath);
      print("💾 Profile image backed up locally: $localPath");
      return localPath;
    } catch (e) {
      print("⚠️ Local backup failed: $e");
      return null;
    }
  }

  /// Download AI recommended outfit image and save locally as .jpg/.png backup
  Future<String?> backupRecommendedOutfitLocally(
      String imageUrl, String uid, String outfitTitle) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return null;

      final dir = await _getBackupDir(uid, 'recommended_outfits');
      final String cleanTitle = outfitTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // Determine extension from contentType or URL
      String contentType = response.headers['content-type'] ?? 'image/jpeg';
      String ext = 'jpg';
      if (contentType.contains('image/png') || imageUrl.toLowerCase().contains('.png')) {
        ext = 'png';
      }

      final String localPath = '${dir.path}/${cleanTitle}_$timestamp.$ext';

      final file = File(localPath);
      await file.writeAsBytes(response.bodyBytes);
      print("💾 Recommended outfit backed up locally: $localPath");
      return localPath;
    } catch (e) {
      print("⚠️ Local backup of recommended outfit failed: $e");
      return null;
    }
  }

  /// Get all locally backed up images for a user
  Future<List<File>> getLocalBackupImages(String uid, String subfolder) async {
    try {
      final dir = await _getBackupDir(uid, subfolder);
      final files = dir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png') || f.path.endsWith('.jpeg'))
          .toList();
      files.sort((a, b) => b.path.compareTo(a.path)); // newest first
      return files;
    } catch (e) {
      print("Error reading local backup: $e");
      return [];
    }
  }

  // =====================================================
  //  COMBINED: UPLOAD + BACKUP (use this in screens)
  // =====================================================

  /// Upload analysis image to Firebase Storage AND save local backup
  Future<String?> saveAnalysisImageEverywhere(File image, String uid) async {
    // 1. Upload to Firebase Storage (primary - .jpg/.png file)
    final String? firebaseUrl = await uploadAnalysisImage(image, uid);

    // 2. Save local backup (.jpg/.png file)
    await backupAnalysisImageLocally(image, uid);

    return firebaseUrl;
  }

  /// Upload profile image to Firebase Storage AND save local backup
  Future<String?> saveProfileImageEverywhere(File image, String uid) async {
    // 1. Upload to Firebase Storage (primary - .jpg/.png file)
    final String? firebaseUrl = await uploadProfileImage(image, uid);

    // 2. Save local backup (.jpg/.png file)
    await backupProfileImageLocally(image, uid);

    return firebaseUrl;
  }

  /// Save AI recommended outfit image to Firebase Storage AND local backup
  Future<String?> saveRecommendedOutfitEverywhere(
      String imageUrl, String uid, String outfitTitle) async {
    // 1. Upload to Firebase Storage (primary - .jpg/.png file)
    final String? firebaseUrl = await uploadRecommendedOutfitImage(imageUrl, uid, outfitTitle);

    // 2. Save local backup (.jpg/.png file)
    await backupRecommendedOutfitLocally(imageUrl, uid, outfitTitle);

    return firebaseUrl;
  }

  // =====================================================
  //  FALLBACK: Base64 conversion (if Storage fails)
  // =====================================================

  /// Convert image to base64 string (fallback when Firebase Storage fails)
  Future<String?> _convertToBase64(File image) async {
    try {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      final String ext = image.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      return "data:image/$ext;base64,$base64String";
    } catch (e) {
      print("Error converting image to base64: $e");
      return null;
    }
  }
}
