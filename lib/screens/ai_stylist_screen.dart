import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_services.dart';
import '../services/firestore_service.dart';
import 'outfit_detail_screen.dart';

class AIStylistScreen extends StatefulWidget {
  const AIStylistScreen({super.key});

  @override
  State<AIStylistScreen> createState() => _AIStylistScreenState();
}

class _AIStylistScreenState extends State<AIStylistScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, String>> _messages = [];
  StreamSubscription<User?>? _authSubscription;
  String? _lastUid;

  @override
  void initState() {
    super.initState();
    _messages = [
      {
        "sender": "stylist",
        "text": "Hello, gorgeous! 💖 I am your personal AI Stylist. Ask me anything about matching outfits, seasonal colors, styling tips, or trending brands! 👗✨",
        "time": _getCurrentTime(),
      }
    ];

    // Listen for authentication changes to reload user stylist chat dynamically
    _authSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      if (user?.uid != _lastUid) {
        _lastUid = user?.uid;
        if (user != null) {
          _loadChatHistory();
        } else {
          if (mounted) {
            setState(() {
              _messages = [
                {
                  "sender": "stylist",
                  "text": "Hello, gorgeous! 💖 I am your personal AI Stylist. Ask me anything about matching outfits, seasonal colors, styling tips, or trending brands! 👗✨",
                  "time": _getCurrentTime(),
                }
              ];
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  /// LOAD PREVIOUS CHAT HISTORY FROM FIREBASE
  Future<void> _loadChatHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final savedMessages = await FirestoreService().getChatMessages(user.uid);
      if (mounted) {
        setState(() {
          if (savedMessages.isNotEmpty) {
            _messages = savedMessages;
          } else {
            _messages = [
              {
                "sender": "stylist",
                "text": "Hello, gorgeous! 💖 I am your personal AI Stylist. Ask me anything about matching outfits, seasonal colors, styling tips, or trending brands! 👗✨",
                "time": _getCurrentTime(),
              }
            ];
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      print("Error loading chat history: $e");
    }
  }

  String _getCurrentTime() {
    final dt = DateTime.now();
    int hour = dt.hour;
    final String ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final String minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute $ampm";
  }

  bool _isTyping = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final String currentTime = _getCurrentTime();
    setState(() {
      _messages.add({
        "sender": "user",
        "text": text,
        "time": currentTime,
      });
      _isTyping = true;
    });
    _scrollToBottom();

    // Save user message to Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirestoreService().saveChatMessage(user.uid, "user", text, currentTime);
    }

    try {
      // Build a clean history context for Groq
      final List<Map<String, String>> history = _messages
          .map((m) => {
                "sender": m["sender"]!,
                "text": m["text"]!,
              })
          .toList();

      final String response = await AIService.chatWithStylist(text, history);

      if (mounted) {
        final String responseTime = _getCurrentTime();
        setState(() {
          _messages.add({
            "sender": "stylist",
            "text": response,
            "time": responseTime,
          });
          _isTyping = false;
        });
        _scrollToBottom();

        // Save AI response to Firebase
        if (user != null) {
          FirestoreService().saveChatMessage(user.uid, "stylist", response, responseTime);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            "sender": "stylist",
            "text": "Oh dear! Something went slightly out of style. 👠 Let's try asking that again in a second!",
            "time": _getCurrentTime(),
          });
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xffFFF5F8), // Soft premium fashion pink
      ),
      child: Column(
        children: [
          // Elegant Header inside the screen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.pink.shade50,
                  child: const Icon(Icons.auto_awesome, color: Colors.pink),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "AI Fashion Stylist",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Online & Styling",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Message list area
          // Message list area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(15),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final bool isUser = message["sender"] == "user";
                String text = message["text"]!;
                String? outfitImageUrl;

                // Check if the text contains an [IMAGE: URL] tag
                if (text.contains("[IMAGE: ")) {
                  try {
                    final startIndex = text.indexOf("[IMAGE: ") + 8;
                    final endIndex = text.indexOf("]", startIndex);
                    if (endIndex != -1) {
                      outfitImageUrl = text.substring(startIndex, endIndex).trim();
                      // Remove the tag from the text
                      text = (text.substring(0, startIndex - 8) + text.substring(endIndex + 1)).trim();
                    }
                  } catch (e) {
                    print("Error parsing image URL: $e");
                  }
                }

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.pink : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (text.isNotEmpty)
                          Text(
                            text,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        


                        const SizedBox(height: 5),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            message["time"]!,
                            style: TextStyle(
                              color: isUser ? Colors.white70 : Colors.black38,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Typing Indicator
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.pink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "AI Stylist is picking an outfit...",
                      style: TextStyle(
                        color: Colors.pink.shade400,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Input Bar (WhatsApp-style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.pink.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xffFFF0F5),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: "Ask AI Stylist...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F7FA), // Light blue ice water
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Color(0xFF00838F), // Contrast dark watery blue
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
