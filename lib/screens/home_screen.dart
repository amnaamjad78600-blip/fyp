import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/ai_services.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

import 'favorites_screen.dart';
import 'outfit_detail_screen.dart';
import 'ai_stylist_screen.dart';

class HomeScreen extends StatefulWidget {

  final String skinTone;
  final String bodyType;
  final String style;
  final String occasion;

  const HomeScreen({
    super.key,
    required this.skinTone,
    required this.bodyType,
    required this.style,
    required this.occasion,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {

  int selectedIndex = 0;

  bool showResults = false;

  late String detectedSkinTone;
  late String selectedBodyType;

  bool isLoading = false;

  File? userImage;

  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<User?>? _authSubscription;
  String? _lastUid;

  @override
  void initState() {
    super.initState();
    detectedSkinTone = widget.skinTone;
    selectedBodyType = widget.bodyType;

    // Listen for authentication changes to clear and reload user data dynamically
    _authSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      if (user?.uid != _lastUid) {
        _lastUid = user?.uid;
        if (user != null) {
          _loadSavedData();
        } else {
          if (mounted) {
            setState(() {
              detectedSkinTone = widget.skinTone;
              selectedBodyType = widget.bodyType;
              aiSuggestedOutfits = [];
              showResults = false;
            });
          }
        }
      }
    });
  }

  /// LOAD PREVIOUSLY SAVED ANALYSIS RESULTS + OUTFITS FROM FIREBASE
  Future<void> _loadSavedData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestoreService = FirestoreService();

      // Run Firestore requests concurrently to cut loading time in half!
      final results = await Future.wait([
        firestoreService.getLastAnalysisResults(user.uid),
        firestoreService.getSuggestedOutfits(user.uid),
      ]);

      final lastAnalysis = results[0] as Map<String, dynamic>?;
      final savedOutfits = results[1] as List<Map<String, String>>;

      if (mounted) {
        setState(() {
          if (lastAnalysis != null) {
            detectedSkinTone = lastAnalysis["skinTone"] ?? widget.skinTone;
            selectedBodyType = lastAnalysis["bodyType"] ?? widget.bodyType;
          } else {
            detectedSkinTone = widget.skinTone;
            selectedBodyType = widget.bodyType;
          }
          aiSuggestedOutfits = savedOutfits;
          showResults = false;
        });
      }
    } catch (e) {
      print("Error loading saved data: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  List<Map<String, String>> aiSuggestedOutfits = [];

  /// AI ANALYSIS
  Future<void> runAI() async {

    if (userImage == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final query = _searchController.text.trim();
      String jsonResult = await AIService.analyzeImage(userImage!, searchQuery: query);
      
      // Parse the JSON string safely
      // Because sometimes the LLM might wrap JSON in markdown ```json ... ```
      if (jsonResult.startsWith("```json")) {
        jsonResult = jsonResult.replaceAll("```json", "").replaceAll("```", "").trim();
      } else if (jsonResult.startsWith("```")) {
        jsonResult = jsonResult.replaceAll("```", "").trim();
      }

      var parsedData = jsonDecode(jsonResult);

      setState(() {
        detectedSkinTone = parsedData["skinTone"] ?? "Medium";
        selectedBodyType = parsedData["bodyType"] ?? "Curvy";
        String detectedSeason = parsedData["season"] ?? "Unknown";
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(query.isNotEmpty 
                ? "Smart Search Completed! Season detected: $detectedSeason"
                : "Analysis complete! Season detected: $detectedSeason"),
            backgroundColor: Colors.pink,
          ),
        );
        
        List dynamicOutfits = parsedData["suggestedOutfits"] ?? [];
        aiSuggestedOutfits = dynamicOutfits.map((o) => {
          "title": o["title"]?.toString() ?? "Outfit",
          "skin": detectedSkinTone,
          "body": selectedBodyType,
          "category": o["category"]?.toString() ?? "Fashion",
          "brand": o["brand"]?.toString() ?? "Unknown",
          "rating": o["rating"]?.toString() ?? "4.0",
          "image": o["image"]?.toString() ?? "https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=600",
          "description": o["description"]?.toString() ?? "A custom outfit curated just for your preferences and body type! 💖",
          "material": o["material"]?.toString() ?? "Premium Fabric Blend",
          "sizes": o["sizes"]?.toString() ?? "S, M, L, XL",
        }).toList();

        showResults = true;
      });

      // Save everything to Firestore Database permanently
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final firestoreService = FirestoreService();
        final imageBytes = await userImage!.readAsBytes();
        final base64Image = base64Encode(imageBytes);
        final String season = parsedData["season"] ?? "Unknown";

        // Upload image to Firebase Storage first (gets .jpg or .png URL)
        final storageService = StorageService();
        String? firebaseUrl = await storageService.uploadAnalysisImage(userImage!, user.uid);
        await storageService.backupAnalysisImageLocally(userImage!, user.uid);

        final String ext = userImage!.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
        final String format = ext == 'png' ? 'image/png' : 'image/jpeg';
        final String fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.$ext';

        // 1. Save uploaded image to "uploaded_images" collection (using Firebase Storage URL or base64 fallback)
        await firestoreService.addUploadedImage(
          user.uid,
          firebaseUrl ?? "data:$format;base64,$base64Image",
          detectedSkinTone,
          selectedBodyType,
          season,
          query,
          format: format,
          fileName: fileName,
        );

        // 2. Save all AI recommended outfit images to "ai_recommended_images" collection (uploads them to Storage dynamically)
        final List<Map<String, String>> uploadedOutfits = 
            await firestoreService.saveAllRecommendedImages(
          user.uid,
          aiSuggestedOutfits,
        );

        // Update local memory list with the uploaded URLs
        setState(() {
          aiSuggestedOutfits = uploadedOutfits;
        });

        // 3. Save last analysis results (skin tone, body type, season)
        await firestoreService.saveLastAnalysisResults(
          user.uid,
          detectedSkinTone,
          selectedBodyType,
          season,
          query,
        );



        // 5. Local backup is already handled in parallel during Step 2 saveAllRecommendedImages!
      }

    } catch (e) {
      print("AI Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("AI failed: $e")),
      );
    } finally {

      setState(() {
        isLoading = false;
      });
    }
  }

  /// IMAGE PICKER
  Future pickImage() async {

    final picked =
    await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
    );

    if(picked != null){

      setState(() {

        userImage =
            File(picked.path);
      });

      await runAI();
    }
  }

  Widget _buildOutfitImage(String? imageUrl, {double? height}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(color: Colors.grey.shade100, height: height, width: double.infinity);
    }
    if (imageUrl.startsWith("http")) {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade100,
          height: height,
          width: double.infinity,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else {
      try {
        final String base64Data = imageUrl.contains(",") 
            ? imageUrl.split(",")[1] 
            : imageUrl;
        return Image.memory(
          base64Decode(base64Data),
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade100,
            height: height,
            width: double.infinity,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      } catch (e) {
        return Container(
          color: Colors.grey.shade100,
          height: height,
          width: double.infinity,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      }
    }
  }

  /// FILTER
  List<Map<String,String>>
  get results {

    if(!showResults){
      return [];
    }
    return aiSuggestedOutfits;
  }

  @override
  Widget build(BuildContext context){
    final user = FirebaseAuth.instance.currentUser;

    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (selectedIndex != 0) {
          setState(() {
            selectedIndex = 0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xffFFF5F8),
      appBar: AppBar(
        backgroundColor: Colors.pink,
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checkroom,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Text(
              "AI Fashion App",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      body: selectedIndex == 0
          ? Column(
              children: [
                /// GOOGLE-STYLE SMART SEARCH BAR
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(Icons.search, color: Colors.grey),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) async {
                            if (userImage == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please upload a photo first to analyze your skin tone and body features! 📸"),
                                  backgroundColor: Colors.pink,
                                ),
                              );
                              await pickImage();
                            } else {
                              await runAI();
                            }
                          },
                          decoration: const InputDecoration(
                            hintText: "Search themes or seasonal outfits...",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ),
                      ),
                      if (showResults)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          tooltip: "Clear Results",
                          onPressed: () {
                            setState(() {
                              showResults = false;
                              _searchController.clear();
                              userImage = null;
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.pink),
                        onPressed: () async {
                          if (userImage == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please upload a photo first to analyze your skin tone and body features! 📸"),
                                backgroundColor: Colors.pink,
                              ),
                            );
                            await pickImage();
                          } else {
                            await runAI();
                          }
                        },
                      ),
                    ],
                  ),
                ),

                /// HARMONIZED PHOTO PREVIEW CHIP (Only shown when photo is uploaded)
                if (userImage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.pink.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.pink.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              userImage!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Smart Image Analysis Active",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Matching suggestions to your body features & skin tone",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.change_circle_rounded, color: Colors.pink),
                            tooltip: "Change Photo",
                            onPressed: pickImage,
                          ),
                        ],
                      ),
                    ),
                  ),

                /// DYNAMIC MAIN VIEW AREA
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.pink),
                              SizedBox(height: 15),
                              Text(
                                "Stylist AI is matching your request...",
                                style: TextStyle(color: Colors.pink, fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        )
                      : (showResults
                          ? GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.all(15),
                              itemCount: results.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 0.51,
                              ),
                              itemBuilder: (c, i) {
                                var item = results[i];
                                final String docId = item["title"]!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => OutfitDetailScreen(
                                          outfit: item,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        /// IMAGE
                                        Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(24),
                                                topRight: Radius.circular(24),
                                              ),
                                              child: _buildOutfitImage(item["image"], height: 135),
                                            ),
                                            Positioned(
                                              top: 5,
                                              right: 5,
                                              child: StreamBuilder<User?>(
                                                stream: FirebaseAuth.instance.authStateChanges(),
                                                builder: (context, authSnapshot) {
                                                  final activeUser = authSnapshot.data;
                                                  if (activeUser == null) return const SizedBox();

                                                  return StreamBuilder<DocumentSnapshot>(
                                                    stream: FirebaseFirestore.instance
                                                        .collection('users').doc(activeUser.uid).collection('favorites')
                                                        .doc(docId)
                                                        .snapshots(),
                                                    builder: (context, snapshot) {
                                                      if (snapshot.hasError) {
                                                        print("Firestore Home Favorites Error: ${snapshot.error}");
                                                      }
                                                      bool isFav = snapshot.hasData && snapshot.data != null && snapshot.data!.exists;
                                                      return Container(
                                                        decoration: const BoxDecoration(
                                                          color: Colors.black26,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: IconButton(
                                                          icon: Icon(
                                                            isFav ? Icons.favorite : Icons.favorite_border,
                                                            color: isFav ? Colors.pinkAccent : Colors.white,
                                                            size: 24,
                                                          ),
                                                          onPressed: () async {
                                                            final docRef = FirebaseFirestore.instance
                                                                .collection('users')
                                                         .doc(activeUser.uid)
                                                         .collection('favorites')
                                                                .doc(docId);
                                                            if (isFav) {
                                                              await docRef.delete();
                                                            } else {
                                                              final Map<String, dynamic> favData = Map<String, dynamic>.from(item);
                                                              favData["userId"] = activeUser.uid;
                                                              favData["createdAt"] = Timestamp.now();
                                                              
                                                              // Dynamically set format for favorites
                                                              final String imageUrl = item["image"] ?? "";
                                                              String format = "image/jpeg";
                                                              if (imageUrl.toLowerCase().contains(".png")) {
                                                                format = "image/png";
                                                              }
                                                              favData["format"] = format;
 
                                                              await docRef.set(favData);
                                                            }
                                                          },
                                                        ),
                                                      );
                                                    },
                                                  );
                                                }
                                              ),
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item["title"]!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                item["brand"]!,
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    color: Colors.amber,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    item["rating"]!,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              /// VIEW DETAILS BUTTON
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => OutfitDetailScreen(
                                                          outfit: item,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.pink,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    "View Details",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: [
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: MediaQuery.of(context).size.height * 0.5,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton(
                                            onPressed: pickImage,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFE0F7FA), // Light blue ice water
                                              padding: const EdgeInsets.all(30),
                                              shape: const CircleBorder(),
                                              elevation: 4,
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              color: Color(0xFF00838F), // Contrast dark watery blue
                                              size: 40,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 20),
                                            child: Text(
                                              "Upload photo for AI recommendation",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                ),
              ],
            )
          : selectedIndex == 1
          ? const FavoritesScreen()
          : const AIStylistScreen(),

      /// BOTTOM NAVIGATION
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: Colors.pink,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: "Favourites",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: "AI Stylist",
          ),
        ],
        onTap: (index){
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    ),
  );
}
}