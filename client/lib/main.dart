import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'screens/ootd_screen.dart';

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
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
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

  // The content for each of the three tabs
  static const List<Widget> _pages = <Widget>[
    Center(
      child: Text(
        'My Wardrobe',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    ),
    OotdScreen(),
    Center(
      child: Text(
        'Account',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Welcome message on the top
        title: const Text(
          'What\'s the vibe today?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Widget on the top right corner for weather integration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.center,
            child: const Row(
              children: [
                Icon(Icons.wb_sunny, color: AppColors.weatherSun),
                SizedBox(width: 8),
                Text(
                  '72°F', // Placeholder for actual weather temperature
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.checkroom),
            label: 'My Wardrobe',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'OOTD'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }
}
