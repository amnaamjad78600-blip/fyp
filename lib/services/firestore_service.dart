import 'package:cloud_firestore/cloud_firestore.dart';
import 'storage_service.dart';

class FirestoreService {

  final FirebaseFirestore db = FirebaseFirestore.instance;

  /// SAVE USER DATA (Pristine fields only)
  Future<void> saveUser(String uid, String email) async {
    await db.collection("users").doc(uid).set({
      "email": email,
      "username": email.split('@')[0],
      "createdAt": Timestamp.now(),
    }, SetOptions(merge: true));
  }

  /// SAVE PREFERENCES (Root Collection)
  Future<void> savePreferences(
      String uid,
      Map<String, dynamic> data) async {
    await db
        .collection("preferences")
        .doc(uid)
        .set(data);
  }

  /// SAVE FAVORITES (Subcollection under User document)
  Future<void> addFavorite(
      String uid,
      Map<String, dynamic> outfit) async {
    final String title = outfit["title"] ?? "outfit";
    final String slug = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final String docId = slug;

    final Map<String, dynamic> favData = Map<String, dynamic>.from(outfit);
    favData["userId"] = uid;
    favData["createdAt"] = Timestamp.now();

    // Dynamically set format for favorites
    final String imageUrl = outfit["image"]?.toString() ?? "";
    String format = "image/jpeg";
    if (imageUrl.startsWith("data:image/png") || imageUrl.toLowerCase().contains(".png")) {
      format = "image/png";
    }
    favData["format"] = format;

    await db
        .collection("users")
        .doc(uid)
        .collection("favorites")
        .doc(docId)
        .set(favData);
  }

  /// GET FAVORITES (Subcollection under User document)
  Stream<QuerySnapshot<Map<String, dynamic>>> getFavorites(String uid) {
    return db
        .collection("users")
        .doc(uid)
        .collection("favorites")
        .snapshots();
  }

  /// SAVE AI ANALYSIS RESULTS (Root Collection)
  Future<void> saveLastAnalysisResults(
      String uid,
      String skinTone,
      String bodyType,
      String season,
      String searchQuery,
      ) async {
    await db
        .collection("last_analyses")
        .doc(uid)
        .set({
      "userId": uid,
      "skinTone": skinTone,
      "bodyType": bodyType,
      "season": season,
      "searchQuery": searchQuery,
      "updatedAt": Timestamp.now(),
    });
  }

