import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OutfitDetailScreen extends StatelessWidget {

  final Map<String,String> outfit;

  const OutfitDetailScreen({super.key, required this.outfit});

  Widget _buildOutfitImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(color: Colors.grey.shade100, height: 300, width: double.infinity);
    }
    if (imageUrl.startsWith("http")) {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: 300,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade100,
          height: 300,
          width: double.infinity,
          child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
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
          height: 300,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade100,
            height: 300,
            width: double.infinity,
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
          ),
        );
      } catch (e) {
        return Container(
          color: Colors.grey.shade100,
          height: 300,
          width: double.infinity,
          child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String titleSlug = outfit["title"]?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ?? 'unknown';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(outfit["title"]!),
      ),
      floatingActionButton: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          final activeUser = authSnapshot.data;
          if (activeUser == null) return const SizedBox();

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(activeUser.uid)
                .collection('favorites')
                .doc(titleSlug)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print("Detail Screen Favorite Stream Error: ${snapshot.error}");
              }
              bool isFavorite = snapshot.hasData && snapshot.data != null && snapshot.data!.exists;
              return FloatingActionButton(
                backgroundColor: Colors.pink,
                onPressed: () async {
                  final docRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(activeUser.uid)
                      .collection('favorites')
                      .doc(titleSlug);
                  if (isFavorite) {
                    await docRef.delete();
                  } else {
                    final Map<String, dynamic> favData = Map<String, dynamic>.from(outfit);
                    favData["userId"] = activeUser.uid;
                    favData["createdAt"] = Timestamp.now();

                    // Dynamically set format for favorites
                    final String imageUrl = outfit["image"] ?? "";
                    String format = "image/jpeg";
                    if (imageUrl.toLowerCase().contains(".png")) {
                      format = "image/png";
                    }
                    favData["format"] = format;

                    await docRef.set(favData);
                  }
                },
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                ),
              );
            },
          );
        }
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _buildOutfitImage(outfit["image"]),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    outfit["title"]!,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Text("Brand: ${outfit["brand"]!}",
                      style: const TextStyle(fontSize: 16)),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.orange),
                      Text(" ${outfit["rating"]!} / 5"),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text("Material: ${outfit["material"]!}"),
                  Text("Available Sizes: ${outfit["sizes"]!}"),

                  const SizedBox(height: 15),

                  const Text("Description",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),

                  const SizedBox(height: 5),

                  Text(outfit["description"]!),

                  const SizedBox(height: 25),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}