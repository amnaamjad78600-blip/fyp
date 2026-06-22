import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'outfit_detail_screen.dart';
import '../services/firestore_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  Widget _buildOutfitImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(color: Colors.grey.shade100);
    }
    if (imageUrl.startsWith("http")) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade100,
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
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade100,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      } catch (e) {
        return Container(
          color: Colors.grey.shade100,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) {
          return Scaffold(
            backgroundColor: const Color(0xffFFF5F8),
            appBar: AppBar(
              title: const Text("My Favourites", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              centerTitle: true,
              backgroundColor: Colors.pink,
            ),
            body: const Center(
              child: Text(
                "Please login to see your collection ❤️",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xffFFF5F8),
          appBar: AppBar(
            title: const Text(
              "My Favourites",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.pink,
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestoreService.getFavorites(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.pink));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 60),
                        const SizedBox(height: 16),
                        Text(
                          "Firestore Access Error:\n${snapshot.error}",
                          style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Tip: Please check that your Firebase Console Firestore rules allow read and write access to the root 'favorites' collection! 🔒",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 85, color: Colors.pink.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      const Text("No favorites added yet ❤️", style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              return GridView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: docs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final outfitRaw = doc.data();
                  final outfit = outfitRaw.map((key, val) => MapEntry(key, val.toString()));

                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                child: _buildOutfitImage(outfit["image"]),
                              ),
                              Positioned(
                                top: 5,
                                right: 5,
                                child: CircleAvatar(
                                  backgroundColor: Colors.white.withOpacity(0.9),
                                  radius: 18,
                                  child: IconButton(
                                    icon: const Icon(Icons.favorite, color: Colors.red, size: 18),
                                    onPressed: () async {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user.uid)
                                          .collection('favorites')
                                          .doc(doc.id)
                                          .delete();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            outfit["title"] ?? "",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Center(
                            child: SizedBox(
                              height: 30,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OutfitDetailScreen(outfit: outfit),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pink,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                                child: const Text("View", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}