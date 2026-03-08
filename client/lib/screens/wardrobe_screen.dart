import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';

class WardrobeScreen extends StatefulWidget {
  final String userId;
  const WardrobeScreen({super.key, required this.userId});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Your Wardrobe',
            style: TextStyle(
              fontFamily: 'Dream-Avenue',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        // Section for Tops
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Tops',
            style: TextStyle(
              fontFamily: 'Dream-Avenue',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: _buildClothingList('top'),
        ),
        // Section for Bottoms
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Bottoms',
            style: TextStyle(
              fontFamily: 'Dream-Avenue',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: _buildClothingList('bottom'),
        ),
      ],
    );
  }

  Widget _buildClothingList(String category) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('scanned_items')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No $category items scanned yet.'));
        }

        final allItems = snapshot.data!.docs;
        final filteredItems = allItems.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String label = data['label']?.toString().toLowerCase() ?? '';
          if (category == 'top') {
            return label.contains('shirt') ||
                label.contains('t-shirt') ||
                label.contains('blouse') ||
                label.contains('sweater') ||
                label.contains('hoodie') ||
                label.contains('jacket') ||
                label == 'top';
          } else if (category == 'bottom') {
            return label.contains('pants') ||
                label.contains('jeans') ||
                label.contains('shorts') ||
                label.contains('skirt') ||
                label == 'bottom';
          }
          return false;
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(child: Text('No $category items found based on labels.'));
        }

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final data = filteredItems[index].data() as Map<String, dynamic>;
            final String label = data['label']?.toString() ?? 'Unknown';
            final List<dynamic> mainColorRgb = data['mainColor'] ?? [0, 0, 0];
            final Color mainColor = Color.fromARGB(
              255,
              mainColorRgb[0].toInt(),
              mainColorRgb[1].toInt(),
              mainColorRgb[2].toInt(),
            );

            return Card(
              margin: const EdgeInsets.all(8.0),
              color: mainColor.withOpacity(0.8), // Use the main color as card background
              child: SizedBox(
                width: 150, // Fixed width for each card
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
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: mainColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                      // Could add more details here later, e.g., complementary color
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