  /// GET LAST ANALYSIS RESULTS (Root Collection)
  Future<Map<String, dynamic>?> getLastAnalysisResults(String uid) async {
    final doc = await db.collection("last_analyses").doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return doc.data();
    }
    return null;
  }

  /// SAVE USER PROFILE IMAGE directly inside the root users document
  Future<void> saveUserProfileImage(String uid, String url) async {
    await db
        .collection("users")
        .doc(uid)
        .set({
      "profileImage": url,
    }, SetOptions(merge: true));
  }

  /// GET SAVED SUGGESTED OUTFITS (Restores directly from root ai_recommended_images)
  Future<List<Map<String, String>>> getSuggestedOutfits(String uid) async {
    final snapshot = await db
        .collection("ai_recommended_images")
        .where("userId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .limit(10)
        .get();

    final outfits = snapshot.docs.map((doc) {
      final data = doc.data();
      return data.map((key, value) => MapEntry(key, value.toString()));
    }).toList();

    // Reverse to restore original chronological list order
    return outfits.reversed.toList();
  }

  /// SAVE A SINGLE CHAT MESSAGE (Root Collection)
  Future<void> saveChatMessage(
      String uid,
      String sender,
      String text,
      String time,
      ) async {
    await db
        .collection("chat_history")
        .add({
      "userId": uid,
      "sender": sender,
      "text": text,
      "time": time,
      "createdAt": Timestamp.now(),
    });
  }

  /// GET CHAT HISTORY (Root Collection)
  Future<List<Map<String, String>>> getChatMessages(String uid) async {
    final snapshot = await db
        .collection("chat_history")
        .where("userId", isEqualTo: uid)
        .orderBy("createdAt", descending: false)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        "sender": data["sender"]?.toString() ?? "stylist",
        "text": data["text"]?.toString() ?? "",
        "time": data["time"]?.toString() ?? "",
      };
    }).toList();
  }

  /// CLEAR CHAT HISTORY (Root Collection)
  Future<void> clearChatHistory(String uid) async {
    final docs = await db
        .collection("chat_history")
        .where("userId", isEqualTo: uid)
        .get();
    for (var doc in docs.docs) {
      await doc.reference.delete();
    }
  }

  // =====================================================
  //  UPLOADED IMAGES (Root Collection)
  // =====================================================

  /// SAVE UPLOADED IMAGE to Firestore (base64 image/URL + metadata)
  Future<void> addUploadedImage(
      String uid,
      String base64ImageOrUrl,
      String skinTone,
      String bodyType,
      String season,
      String searchQuery, {
      String? format,
      String? fileName,
      }) async {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String docId = "upload_${uid}_$timestamp";

    // Auto-detect format and filename from the image url or base64
    String detectedFormat = format ?? "image/jpeg";
    String detectedFileName = fileName ?? "photo_$timestamp.jpg";

    if (base64ImageOrUrl.startsWith("data:image/png") || base64ImageOrUrl.toLowerCase().contains(".png")) {
      detectedFormat = "image/png";
      detectedFileName = "photo_$timestamp.png";
    }

    await db
        .collection("uploaded_images")
        .doc(docId)
        .set({
      "userId": uid,
      "image": base64ImageOrUrl,
      "fileName": detectedFileName,
      "format": detectedFormat,
      "skinTone": skinTone,
      "bodyType": bodyType,
      "season": season,
      "searchQuery": searchQuery,
      "createdAt": Timestamp.now(),
    });
  }

  /// GET ALL UPLOADED IMAGES
  Stream<QuerySnapshot<Map<String, dynamic>>> getUploadedImages(String uid) {
    return db
        .collection("uploaded_images")
        .where("userId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  /// DELETE AN UPLOADED IMAGE
  Future<void> deleteUploadedImage(String uid, String docId) async {
    await db
        .collection("uploaded_images")
        .doc(docId)
        .delete();
  }

  // =====================================================
  //  AI RECOMMENDED IMAGES (Root Collection)
  // =====================================================

  /// SAVE A SINGLE AI RECOMMENDED OUTFIT IMAGE
  /// Returns the final image URL (either the Firebase Storage URL or original URL)
  Future<String> addRecommendedImage(
      String uid,
      Map<String, String> outfit,
      ) async {
    final String title = outfit["title"] ?? "outfit";
    final String slug = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final String docId = "rec_${uid}_$slug";

    final String imageUrl = outfit["image"] ?? "";
    String finalImageUrl = imageUrl;
    String format = "image/jpeg";

    if (imageUrl.startsWith("http")) {
      try {
        final storage = StorageService();
        final String? uploadedUrl = await storage.uploadAndBackupRecommendedOutfit(imageUrl, uid, title);
        if (uploadedUrl != null) {
          finalImageUrl = uploadedUrl;
        }
      } catch (e) {
        print("Could not upload recommended image to storage: $e");
      }
    }

    if (finalImageUrl.startsWith("data:image/png") || finalImageUrl.toLowerCase().contains(".png")) {
      format = "image/png";
    }

    await db
        .collection("ai_recommended_images")
        .doc(docId)
        .set({
      "userId": uid,
      "title": outfit["title"] ?? "",
      "brand": outfit["brand"] ?? "",
      "category": outfit["category"] ?? "",
      "rating": outfit["rating"] ?? "",
      "image": finalImageUrl,
      "description": outfit["description"] ?? "",
      "material": outfit["material"] ?? "",
      "sizes": outfit["sizes"] ?? "",
      "skinTone": outfit["skin"] ?? "",
      "bodyType": outfit["body"] ?? "",
      "format": format,
      "createdAt": Timestamp.now(),
    });

    return finalImageUrl;
  }

  /// SAVE ALL AI RECOMMENDED OUTFIT IMAGES (batch - HIGHLY OPTIMIZED PARALLEL EXECUTION)
  /// Returns the list of updated outfits with their uploaded image URLs
  Future<List<Map<String, String>>> saveAllRecommendedImages(
      String uid,
      List<Map<String, String>> outfits,
      ) async {
    final List<Future<Map<String, String>>> futures = outfits.map((outfit) async {
      final String finalImageUrl = await addRecommendedImage(uid, outfit);
      final Map<String, String> updated = Map<String, String>.from(outfit);
      updated["image"] = finalImageUrl;
      return updated;
    }).toList();

    return await Future.wait(futures);
  }

  /// GET ALL AI RECOMMENDED IMAGES
  Stream<QuerySnapshot<Map<String, dynamic>>> getRecommendedImages(String uid) {
    return db
        .collection("ai_recommended_images")
        .where("userId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  /// DELETE A RECOMMENDED IMAGE
  Future<void> deleteRecommendedImage(String uid, String docId) async {
    await db
        .collection("ai_recommended_images")
        .doc(docId)
        .delete();
  }
}