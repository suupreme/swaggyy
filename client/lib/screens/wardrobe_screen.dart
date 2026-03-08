import 'package:flutter/material.dart';
import '../widgets/tinted_silhouette.dart';
import '../theme/app_colors.dart';
import 'package:carousel_slider/carousel_slider.dart';

// Port 1: A data model representing the outfit.
// Coworkers can replace this or map their backend data to it.
class OutfitModel {
  final int shirtR;
  final int shirtG;
  final int shirtB;
  final int pantsR;
  final int pantsG;
  final int pantsB;

  const OutfitModel({
    required this.shirtR,
    required this.shirtG,
    required this.shirtB,
    required this.pantsR,
    required this.pantsG,
    required this.pantsB,
  });

  Color get shirtColor => Color.fromRGBO(shirtR, shirtG, shirtB, 1.0);
  Color get pantsColor => Color.fromRGBO(pantsR, pantsG, pantsB, 1.0);
}

class WardrobeScreen extends StatefulWidget {
  // Port 2: Pass down the data from a parent or state manager here.
  // Set to null to show dummy data, or an empty list [] to show the empty state.
  final List<OutfitModel>? outfits;

  // Port 3: A callback triggered when the user wants to fetch data manually, or when screen loads.
  final VoidCallback? onFetchData;

  const WardrobeScreen({super.key, this.outfits, this.onFetchData});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  // Dummy values for MVP until backend is connected.
  final List<OutfitModel> _dummyData = [
    const OutfitModel(
      shirtR: 244,
      shirtG: 67,
      shirtB: 54,
      pantsR: 33,
      pantsG: 33,
      pantsB: 33,
    ), // Red top, dark pants
    const OutfitModel(
      shirtR: 100,
      shirtG: 181,
      shirtB: 246,
      pantsR: 238,
      pantsG: 238,
      pantsB: 238,
    ), // Light blue top, white pants
    const OutfitModel(
      shirtR: 76,
      shirtG: 175,
      shirtB: 80,
      pantsR: 121,
      pantsG: 85,
      pantsB: 72,
    ), // Green top, brown pants
    const OutfitModel(
      shirtR: 255,
      shirtG: 193,
      shirtB: 7,
      pantsR: 21,
      pantsG: 101,
      pantsB: 192,
    ), // Yellow top, blue pants
  ];

  @override
  void initState() {
    super.initState();

    // Call Port 3 gracefully if needed
    if (widget.onFetchData != null) {
      widget.onFetchData!();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If widget.outfits is explicitly [], display empty state.
    // Otherwise fallback to dummy data for demonstration.
    final items = widget.outfits ?? _dummyData;

    if (items.isEmpty) {
      return Center(
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
              "No outfits saved yet.\nConnect to back-end to load wardrobe!",
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "My Wardrobe",
                style: TextStyle(
                  fontFamily: 'Dream-Avenue',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  onPressed: () {
                    // Future backend port: Add outfit
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: CarouselSlider.builder(
            itemCount: items.length,
            options: CarouselOptions(
              height: double.infinity,
              viewportFraction: 0.85,
              enlargeCenterPage: true,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 4),
              autoPlayCurve: Curves.fastOutSlowIn,
            ),
            itemBuilder: (context, index, realIndex) {
              return _buildWardrobeCard(items[index], index);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWardrobeCard(OutfitModel outfit, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: outfit.shirtColor.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background subtle decoration
          Positioned(
            top: -20,
            right: -20,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: outfit.shirtColor.withOpacity(0.05),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: outfit.pantsColor.withOpacity(0.05),
            ),
          ),
          // Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TintedSilhouette(
                shirtColor: outfit.shirtColor,
                pantsColor: outfit.pantsColor,
                size: 130, // Reduced size further to fully prevent overflow on small vertical constraints
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (widget.outfits != null) {
                      widget.outfits!.removeAt(index);
                    } else {
                      _dummyData.removeAt(index);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Wear',
                        style: TextStyle(
                          fontFamily: 'SF',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
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
