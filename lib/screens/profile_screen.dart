import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  String username = "Loading...";
  String email = "Loading...";

  File? profileImage;
  String? profileImageUrl;
  bool isUploading = false;

  final nameController = TextEditingController();
  final emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        email = user.email ?? "No Email";
      });
      final doc = await FirestoreService().db.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          if (data.containsKey('username')) username = data['username'];
          else username = email.split('@')[0]; // fallback
          if (data.containsKey('contactEmail')) email = data['contactEmail'];
          if (data.containsKey('profileImage')) profileImageUrl = data['profileImage'];
        });
      } else if (mounted) {
        setState(() {
          username = email.split('@')[0];
        });
      }
    }
  }

  Future pickProfileImage() async {

    final picked =
    await ImagePicker().pickImage(
        source: ImageSource.gallery);

    if(picked != null){
      setState(() {
        profileImage = File(picked.path);
        isUploading = true;
      });

      String uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      StorageService storage = StorageService();
      String? url = await storage.saveProfileImageEverywhere(profileImage!, uid);

      if (mounted) {
        setState(() {
          isUploading = false;
          if (url != null) profileImageUrl = url;
        });

        if (url != null && uid != 'guest') {
          FirestoreService().saveUserProfileImage(uid, url);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile image uploaded!')),
          );
        }
      }
    }
  }

  void editProfile(){

    nameController.text = username;
    emailController.text = email;

    showDialog(
      context: context,
      builder:(context){
        return AlertDialog(
          title: const Text("Edit Profile"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              TextField(
                controller: nameController,
                decoration:
                const InputDecoration(
                    labelText: "Username"),
              ),

              TextField(
                controller: emailController,
                decoration:
                const InputDecoration(
                    labelText: "Email"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:(){
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed:() async {
                setState(() {
                  username = nameController.text;
                  email = emailController.text;
                });
                
                // Save username permanently to Firestore
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirestoreService().db.collection('users').doc(user.uid).set(
                    {
                      'username': username,
                      'contactEmail': email,
                    },
                    SetOptions(merge: true),
                  );
                }
                
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context){

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [

            GestureDetector(
              onTap: pickProfileImage,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade200,
                    child: ClipOval(
                      child: profileImage != null
                          ? Image.file(
                              profileImage!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : (profileImageUrl != null
                              ? (profileImageUrl!.startsWith("http")
                                  ? Image.network(
                                      profileImageUrl!,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.memory(
                                      base64Decode(profileImageUrl!.contains(",")
                                          ? profileImageUrl!.split(",")[1]
                                          : profileImageUrl!),
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ))
                              : const Icon(Icons.person, size: 60, color: Colors.pink)),
                    ),
                  ),
                  if (isUploading)
                    const CircularProgressIndicator(color: Colors.pink),
                ],
              ),
            ),

            const SizedBox(height:20),

            Text(
              username,
              style: const TextStyle(
                  fontSize:22,
                  fontWeight:
                  FontWeight.bold),
            ),
            
            Text(
              email,
              style: const TextStyle(
                  color: Colors.grey),
            ),

            const SizedBox(height:20),

            ElevatedButton(
              onPressed: editProfile,
              child:
              const Text("Edit Profile"),
            ),
          ],
        ),
      ),
    );
  }
}