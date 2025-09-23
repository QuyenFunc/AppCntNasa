import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern SliverAppBar
          SliverAppBar.large(
            title: const Text('Settings'),
            backgroundColor: colorScheme.surface,
            surfaceTintColor: colorScheme.surfaceTint,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          
          // Settings Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Theme Section
                _buildSectionCard(
                  context,
                  title: 'Appearance',
                  icon: Icons.palette_outlined,
                  children: [
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        return Column(
                          children: [
                            // Dark Mode Toggle
                            _buildSettingTile(
                              context,
                              title: 'Dark Mode',
                              subtitle: 'Switch between light and dark themes',
                              leading: Icon(
                                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                                color: colorScheme.primary,
                              ),
                              trailing: Switch(
                                value: themeProvider.isDarkMode,
                                onChanged: (value) => themeProvider.toggleDarkMode(),
                              ),
                            ),
                            
                            const Divider(height: 1),
                            
                            // Color Picker
                            _buildColorPickerTile(context, themeProvider),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // App Info Section
                _buildSectionCard(
                  context,
                  title: 'About',
                  icon: Icons.info_outline,
                  children: [
                    _buildSettingTile(
                      context,
                      title: 'NASA GNSS Client',
                      subtitle: 'Version 1.0.0',
                      leading: Icon(Icons.satellite_alt, color: colorScheme.primary),
                      onTap: () => _showAboutDialog(context),
                    ),
                    
                    const Divider(height: 1),
                    
                    _buildSettingTile(
                      context,
                      title: 'Privacy Policy',
                      subtitle: 'View our privacy policy',
                      leading: Icon(Icons.privacy_tip_outlined, color: colorScheme.primary),
                      onTap: () => _showPrivacyDialog(context),
                    ),
                    
                    const Divider(height: 1),
                    
                    _buildSettingTile(
                      context,
                      title: 'Open Source Licenses',
                      subtitle: 'View third-party licenses',
                      leading: Icon(Icons.code, color: colorScheme.primary),
                      onTap: () => _showLicensesDialog(context),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Footer
                Center(
                  child: Text(
                    'Made with ❤️ for NASA GNSS',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Section Content
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null 
        ? Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildColorPickerTile(BuildContext context, ThemeProvider themeProvider) {
    final theme = Theme.of(context);
    
    return ExpansionTile(
      leading: Icon(Icons.color_lens, color: theme.colorScheme.primary),
      title: Text(
        'Theme Color',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        'Choose your preferred color scheme',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ThemeProvider.colorOptions.map((color) {
              final isSelected = themeProvider.primaryColor.value == color.value;
              return GestureDetector(
                onTap: () => themeProvider.setPrimaryColor(color),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected 
                        ? theme.colorScheme.outline
                        : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: isSelected
                    ? Icon(
                        Icons.check,
                        color: _getContrastColor(color),
                        size: 24,
                      )
                    : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getContrastColor(Color color) {
    // Calculate luminance to determine if white or black text should be used
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'NASA GNSS Client',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        Icons.satellite_alt,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
      children: [
        const Text(
          'A comprehensive GNSS monitoring application using NASA\'s real-time data services including EarthScope, Earthdata, Worldview, and FIRMS.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Features:\n'
          '• Real-time GNSS data monitoring\n'
          '• Offline data analysis\n'
          '• NASA Worldview satellite imagery\n'
          '• FIRMS fire detection data\n'
          '• Material 3 design\n'
          '• Dark mode support',
        ),
      ],
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'This app collects and processes location data for GNSS monitoring purposes. '
            'No personal information is stored or transmitted to third parties. '
            'All data processing is performed locally on your device.\n\n'
            'NASA data services are accessed through their public APIs and are subject to '
            'their respective terms of service and privacy policies.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLicensesDialog(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'NASA GNSS Client',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        Icons.satellite_alt,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
