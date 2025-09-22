# NASA GNSS Client

A beautiful and feature-rich Flutter application for monitoring NASA GNSS (Global Navigation Satellite System) stations with real-time data visualization, interactive maps, and comprehensive analytics.

## 🚀 Features

### Core Functionality
- **Real-time GNSS Data**: Fetch and display live satellite positioning data from NASA APIs
- **Interactive Map**: OpenStreetMap integration with station markers and accuracy circles
- **Station Management**: Comprehensive list view with search, filter, and sorting capabilities
- **Real-time Analytics**: Dynamic charts showing accuracy trends and signal strength over time
- **Offline Support**: Local caching with SQLite and Hive for offline access

### Advanced Features
- **Data Export**: Export station data in CSV, JSON, and text formats
- **Smart Notifications**: Accuracy threshold alerts with customizable warnings
- **Multi-station Selection**: Bulk operations and batch data processing
- **Dark Mode**: Beautiful dark/light theme with custom color options
- **Performance Optimized**: Efficient data handling and smooth animations

### User Experience
- **Modern UI**: Material Design 3 with smooth animations and transitions
- **Responsive Design**: Optimized for phones, tablets, and web
- **Intuitive Navigation**: Bottom navigation bar with contextual actions
- **Accessibility**: Full accessibility support with semantic labels
- **Error Handling**: Graceful error handling with informative messages

## 📱 Screenshots

### Map View
- Interactive OpenStreetMap with GNSS station markers
- Real-time accuracy visualization with color-coded indicators
- Station info popups with detailed information
- Map controls for zoom, location, and filter options

### Stations List
- Searchable and filterable station list
- Batch selection and export capabilities
- Real-time status indicators
- Comprehensive station details

### Analytics Dashboard
- Real-time accuracy charts with fl_chart
- Signal strength monitoring
- Statistical analysis with averages and trends
- Customizable time ranges (1H, 6H, 24H, 3D, 1W, 1M)

### Settings
- Dark/light theme toggle
- Custom theme colors
- Notification preferences
- Data management tools
- Export history tracking

## 🛠 Technical Architecture

### State Management
- **Provider Pattern**: Efficient state management with ChangeNotifier
- **Theme Provider**: Dynamic theming with persistence
- **GNSS Provider**: Station data management and real-time updates

### Data Layer
- **SQLite**: Persistent storage for station data and history
- **Hive**: Fast caching for frequently accessed data
- **API Service**: NASA Earthdata API integration with authentication

### Services
- **Database Service**: Unified data access layer
- **Export Service**: Multi-format data export (CSV, JSON, TXT)
- **Notification Service**: Push notifications for accuracy alerts
- **API Service**: NASA API integration with fallback mock data

### UI Components
- **Reusable Widgets**: Modular UI components for consistency
- **Custom Animations**: Smooth transitions and loading states
- **Responsive Layouts**: Adaptive UI for different screen sizes

## 🏗 Project Structure

```
lib/
├── models/
│   ├── gnss_station.dart          # GNSS station data model
│   └── gnss_station.g.dart        # Generated code for serialization
├── services/
│   ├── nasa_api_service.dart      # NASA API integration
│   ├── database_service.dart      # SQLite and Hive management
│   ├── notification_service.dart  # Push notifications
│   └── export_service.dart        # Data export functionality
├── providers/
│   ├── gnss_provider.dart         # Station data state management
│   └── theme_provider.dart        # Theme and UI preferences
├── screens/
│   ├── home_screen.dart           # Main navigation container
│   ├── map_screen.dart            # Interactive map view
│   ├── stations_list_screen.dart  # Station list and management
│   ├── charts_screen.dart         # Analytics and charts
│   └── settings_screen.dart       # App settings and preferences
├── widgets/
│   ├── station_info_popup.dart    # Map popup widget
│   ├── station_list_item.dart     # List item component
│   ├── map_controls.dart          # Map control buttons
│   ├── chart_controls.dart        # Chart customization
│   ├── station_selector.dart      # Station dropdown
│   ├── search_bar_widget.dart     # Search functionality
│   └── filter_dialog.dart         # Filter options dialog
└── main.dart                      # App entry point with splash screen
```

## 🔧 Setup Instructions

### Prerequisites
- Flutter SDK (3.35.1 or later)
- Dart SDK (3.5.0 or later)
- Android Studio or VS Code
- Android SDK or iOS development tools

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd nasa_gnss_client
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run code generation**
   ```bash
   flutter packages pub run build_runner build
   ```

4. **Run the application**
   ```bash
   flutter run
   ```

### Configuration

#### NASA API Token
The app includes a NASA Earthdata API token for development. For production use:

1. Register at [NASA Earthdata](https://urs.earthdata.nasa.gov/)
2. Replace the token in `lib/services/nasa_api_service.dart`

#### Mock Data
If NASA APIs are unavailable, the app automatically falls back to generated mock data for development and testing.

## 📦 Dependencies

### Core Dependencies
- **flutter_map**: Interactive map widget
- **latlong2**: Geographic coordinate calculations
- **fl_chart**: Beautiful chart library
- **provider**: State management
- **sqflite**: SQLite database
- **hive**: Fast key-value storage
- **dio**: HTTP client for API requests

### UI/UX Dependencies
- **fluttertoast**: Toast notifications
- **flutter_local_notifications**: Push notifications
- **share_plus**: File sharing capabilities
- **permission_handler**: Runtime permissions

### Data Export
- **csv**: CSV file generation
- **path_provider**: File system access
- **json_annotation**: JSON serialization

## 🎯 Key Features Implementation

### Real-time Data Updates
```dart
// Automatic data refresh with provider pattern
await gnssProvider.fetchStations();
await gnssProvider.refreshStations();
```

### Interactive Map
```dart
// OpenStreetMap with custom markers
FlutterMap(
  options: MapOptions(
    onTap: (tapPosition, point) => _showStationPopup(station),
  ),
  children: [
    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
    MarkerLayer(markers: _buildMarkers(stations)),
  ],
)
```

### Data Export
```dart
// Multi-format export support
await exportService.exportStationsToCSV(stations);
await exportService.exportStationsToJSON(stations);
await exportService.shareExportedFile(filePath);
```

### Push Notifications
```dart
// Accuracy threshold alerts
await notificationService.checkStationAccuracy(station);
await notificationService.showAccuracyWarning(station);
```

## 🔒 Security & Privacy

- **No Personal Data**: App only processes public GNSS station data
- **Local Storage**: All data stored locally on device
- **API Security**: Secure NASA API token authentication
- **Permissions**: Minimal required permissions for functionality

## 🚧 Future Enhancements

- [ ] Real-time WebSocket connections for live updates
- [ ] Augmented Reality (AR) for satellite visualization
- [ ] Machine Learning predictions for accuracy trends
- [ ] Multi-language support (i18n)
- [ ] Tablet-optimized UI layouts
- [ ] Background sync with WorkManager
- [ ] Advanced filtering and search capabilities
- [ ] Custom map tiles and satellite imagery
- [ ] Integration with other GNSS providers
- [ ] Historical data analysis tools

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **NASA Earthdata**: For providing open access to GNSS data
- **OpenStreetMap**: For beautiful map tiles
- **Flutter Community**: For excellent packages and documentation
- **Material Design**: For design system and components

## 📞 Support

For support, email [your-email@example.com] or create an issue in this repository.

---

**Built with ❤️ using Flutter and NASA's open data**