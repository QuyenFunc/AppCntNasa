import 'package:flutter/material.dart';
import 'realtime_main_tab.dart';
import 'offline_main_tab.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = const [
    RealtimeMainTab(),
    OfflineMainTab(),
  ];

  final List<String> _titles = [
    'Realtime (EarthScope)',
    'Offline (Earthdata)',
  ];

  final List<Color> _brandColors = [
    Color(0xFF2196F3), // Blue for Realtime
    Color(0xFF4CAF50), // Green for Offline
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: _brandColors[_currentIndex],
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _brandColors[_currentIndex],
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_currentIndex]),
          backgroundColor: _brandColors[_currentIndex].withOpacity(0.1),
          foregroundColor: _brandColors[_currentIndex],
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Settings'),
                    content: const Text('Settings panel will be implemented here.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: _brandColors[_currentIndex],
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.satellite_alt),
              label: 'Realtime',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.cloud_download),
              label: 'Offline',
            ),
          ],
        ),
      ),
    );
  }
}
