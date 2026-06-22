import 'package:flutter/material.dart';
import '../widgets/custom_drawer.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      drawer: const CustomDrawer(),

      body: Stack(

        children: [

          /// SOLID LIGHT GREEN BACKGROUND
          Container(
            color: Colors.lightGreen.shade100,
          ),

          /// CONTENT
          SafeArea(
            child: Column(

              children: [

                /// MENU BUTTON
                Padding(
                  padding: const EdgeInsets.all(15),

                  child: Row(

                    children: [

                      Builder(
                        builder: (context) => IconButton(

                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },

                          icon: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                /// LOGO
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                    image: const DecorationImage(
                      image: AssetImage('assets/images/logo.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                /// TITLE
                const Text(
                  "AI Branded Stylish Western",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 10),

                /// SUBTITLE
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),

                  child: Text(

                    "Smart AI Fashion Recommendations For Men, Women & Kids",

                    textAlign: TextAlign.center,

                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}