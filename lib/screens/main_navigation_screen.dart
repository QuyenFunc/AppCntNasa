import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'realtime_main_tab.dart';
import 'offline_main_tab.dart';
import 'worldview_screen.dart';
import 'firms_screen.dart';
import 'settings_screen.dart';
import '../providers/theme_provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  
  // PERFORMANCE OPTIMIZATION: Track visited screens for lazy loading
  final Set<int> _visitedScreens = {0}; // Start with first screen visited
  
  final List<Widget> _screens = const [
    RealtimeMainTab(),
    OfflineMainTab(),
    WorldviewScreen(),
    FirmsScreen(),
  ];

  final List<String> _titles = [
    'Realtime (EarthScope)',
    'Offline (Earthdata)',
    'NASA Worldview',
    'NASA FIRMS',
  ];

  final List<Color> _brandColors = [
    Color(0xFF2196F3), // Blue for Realtime
    Color(0xFF4CAF50), // Green for Offline
    Color(0xFF673AB7), // Purple for Worldview
    Color(0xFFE53935), // Red for FIRMS
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, provider, child) {
        return Theme(
          data: provider.currentTheme.copyWith(
            colorScheme: provider.currentTheme.colorScheme.copyWith(
              primary: _brandColors[_currentIndex],
            ),
          ),
          child: Scaffold(
            appBar: _currentIndex < 2 ? AppBar(
              title: Text(_titles[_currentIndex]),
              backgroundColor: _brandColors[_currentIndex].withOpacity(0.1),
              foregroundColor: _brandColors[_currentIndex],
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ) : null,
            body: IndexedStack(
              index: _currentIndex,
              // PERFORMANCE OPTIMIZATION: Lazy loading screens
              children: _screens.asMap().entries.map((entry) {
                final index = entry.key;
                final screen = entry.value;
                
                // Chỉ build screen hiện tại và screen đã được visit
                if (index == _currentIndex || _visitedScreens.contains(index)) {
                  return screen;
                } else {
                  // Placeholder cho screens chưa được visit
                  return Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
              }).toList(),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                  // PERFORMANCE OPTIMIZATION: Mark screen as visited
                  _visitedScreens.add(index);
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.satellite_alt_outlined),
                  selectedIcon: Icon(Icons.satellite_alt),
                  label: 'Realtime',
                ),
                NavigationDestination(
                  icon: Icon(Icons.cloud_download_outlined),
                  selectedIcon: Icon(Icons.cloud_download),
                  label: 'Offline',
                ),
                NavigationDestination(
                  icon: Icon(Icons.public_outlined),
                  selectedIcon: Icon(Icons.public),
                  label: 'Worldview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_fire_department_outlined),
                  selectedIcon: Icon(Icons.local_fire_department),
                  label: 'FIRMS',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}