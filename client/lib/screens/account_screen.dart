import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isCelsius = false;

  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _waistController = TextEditingController();

  String? _selectedGender;
  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 25, color: Colors.black87),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Dream-Avenue',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Dream-Avenue', fontSize: 10),
        ),
      ], // Close the children list
    ); // Close the Column
  }

  Widget _buildEditableRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontFamily: 'Dream-Avenue', fontSize: 20),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'SF',
                fontSize: 18,
                color: Colors.black54,
              ),
              decoration: const InputDecoration(
                hintText: '--',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'in',
            style: TextStyle(
              fontFamily: 'SF',
              fontSize: 18,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderDropdownRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Gender',
            style: TextStyle(fontFamily: 'Dream-Avenue', fontSize: 20),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender,
              hint: const Text(
                '--',
                style: TextStyle(
                  fontFamily: 'SF',
                  fontSize: 18,
                  color: Colors.black54,
                ),
              ),
              icon:
                  const SizedBox.shrink(), // hide the default arrow optionally
              alignment: AlignmentDirectional.centerEnd,
              style: const TextStyle(
                fontFamily: 'SF',
                fontSize: 18,
                color: Colors.black54,
              ),
              items: _genderOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedGender = newValue;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: const Text(
            'Share Profile',
            style: TextStyle(fontFamily: 'Dream-Avenue'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Copy this link to share your profile with friends!',
                style: TextStyle(fontFamily: 'SF', fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'swaggyy.app/u/me123',
                        style: TextStyle(
                          fontFamily: 'SF',
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard!'),
                          ),
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          // Outer SingleChildScrollView for the entire content
          child: Column(
            children: [
              // "My Account" header
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 15, 28, 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Account',
                      style: TextStyle(
                        fontFamily: 'Dream-Avenue',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showShareDialog(context),
                      child: const Icon(Icons.ios_share, size: 28),
                    ),
                  ],
                ),
              ),

              // Profile Info
              Container(
                width: double.infinity,
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 32,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 4),
                        gradient: const SweepGradient(
                          colors: [
                            Color(0xFFD95A4D),
                            Color(0xFFE89A4E),
                            Color(0xFFEDC951),
                            Color(0xFF558988),
                            Color(0xFFD95A4D),
                          ],
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.background,
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 50,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Albert',
                          style: TextStyle(
                            fontFamily: 'Dream-Avenue',
                            fontSize: 20,
                          ),
                        ),
                        const Text(
                          'account created: Mar 2026',
                          style: TextStyle(
                            fontFamily: 'Dream-Avenue',
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow
                              .ellipsis, // Added overflow to prevent issues if text is too long
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stats
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStat(Icons.checkroom_outlined, '42', 'fits created'),
                    _buildStat(Icons.group_outlined, '0', 'friends'),
                    _buildStat(
                      Icons.local_fire_department_outlined,
                      '69',
                      'swag streak',
                    ),
                  ],
                ),
              ),

              // Editable Fields
              Container(
                // No Expanded here
                width: double.infinity,
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 24,
                ),
                child: Column(
                  // This Column does not need to be wrapped in SingleChildScrollView again
                  children: [
                    _buildGenderDropdownRow(),
                    _buildEditableRow('Height', _heightController),
                    _buildEditableRow('Waist', _waistController),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Temp Units',
                            style: TextStyle(
                              fontFamily: 'Dream-Avenue',
                              fontSize: 20,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isCelsius = !_isCelsius;
                              });
                            },
                            child: Container(
                              width: 90,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    left: _isCelsius ? 45 : 0,
                                    right: _isCelsius ? 0 : 45,
                                    child: Container(
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: _isCelsius
                                            ? Colors.green
                                            : const Color(
                                                0xFFF79471,
                                              ), // green when Celsius, peach when F
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            '°F',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: !_isCelsius
                                                  ? Colors.black
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            '°C',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: _isCelsius
                                                  ? Colors.white
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
