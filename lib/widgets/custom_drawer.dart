import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Column(
        children: [

          /// HEADER
          StreamBuilder<DocumentSnapshot?>(
            stream: user != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots()
                : null,

            builder: (context, snapshot) {

              String? profileImageUrl;
              String accountName = user?.email?.split('@')[0] ?? "Guest User";

              if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                final data =
                    snapshot.data!.data() as Map<String, dynamic>?;
                if (data != null) {
                  profileImageUrl = data['profileImage'];
                  if (data.containsKey('username')) {
                    accountName = data['username'];
                  }
                }
              }

              return UserAccountsDrawerHeader(

                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black,
                      Colors.pink,
                    ],
                  ),
                ),

                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: profileImageUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.pink,
                          )
                        : (profileImageUrl.startsWith("http")
                            ? Image.network(
                                profileImageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.memory(
                                base64Decode(profileImageUrl.contains(",")
                                    ? profileImageUrl.split(",")[1]
                                    : profileImageUrl),
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              )),
                  ),
                ),

                accountName: Text(
                  accountName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                accountEmail: const Text(""),

              );
            },
          ),

          /// PROFILE
          buildDrawerItem(
            context: context,
            icon: Icons.person,
            title: "Profile",
            page: const ProfileScreen(),
          ),

          /// AI RECOMMENDATION
          buildDrawerItem(
            context: context,
            icon: Icons.auto_awesome,
            title: "AI Recommendation",
            page: user == null
                ? const LoginScreen()
                : const HomeScreen(
                    skinTone: "Fair",
                    bodyType: "Slim",
                    style: "Casual",
                    occasion: "Daily",
                  ),
          ),


          const Divider(
            thickness: 1,
          ),

          /// LOGIN
          buildDrawerItem(
            context: context,
            icon: Icons.login,
            title: "Login",
            page: const LoginScreen(),
          ),

          /// LOGOUT
          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.red,
            ),

            title: const Text(
              "Logout",
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),

            onTap: () async {

              await FirebaseAuth.instance.signOut();

              if (context.mounted) {

                Navigator.pushAndRemoveUntil(

                  context,

                  MaterialPageRoute(
                    builder: (context) =>
                        const LoginScreen(),
                  ),

                  (route) => false,
                );
              }
            },
          ),

          const Spacer(),

          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text(
              "Fashion AI App v1.0",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget page,
  }) {

    return ListTile(

      leading: Icon(
        icon,
        color: Colors.pink,
      ),

      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),

      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
      ),

      onTap: () {
        Navigator.pop(context);

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null && (title == "Profile" || title == "AI Recommendation")) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Please sign in to access your $title"),
              backgroundColor: Colors.pink,
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => page,
            ),
          );
        }
      },
    );
  }
}