import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class OotdScreen extends StatefulWidget {
  const OotdScreen({super.key});

  @override
  State<OotdScreen> createState() => _OotdScreenState();
}

class _OotdScreenState extends State<OotdScreen> {
  // Simulating whether the user has scanned their wardrobe yet.
  // In a real app, this would be fetched from SharedPreferences, a database, or state management.
  bool _hasScannedWardrobe = false;

  void _scanWardrobe() {
    // Navigate to scanning screen or show a simulation
    setState(() {
      _hasScannedWardrobe = true;
    });
    // Give satisfying feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wardrobe scanned! Generating aesthetic recommendations...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasScannedWardrobe) {
      return _buildEmptyState();
    } else {
      return _buildOotdState();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _scanWardrobe,
              child: Container(
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.checkroom, // Hanger icon
                  size: 100,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Your wardrobe is empty!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap the hanger above to start scanning your closet. We\'ll use color theory to curate perfect daily outfits for you.',
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

  Widget _buildOotdState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Outfit of the Day',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Based on monochromatic color theory',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          // OOTD Display Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top placeholder Image (e.g. Shirt / Top)
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Icon(Icons.dry_cleaning, size: 60, color: AppColors.secondary),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Bottom placeholder Image (e.g. Pants / Bottoms)
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Icon(Icons.accessibility_new, size: 60, color: AppColors.secondary),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Color Palette Dots for the outfit
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildColorDot(AppColors.textPrimary),
                    const SizedBox(width: 12),
                    _buildColorDot(AppColors.primary),
                    const SizedBox(width: 12),
                    _buildColorDot(AppColors.secondary),
                    const SizedBox(width: 12),
                    _buildColorDot(AppColors.tertiary),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Generate New Vibe Button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () {
                // Future functionality: Cycle through different recommendations
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Finding a new vibe...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary, // Stark contrast for emphasis
                foregroundColor: AppColors.background,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Generate Another Vibe', 
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}
