import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clothing_recognizer/services/ollama_service.dart';

class ImageProcessingCallbacks {
  final Function(bool) onLoading;
  final Function(File?) onImagePicked;
  final Function(List<dynamic>) onDetections;
  final Function(bool) onNoDetections;
  final Function(String) onError;
  final Function(int topCount, int bottomCount, List<ClothingItem> allTops, List<ClothingItem> allBottoms) onCountsAndItemsUpdated;

  ImageProcessingCallbacks({
    required this.onLoading,
    required this.onImagePicked,
    required this.onDetections,
    required this.onNoDetections,
    required this.onError,
    required this.onCountsAndItemsUpdated,
  });
}

class ImageProcessor {
  final String userId;
  final String serverUrl;
  final ImageProcessingCallbacks callbacks;

  ImageProcessor({
    required this.userId,
    required this.serverUrl,
    required this.callbacks,
  });

  // Method to categorize labels (similar to WardrobeScreen)
  bool _isTop(String label) {
    label = label.toLowerCase();
    return label.contains('shirt') ||
        label.contains('t-shirt') ||
        label.contains('blouse') ||
        label.contains('sweater') ||
        label.contains('hoodie') ||
        label.contains('jacket') ||
        label == 'top';
  }

  bool _isBottom(String label) {
    label = label.toLowerCase();
    return label.contains('pants') ||
        label.contains('jeans') ||
        label.contains('shorts') ||
        label.contains('skirt') ||
        label == 'bottom';
  }

  Future<void> pickAndProcessImage(ImageSource source) async {
    callbacks.onLoading(true);
    callbacks.onNoDetections(false); // Reset no detections flag

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (image == null) {
      callbacks.onLoading(false);
      return;
    }

    callbacks.onImagePicked(File(image.path)); // Update image in UI

    try {
      if (kDebugMode) print('Attempting HTTP request to $serverUrl');
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.headers['ngrok-skip-browser-warning'] = 'true';
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> detections = data['detections'] ?? [];
        callbacks.onDetections(detections); // Update detections in UI

        if (detections.isEmpty) {
          callbacks.onNoDetections(true);
        }

        // Save detections to Firestore
        final userDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId);
        final scannedItemsCollection = userDocRef.collection('scanned_items');

        for (var detection in detections) {
          final List<dynamic> color = detection['color'] ?? [0, 0, 0];
          final List<dynamic>? complementaryColor = detection['complementary_color'] as List<dynamic>?;

          await scannedItemsCollection.add({
            'label': detection['label'].toString(),
            'mainColor': color,
            'complementaryColor': complementaryColor,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
        // After saving, re-fetch counts and items to update state in OotdScreen
        await _fetchClothingItemsAndCountsInternal();

      } else {
        callbacks.onError("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (kDebugMode) print('Error in ImageProcessor: $e');
      callbacks.onError("Connection failed. Error: $e");
    } finally {
      callbacks.onLoading(false);
    }
  }

  // Internal method to fetch counts and items after a scan
  Future<void> _fetchClothingItemsAndCountsInternal() async {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('scanned_items')
        .get();

    int top = 0;
    int bottom = 0;
    List<ClothingItem> fetchedTops = [];
    List<ClothingItem> fetchedBottoms = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String label = data['label']?.toString() ?? '';
      final List<dynamic> colorRgb = data['mainColor'] ?? [0, 0, 0];
      final ClothingItem item = ClothingItem(
        id: doc.id,
        label: label,
        colorRgb: colorRgb.map((e) => e as int).toList(),
      );

      if (_isTop(label)) {
        top++;
        fetchedTops.add(item);
      } else if (_isBottom(label)) {
        bottom++;
        fetchedBottoms.add(item);
      }
    }
    callbacks.onCountsAndItemsUpdated(top, bottom, fetchedTops, fetchedBottoms);
  }

  Future<void> fetchInitialClothingItemsAndCounts() async {
    callbacks.onLoading(true);
    await _fetchClothingItemsAndCountsInternal();
    callbacks.onLoading(false);
  }
}