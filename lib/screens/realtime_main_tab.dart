import 'package:flutter/material.dart';
import '../widgets/ntrip_connection_panel.dart';
import 'realtime_map_tab.dart';
import 'realtime_stations_tab.dart';
import 'realtime_charts_tab.dart';

class RealtimeMainTab extends StatefulWidget {
  const RealtimeMainTab({super.key});

  @override
  State<RealtimeMainTab> createState() => _RealtimeMainTabState();
}

class _RealtimeMainTabState extends State<RealtimeMainTab>
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
        // NTRIP Connection Panel at top - constrained to prevent overflow
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4, // Max 40% of screen height
          ),
          child: const SingleChildScrollView(
            child: NtripConnectionPanel(),
          ),
        ),
        
        // Sub-tabs
        Container(
          color: Theme.of(context).primaryColor.withOpacity(0.05),
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(
                icon: Icon(Icons.map),
                text: 'Map',
              ),
              Tab(
                icon: Icon(Icons.list),
                text: 'Stations',
              ),
              Tab(
                icon: Icon(Icons.analytics),
                text: 'Charts',
              ),
            ],
          ),
        ),
        
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              RealtimeMapTab(),
              RealtimeStationsTab(),
              RealtimeChartsTab(),
            ],
          ),
        ),
      ],
    );
  }
}
