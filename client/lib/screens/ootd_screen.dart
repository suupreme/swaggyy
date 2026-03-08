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

  bool _isOutfitGenerating = false;
  bool _isImageProcessing = false;

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
    _isOutfitGenerating = true; // Start with loading state for initial OOTD
    _ollamaService = OllamaService(
      'https://8e4d-97-104-30-252.ngrok-free.app/ollama_proxy',
      userId: widget.userId,
    ); // Initialize with your Ollama API URL

    _imageProcessor = ImageProcessor(
      userId: widget.userId,
      serverUrl:
          'https://8e4d-97-104-30-252.ngrok-free.app/detect', // Backend server URL
      callbacks: ImageProcessingCallbacks(
        onLoading: (loading) => setState(() => _isImageProcessing = loading), // Use new state var
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
          // After counts are updated, attempt to get an outfit suggestion
          if (_topCount >= 2 && _bottomCount >= 2) {
            _getOutfitSuggestion();
          } else {
            // If not enough clothes, ensure _isOutfitGenerating is false
            setState(() { _isOutfitGenerating = false; });
          }
        },
      ),
    );

    // Initial fetch of clothing items and counts when the screen loads
    _imageProcessor.fetchInitialClothingItemsAndCounts();
  }

  Future<void> _getOutfitSuggestion({bool forceRefresh = false}) async {
    // Only set loading state; do NOT clear _outfitSuggestion here.
    // The previous outfit should remain displayed during refresh.
    setState(() {
      _isOutfitGenerating = true;
    });

    OutfitSuggestion? newSuggestion; // Temporary variable for the new suggestion
    try {
      newSuggestion = await _ollamaService.getOutfitSuggestion(
        _allTops,
        _allBottoms,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      _showError('Failed to get outfit suggestion: $e');
      // If error, the _outfitSuggestion remains whatever it was or null if first time.
    } finally {
      setState(() {
        _isOutfitGenerating = false;
        // Update _outfitSuggestion only AFTER the call,
        // and if it's null, then it genuinely means no suggestion was found.
        _outfitSuggestion = newSuggestion;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If counts aren't loaded yet, show initial loading
    if (!_countsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    // If there aren't enough tops or bottoms, prompt the user to scan more.
    if (_topCount < 2 || _bottomCount < 2) {
      return _buildEmptyState();
    } else {
      // If we have enough clothes, display the Mistral generated outfit
      // If outfit is still generating, show loading
      if (_isOutfitGenerating && _outfitSuggestion == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return _buildSuggestedOutfit();
    }
  }

  Widget _buildSuggestedOutfit() {
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
      body: Stack( // Use a Stack to layer the content and the loading indicator
        children: [
          Column( // Your main content for the outfit suggestion
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
          if (_isOutfitGenerating) // Only show overlay if generating
            Positioned.fill(
              child: Container(
                color: Colors.transparent, // Make the overlay transparent
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
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
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SvgPicture.asset(
                type == 'Top'
                    ? 'assets/images/shirt-svgrepo-com.svg'
                    : 'assets/images/pants-svgrepo-com.svg',
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                width: type == 'Top' ? 100 : 80,
                height: type == 'Top' ? 100 : 80,
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
                child: _isImageProcessing
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
              _isImageProcessing
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
