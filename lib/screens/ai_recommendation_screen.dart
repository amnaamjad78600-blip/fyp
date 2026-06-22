import 'package:flutter/material.dart';

class AIRecommendationScreen extends StatelessWidget {
  const AIRecommendationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Recommendation"),
        backgroundColor: Colors.pink,
      ),

      body: const Center(
        child: Text(
          "AI Recommendation Screen",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}