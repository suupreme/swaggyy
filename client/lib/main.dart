import 'dart:async'; // 1. Added for the Timer
import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'screens/ootd_screen.dart';
import 'screens/wardrobe_screen.dart';
import 'screens/account_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(const SwaggyyApp());
}

class SwaggyyApp extends StatelessWidget {
  const SwaggyyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swaggyy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: const SplashScreen(), // 2. Updated to start with SplashScreen
      debugShowCheckedModeBanner: false,
    );
  }
}

// 3. New Splash Screen Widget
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to HomeScreen after 2.5 seconds
    Timer(const Duration(milliseconds: 2500), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.white, // Using your primary color for the background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.checkroom, // A temporary placeholder logo
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'swaggyy',
              style: TextStyle(
                fontFamily: 'Dream-Avenue', // Using your custom font
                fontSize: 42,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: AppColors.primary.withOpacity(0.8),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    WardrobeScreen(),
    OotdScreen(),
    AccountScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Night';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedIndex == 2 ? 1 : 0,
        children: [
          SafeArea(
            child: Column(
              children: [
            // Custom Header area replacing the AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                          fontFamily: 'Dream-Avenue',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors
                              .textPrimary, // Make sure AppColors.textPrimary is defined
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'What\'s the vibe today?',
                        style: TextStyle(
                          fontFamily: 'Dream-Avenue',
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wb_sunny,
                          color: AppColors
                              .weatherSun, // Make sure AppColors.weatherSun is defined
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '72°F',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // The selected tab's content
            Expanded(
              child: IndexedStack(
                index: _selectedIndex == 1 ? 1 : 0,
                children: [
                  _pages[0],
                  _pages[1],
                ],
              ),
            ),
          ],
        ),
      ),
      _pages[2],
    ],
  ),
      bottomNavigationBar: SafeArea(
              child: Container(
                margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                iconTheme: WidgetStateProperty.all(
                  const IconThemeData(color: AppColors.textPrimary),
                ),
                labelTextStyle: WidgetStateProperty.all(
                  const TextStyle(
                    fontFamily: 'SF',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                indicatorShape: const StadiumBorder(),
                indicatorColor: Colors.black.withOpacity(0.08),
              ),
              child: NavigationBar(
                height: 85,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.checkroom_outlined),
                    label: 'Wardrobe',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'Account',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
