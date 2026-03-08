import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../services/image_processor.dart';
import '../services/ollama_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/tinted_silhouette.dart';

class WardrobeScreen extends StatefulWidget {
  final String userId;
  const WardrobeScreen({super.key, required this.userId});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  late ImageProcessor _imageProcessor;
  bool _isLoadingImage =
      false; // New state to manage loading during image pick/process

  // State for fetching and displaying outfit suggestions
  late OllamaService _ollamaService;
  List<ClothingItem> _allTops = [];
  List<ClothingItem> _allBottoms = [];
  List<OutfitSuggestion> _outfitSuggestions = [];
  bool _isLoadingOutfits = true; // Initially loading outfits

  @override
  void initState() {
    super.initState();

    _ollamaService = OllamaService(
      'https://8e4d-97-104-30-252.ngrok-free.app/ollama_proxy',
      userId: widget.userId,
    );

    _imageProcessor = ImageProcessor(
      userId: widget.userId,
      serverUrl:
          'https://8e4d-97-104-30-252.ngrok-free.app/detect', // Backend server URL
      callbacks: ImageProcessingCallbacks(
        onLoading: (loading) => setState(() => _isLoadingImage = loading),
        onImagePicked: (file) {
          // Wardrobe screen doesn't need to display the image directly
          // but can use this callback if needed for a preview
        },
        onDetections: (dets) {
          // Wardrobe screen doesn't directly display detections, but confirms success
          if (dets.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Clothes scanned and added!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No clothes detected in image.')),
            );
          }
        },
        onNoDetections: (noDets) {
          if (noDets) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No clothes detected after scan.')),
            );
          }
        },
        onError: (message) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        ),
        onCountsAndItemsUpdated: (topCount, bottomCount, allTops, allBottoms) {
          // After a new item is scanned, refresh the outfit suggestions
          _fetchOutfitsAndSuggestions();
        },
      ),
    );

    // Initial fetch of outfits and suggestions
    _fetchOutfitsAndSuggestions();
  }

  // Method to categorize labels (similar to OotdScreen)
  bool _isTop(String label) {
    label = label.toLowerCase();
    if (label.contains('shoe')) return false; // Exclude shoes
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
    if (label.contains('shoe')) return false; // Exclude shoes
    return label.contains('pants') ||
        label.contains('jeans') ||
        label.contains('shorts') ||
        label.contains('skirt') ||
        label == 'bottom';
  }

  Future<void> _fetchOutfitsAndSuggestions({bool forceRefresh = false}) async {
    setState(() {
      _isLoadingOutfits = true;
    });

    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('scanned_items')
        .get();

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
        fetchedTops.add(item);
      } else if (_isBottom(label)) {
        fetchedBottoms.add(item);
      }
    }

    List<OutfitSuggestion> suggestions = [];
    // Only attempt to get suggestions if there are at least 2 tops and 2 bottoms
    // This is a heuristic to ensure meaningful combinations can be generated.
    if (fetchedTops.length >= 2 && fetchedBottoms.length >= 2) {
      suggestions = await _ollamaService.getAllOutfitCombinations(
        fetchedTops,
        fetchedBottoms,
        forceRefresh: forceRefresh, // Pass the forceRefresh parameter
      );
    }

    setState(() {
      _allTops = fetchedTops;
      _allBottoms = fetchedBottoms;
      _outfitSuggestions = suggestions;
      _isLoadingOutfits = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingOutfits) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Wardrobe',
          style: TextStyle(
            fontFamily: 'Dream-Avenue',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          _isLoadingImage
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : PopupMenuButton<ImageSource>(
                  icon: const Icon(Icons.add), // Add icon
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
                ),
          // New Refresh Button
          if (!_isLoadingOutfits) // Only show refresh if not already loading outfits
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _fetchOutfitsAndSuggestions(forceRefresh: true),
            ),
        ],
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_outfitSuggestions.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.checkroom_rounded,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      """No outfit combinations yet.
Scan more clothes or try again!""",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'SF',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: CarouselSlider.builder(
                itemCount: _outfitSuggestions.length,
                options: CarouselOptions(
                  height: double.infinity,
                  viewportFraction: 0.85,
                  enlargeCenterPage: true,
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 4),
                  autoPlayCurve: Curves.fastOutSlowIn,
                ),
                itemBuilder: (context, index, realIndex) {
                  return _buildOutfitCard(_outfitSuggestions[index]);
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Helper to parse RGB string to Color (copied from OotdScreen)
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

  // Build outfit card (copied and adapted from OotdScreen)
  Widget _buildOutfitCard(OutfitSuggestion suggestion) {
    final Color topColor = _parseRgbString(suggestion.top.color);
    final Color bottomColor = _parseRgbString(suggestion.bottom.color);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: topColor.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle decoration - Top Right Circle
          Positioned(
            top: -20,
            right: -20,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFF4B65F1).withValues(alpha: 0.7),
              child: Container(
                // For the white border
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
          // Background subtle decoration - Bottom Left Circle
          Positioned(
            bottom: -20,
            left: -20,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFFA78BFA).withValues(alpha: 0.7),
              child: Container(
                // For the white border
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
          Column(
            // Original content
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TintedSilhouette(shirtColor: topColor, pantsColor: bottomColor),
              if (suggestion.reason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Reason: ${suggestion.reason}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
