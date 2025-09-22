import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gnss_provider.dart';
import '../providers/theme_provider.dart';
import 'map_screen.dart';
import 'stations_list_screen.dart';
import 'charts_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _screens = const [
    MapScreen(),
    StationsListScreen(),
    ChartsScreen(),
    SettingsScreen(),
  ];

  final List<BottomNavigationBarItem> _navigationItems = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.map),
      activeIcon: Icon(Icons.map),
      label: 'Map',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.list),
      activeIcon: Icon(Icons.list),
      label: 'Stations',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.analytics),
      activeIcon: Icon(Icons.analytics),
      label: 'Charts',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings),
      activeIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: Consumer2<GnssProvider, ThemeProvider>(
        builder: (context, gnssProvider, themeProvider, child) {
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey[600],
            backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
            elevation: 8,
            items: _navigationItems.map((item) {
              // Add badges for certain tabs
              if (item.label == 'Stations') {
                return BottomNavigationBarItem(
                  icon: _buildBadgedIcon(
                    item.icon as Icon,
                    gnssProvider.inaccurateStations,
                    Colors.red,
                  ),
                  activeIcon: _buildBadgedIcon(
                    item.activeIcon as Icon,
                    gnssProvider.inaccurateStations,
                    Colors.red,
                  ),
                  label: item.label,
                );
              }
              return item;
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildBadgedIcon(Icon icon, int count, Color badgeColor) {
    if (count == 0) return icon;
    
    return Stack(
      children: [
        icon,
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
