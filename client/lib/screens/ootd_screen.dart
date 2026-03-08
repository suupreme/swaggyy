import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/ollama_service.dart'; // Import OllamaService
import '../services/image_processor.dart'; // Import ImageProcessor

class OotdScreen extends StatefulWidget {
  final String userId;
  const OotdScreen({super.key, required this.userId});

  @override
  State<OotdScreen> createState() => _OotdScreenState();
}

class _OotdScreenState extends State<OotdScreen> {
  bool _scanAttemptedWithNoDetections = false;

  bool _isLoading = false;

  int _topCount = 0;
  int _bottomCount = 0;
  bool _countsLoaded = false;

  List<ClothingItem> _allTops = [];
  List<ClothingItem> _allBottoms = [];

  late OllamaService _ollamaService;
  OutfitSuggestion? _outfitSuggestion; // To store the LLM's suggestion

  late ImageProcessor _imageProcessor;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void initState() {
    super.initState();
    _ollamaService = OllamaService(
      'https://8e4d-97-104-30-252.ngrok-free.app/ollama_proxy',
      userId: widget.userId,
    ); // Initialize with your Ollama API URL

    _imageProcessor = ImageProcessor(
      userId: widget.userId,
      serverUrl:
          'https://8e4d-97-104-30-252.ngrok-free.app/detect', // Backend server URL
      callbacks: ImageProcessingCallbacks(
        onLoading: (loading) => setState(() => _isLoading = loading),
        onImagePicked: (file) {
          /* Removed as _imageFile is removed from OotdScreenState */
        },
        onDetections: (dets) {
          /* Removed as _detections is removed from OotdScreenState */
        },
        onNoDetections: (noDets) =>
            setState(() => _scanAttemptedWithNoDetections = noDets),
        onError: (message) => _showError(message),
        onCountsAndItemsUpdated: (topCount, bottomCount, allTops, allBottoms) {
          setState(() {
            _topCount = topCount;
            _bottomCount = bottomCount;
            _allTops = allTops;
            _allBottoms = allBottoms;
            _countsLoaded = true;
          });
          // After counts are updated from a new scan, try to get an outfit suggestion
          if (_topCount >= 2 && _bottomCount >= 2) {
            _getOutfitSuggestion();
          }
        },
      ),
    );

    // Initial fetch of clothing items and counts when the screen loads
    _imageProcessor.fetchInitialClothingItemsAndCounts();
  }

  Future<void> _getOutfitSuggestion({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _outfitSuggestion = null; // Clear previous suggestion
    });

    try {
      final suggestion = await _ollamaService.getOutfitSuggestion(
        _allTops,
        _allBottoms,
        forceRefresh: forceRefresh, // Pass the forceRefresh parameter
      );
      setState(() {
        _outfitSuggestion = suggestion;
      });
    } catch (e) {
      _showError('Failed to get outfit suggestion: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_countsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    // If there aren't enough tops or bottoms, prompt the user to scan more.
    if (_topCount < 2 || _bottomCount < 2) {
      return _buildEmptyState();
    } else {
      // If we have enough clothes, display the Mistral generated outfit
      return _buildSuggestedOutfit();
    }
  }

  Widget _buildSuggestedOutfit() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_outfitSuggestion == null) {
      return const Center(child: Text('No outfit suggestion found.'));
    }

    // Helper to parse RGB string to Color
    Color _parseRgbString(String rgbString) {
      final regex = RegExp(r'RGB\((\d+),\s*(\d+),\s*(\d+)\)');
      final match = regex.firstMatch(rgbString);
      if (match != null && match.groupCount == 3) {
        final r = int.parse(match.group(1)!);
        final g = int.parse(match.group(2)!);
        final b = int.parse(match.group(3)!);
        return Color.fromARGB(255, r, g, b);
      }
      return Colors.grey; // Default color if parsing fails
    }

    final Color topColor = _parseRgbString(_outfitSuggestion!.top.color);
    final Color bottomColor = _parseRgbString(_outfitSuggestion!.bottom.color);

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Your Suggested Outfit:',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildOutfitItemCard(
                _outfitSuggestion!.top.label,
                topColor,
                'Top',
              ),
              const SizedBox(width: 16),
              _buildOutfitItemCard(
                _outfitSuggestion!.bottom.label,
                bottomColor,
                'Bottom',
              ),
            ],
          ),
          if (_outfitSuggestion!.reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Reason: ${_outfitSuggestion!.reason}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _getOutfitSuggestion(forceRefresh: true),
        child: const Icon(Icons.refresh),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildOutfitItemCard(String label, Color color, String type) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: color.withOpacity(0.8),
      child: SizedBox(
        width: 150,
        height: 200, // Adjusted height for better display
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                type,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PopupMenuButton<ImageSource>(
              onSelected: (ImageSource source) {
                _imageProcessor.pickAndProcessImage(source);
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<ImageSource>>[
                    const PopupMenuItem<ImageSource>(
                      value: ImageSource.camera,
                      child: Row(
                        children: [
                          Icon(Icons.camera_alt),
                          SizedBox(width: 8),
                          Text('Take Photo'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<ImageSource>(
                      value: ImageSource.gallery,
                      child: Row(
                        children: [
                          Icon(Icons.photo_library),
                          SizedBox(width: 8),
                          Text('Choose from Gallery'),
                        ],
                      ),
                    ),
                  ],
              child: Container(
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.15),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.primary)
                    : const Icon(
                        Icons.camera_alt, // Camera icon for scanning
                        size: 100,
                        color: AppColors.primary,
                      ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _isLoading
                  ? 'Scanning Wardrobe...'
                  : _scanAttemptedWithNoDetections
                  ? 'No items detected! Try again.'
                  : 'Scan Your Wardrobe!',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap the camera above to start scanning your closet. We\'ll detect clothing items and provide color insights.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
