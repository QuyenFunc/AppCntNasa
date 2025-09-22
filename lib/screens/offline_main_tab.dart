import 'package:flutter/material.dart';
import '../widgets/earthdata_auth_panel.dart';
import 'offline_search_tab.dart';
import 'offline_downloads_tab.dart';
import 'offline_viewer_tab.dart';

class OfflineMainTab extends StatefulWidget {
  const OfflineMainTab({super.key});

  @override
  State<OfflineMainTab> createState() => _OfflineMainTabState();
}

class _OfflineMainTabState extends State<OfflineMainTab>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Compact Earthdata Authentication Panel at top
        const EarthdataAuthPanel(),
        
        // Sub-tabs
        Container(
          color: Theme.of(context).primaryColor.withOpacity(0.05),
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(
                icon: Icon(Icons.search),
                text: 'Search',
              ),
              Tab(
                icon: Icon(Icons.download),
                text: 'Downloads',
              ),
              Tab(
                icon: Icon(Icons.visibility),
                text: 'Viewer',
              ),
            ],
          ),
        ),
        
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              OfflineSearchTab(),
              OfflineDownloadsTab(),
              OfflineViewerTab(),
            ],
          ),
        ),
      ],
    );
  }
}
