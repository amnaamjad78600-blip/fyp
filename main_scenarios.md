# AI Fashion App - Main Scenarios Overview

This document outlines the core scenarios (use cases) driving the AI Fashion App, along with the foundational code that implements them.

## Scenario 1: AI Outfit Recommendation (Image + Text Search)
**Where it happens:** `lib/screens/home_screen.dart` & `lib/services/ai_services.dart`

**Flow:**
1. The user uploads an image of themselves and optionally enters a search query (e.g., "traditional dress").
2. The `HomeScreen` converts the image to Base64 and sends it to `AIService.analyzeImage`.
3. The AI (Llama via Groq) analyzes the image for skin tone, body type, and generates exactly 8 culturally-aware, seasonally-appropriate outfits in JSON format.
4. The JSON is decoded and displayed in a grid of cards on the `HomeScreen`.

**Key Code Snippet (`HomeScreen` calling `AIService`):**
```dart
Future<void> runAI() async {
  if (userImage == null) return;
  setState(() => isLoading = true);

  try {
    final query = _searchController.text.trim();
    // 1. Call AI Service with Image and Optional Query
    String jsonResult = await AIService.analyzeImage(userImage!, searchQuery: query);
    
    // 2. Parse the JSON Response
    var parsedData = jsonDecode(jsonResult.replaceAll("```json", "").replaceAll("```", "").trim());

    setState(() {
      detectedSkinTone = parsedData["skinTone"] ?? "Medium";
      selectedBodyType = parsedData["bodyType"] ?? "Curvy";
      
      // 3. Map dynamic outfits to local list
      List dynamicOutfits = parsedData["suggestedOutfits"] ?? [];
      aiSuggestedOutfits = dynamicOutfits.map((o) => {
        "title": o["title"]?.toString() ?? "Outfit",
        "brand": o["brand"]?.toString() ?? "Unknown",
        "image": o["image"]?.toString() ?? "https://placeholder.url",
        // ... mapping other fields
      }).toList();
      showResults = true;
    });

    // 4. Permanently save to Firebase
    await _saveResultsToFirebase(parsedData, query);
  } catch (e) {
    print("AI Error: $e");
  } finally {
    setState(() => isLoading = false);
  }
}
```

## Scenario 2: Conversational AI Fashion Stylist
**Where it happens:** `lib/screens/ai_stylist_screen.dart` & `lib/services/ai_services.dart`

**Flow:**
1. The user opens the "AI Stylist" tab and sends a message asking for fashion advice.
2. The chat history and the new message are formatted and sent to the `AIService.chatWithStylist` function.
3. The AI returns a friendly, personalized fashion tip based on Pakistani/South Asian fashion trends.
4. The response is appended to the chat UI, and both messages are saved to Firebase.

**Key Code Snippet (`AIStylistScreen` chat flow):**
```dart
Future<void> _sendMessage() async {
  final String text = _messageController.text.trim();
  if (text.isEmpty) return;

  _messageController.clear();
  final String currentTime = _getCurrentTime();
  
  // 1. Update UI with User Message
  setState(() {
    _messages.add({"sender": "user", "text": text, "time": currentTime});
    _isTyping = true;
  });

  try {
    // 2. Send context history + new message to AI
    final List<Map<String, String>> history = _messages.map((m) => {
      "sender": m["sender"]!, "text": m["text"]!
    }).toList();

    final String response = await AIService.chatWithStylist(text, history);

    // 3. Update UI with AI Stylist Response
    if (mounted) {
      setState(() {
        _messages.add({"sender": "stylist", "text": response, "time": _getCurrentTime()});
        _isTyping = false;
      });
    }
  } catch (e) {
    // Handle error...
  }
}
```

## Scenario 3: Real-Time Dynamic Stock Image Fetching & Fallbacks
**Where it happens:** `lib/services/ai_services.dart`

**Flow:**
1. Once the LLM generates the outfit data, the system needs high-quality, relevant images.
2. It dynamically scrapes Unsplash for realistic stock images matching the outfit descriptions (e.g., "traditional pakistani mens sherwani").
3. If the scrape fails, it relies on a hardcoded "self-healing" curated fallback list for flawless UX.

**Key Code Snippet (`AIService` image scraper):**
```dart
static Future<List<String>> fetchLiveStockImages(String query, String gender) async {
  try {
    String searchTerm = query.toLowerCase();
    // Enforce cultural context
    if (searchTerm.isEmpty || searchTerm.contains("traditional")) {
      searchTerm = gender.toLowerCase() == 'male' 
          ? "traditional pakistani mens sherwani kurta" 
          : "traditional pakistani womens shalwar kameez lawn";
    }

    final encodedQuery = Uri.encodeComponent(searchTerm);
    final url = Uri.parse("https://unsplash.com/s/photos/$encodedQuery");

    final response = await http.get(url, headers: {"User-Agent": "Mozilla/5.0..."});
    
    // Extract images using Regex
    final regExp = RegExp(r'https://images\.unsplash\.com/(photo-[a-zA-Z0-9\-_]+)');
    final matches = regExp.allMatches(response.body);
    
    return matches.map((m) => "${m.group(0)}?w=600&fit=crop&q=80").toList();
  } catch (e) {
    return []; // Triggers fallback logic
  }
}
```

## Scenario 4: Firebase Data Persistence & Syncing
**Where it happens:** Scattered across screens utilizing `FirestoreService` and `StorageService`

**Flow:**
1. When a user uploads a photo, it is backed up locally and sent to Firebase Storage.
2. The AI analysis results (detected skin tone, body type) are saved directly to a Firestore document tied to `user.uid`.
3. Outfits are saved so they automatically load the next time the app opens, preventing redundant API calls.

**Key Code Snippet (`HomeScreen` Firebase save):**
```dart
final firestoreService = FirestoreService();
final storageService = StorageService();

// 1. Upload base image to Firebase Storage
String? firebaseUrl = await storageService.uploadAnalysisImage(userImage!, user.uid);

// 2. Save metadata to Firestore Collections
await firestoreService.addUploadedImage(
  user.uid, firebaseUrl, detectedSkinTone, selectedBodyType, season, query
);

// 3. Save AI recommendations so they persist on reload
await firestoreService.saveAllRecommendedImages(user.uid, aiSuggestedOutfits);
await firestoreService.saveLastAnalysisResults(user.uid, detectedSkinTone, selectedBodyType, season, query);
```
