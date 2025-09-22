import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/offline_provider.dart';

class EarthdataAuthPanel extends StatefulWidget {
  const EarthdataAuthPanel({super.key});

  @override
  State<EarthdataAuthPanel> createState() => _EarthdataAuthPanelState();
}

class _EarthdataAuthPanelState extends State<EarthdataAuthPanel> {
  final _apiKeyController = TextEditingController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, provider, child) {
        return Card(
          margin: const EdgeInsets.all(8.0),
          elevation: 2,
          child: Column(
            children: [
              // Compact status bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Authentication status indicator
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: provider.isAuthenticated ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Status text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.isAuthenticated 
                                ? 'Earthdata Authenticated' 
                                : 'Not Authenticated',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (provider.isAuthenticated && provider.userInfo.isNotEmpty)
                            Text(
                              'User: ${provider.userInfo['username'] ?? 'Unknown'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    
                    // Auth status badge
                    if (provider.isAuthenticated)
                      const Chip(
                        label: Text('API Ready'),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )
                    else
                      const Chip(
                        label: Text('API Key Required'),
                        backgroundColor: Colors.orange,
                        labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    
                    // Expand/Collapse button
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      icon: Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Expandable authentication form
              if (_isExpanded)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: const Border(
                      top: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NASA Earthdata Authentication',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      
                      // API Key input
                      TextFormField(
                        controller: _apiKeyController,
                        decoration: InputDecoration(
                          labelText: 'Bearer Token / API Key',
                          hintText: 'Paste your NASA Earthdata Bearer token here',
                          border: const OutlineInputBorder(),
                          suffixIcon: provider.isAuthenticated
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : const Icon(Icons.key),
                        ),
                        obscureText: !provider.isAuthenticated,
                        maxLines: provider.isAuthenticated ? null : 1,
                      ),
                      const SizedBox(height: 16),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                            onPressed: provider.isAuthenticating 
                                ? null 
                                : () => _authenticate(provider),
                            icon: provider.isAuthenticating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.login),
                            label: Text(provider.isAuthenticated ? 'Re-authenticate' : 'Authenticate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            ),
                          ),
                          
                          if (provider.isAuthenticated)
                            ElevatedButton.icon(
                              onPressed: () => _logout(provider),
                              icon: const Icon(Icons.logout),
                              label: const Text('Logout'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          
                          const Spacer(),
                          
                          TextButton.icon(
                            onPressed: _showHelpDialog,
                            icon: const Icon(Icons.help_outline),
                            label: const Text('Help'),
                          ),
                        ],
                      ),
                      
                      // Status message
                      if (provider.authStatusMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: provider.isAuthenticated 
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            border: Border.all(
                              color: provider.isAuthenticated 
                                  ? Colors.green 
                                  : Colors.red,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                provider.isAuthenticated 
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                color: provider.isAuthenticated 
                                    ? Colors.green 
                                    : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  provider.authStatusMessage,
                                  style: TextStyle(
                                    color: provider.isAuthenticated 
                                        ? Colors.green[700] 
                                        : Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _authenticate(OfflineProvider provider) async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your API key')),
      );
      return;
    }

    try {
      await provider.authenticate(apiKey);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication failed: $e')),
        );
      }
    }
  }

  Future<void> _logout(OfflineProvider provider) async {
    await provider.logout();
    _apiKeyController.clear();
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Get NASA Earthdata API Key'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'To access NASA Earthdata services, you need a Bearer token:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('1. Go to https://urs.earthdata.nasa.gov/'),
              SizedBox(height: 8),
              Text('2. Login to your account (or create one)'),
              SizedBox(height: 8),
              Text('3. Go to Profile → Applications'),
              SizedBox(height: 8),
              Text('4. Click "Generate Token"'),
              SizedBox(height: 8),
              Text('5. Copy the Bearer token'),
              SizedBox(height: 8),
              Text('6. Paste it in the API Key field above'),
              SizedBox(height: 16),
              Text(
                'Note: This token is used to search and download GNSS data from NASA\'s Common Metadata Repository (CMR).',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
