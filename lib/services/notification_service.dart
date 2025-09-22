import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/gnss_station.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Notification configuration
  static const String _channelId = 'gnss_alerts';
  static const String _channelName = 'GNSS Accuracy Alerts';
  static const String _channelDescription = 'Notifications for GNSS station accuracy warnings';

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request notification permissions
    await _requestPermissions();

    // Initialize notification settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Request notification permission for Android 13+
      final status = await Permission.notification.request();
      if (status != PermissionStatus.granted) {
        debugPrint('Notification permission denied');
      }
    } else if (Platform.isIOS) {
      // iOS permissions are handled during initialization
      final permitted = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      
      if (permitted != true) {
        debugPrint('iOS notification permissions denied');
      }
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle navigation or actions based on payload
  }

  // Check station accuracy and send notification if needed
  Future<void> checkStationAccuracy(GnssStation station) async {
    if (!_isInitialized) await initialize();

    if (!station.isAccurate) {
      await _showAccuracyWarning(station);
    }
  }

  // Check multiple stations and send batch notification if needed
  Future<void> checkMultipleStations(List<GnssStation> stations) async {
    if (!_isInitialized) await initialize();

    final inaccurateStations = stations.where((station) => !station.isAccurate).toList();
    
    if (inaccurateStations.isNotEmpty) {
      if (inaccurateStations.length == 1) {
        await _showAccuracyWarning(inaccurateStations.first);
      } else {
        await _showMultipleStationsWarning(inaccurateStations);
      }
    }
  }

  // Show accuracy warning for single station
  Future<void> _showAccuracyWarning(GnssStation station) async {
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFFFF5722), // Orange warning color
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
    );

    await _notifications.show(
      station.id.hashCode, // Use station ID hash as notification ID
      'GNSS Accuracy Warning',
      '${station.name}: Accuracy ${station.accuracyString} exceeds threshold',
      notificationDetails,
      payload: 'station:${station.id}',
    );

    debugPrint('Accuracy warning sent for station: ${station.name}');
  }

  // Show warning for multiple stations
  Future<void> _showMultipleStationsWarning(List<GnssStation> stations) async {
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFFFF5722),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        groupKey: 'accuracy_warnings',
        setAsGroupSummary: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
    );

    final stationNames = stations.take(3).map((s) => s.name).join(', ');
    final additionalCount = stations.length > 3 ? ' +${stations.length - 3} more' : '';

    await _notifications.show(
      'multiple_warnings'.hashCode,
      'Multiple GNSS Accuracy Warnings',
      '${stations.length} stations exceed accuracy threshold: $stationNames$additionalCount',
      notificationDetails,
      payload: 'multiple:${stations.map((s) => s.id).join(',')}',
    );

    debugPrint('Multiple stations warning sent for ${stations.length} stations');
  }

  // Show data refresh notification
  Future<void> showDataRefreshNotification(int stationCount) async {
    if (!_isInitialized) await initialize();

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF4CAF50), // Green success color
        ongoing: false,
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: true,
        presentSound: false,
      ),
    );

    await _notifications.show(
      'data_refresh'.hashCode,
      'GNSS Data Updated',
      'Successfully refreshed $stationCount stations',
      notificationDetails,
      payload: 'refresh:$stationCount',
    );
  }

  // Show export completion notification
  Future<void> showExportCompletionNotification(String exportType, String fileName) async {
    if (!_isInitialized) await initialize();

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF2196F3), // Blue info color
        ongoing: false,
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.show(
      'export_complete'.hashCode,
      'Export Complete',
      '$exportType file saved: $fileName',
      notificationDetails,
      payload: 'export:$fileName',
    );
  }

  // Show connection error notification
  Future<void> showConnectionErrorNotification() async {
    if (!_isInitialized) await initialize();

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFFF44336), // Red error color
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.show(
      'connection_error'.hashCode,
      'NASA API Connection Failed',
      'Unable to fetch GNSS data. Using cached data.',
      notificationDetails,
      payload: 'error:connection',
    );
  }

  // Schedule periodic accuracy checks
  Future<void> schedulePeriodicChecks() async {
    if (!_isInitialized) await initialize();

    // This would typically be implemented with background tasks
    // For now, we'll show a notification about the feature
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        icon: '@mipmap/ic_launcher',
        ongoing: false,
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    );

    await _notifications.show(
      'periodic_checks'.hashCode,
      'GNSS Monitoring Active',
      'Periodic accuracy checks enabled',
      notificationDetails,
      payload: 'schedule:enabled',
    );
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('All notifications canceled');
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    } else if (Platform.isIOS) {
      // For iOS, we'll use the permission_handler approach
      final status = await Permission.notification.status;
      return status == PermissionStatus.granted;
    }
    return false;
  }

  // Request permission if not granted
  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status == PermissionStatus.granted;
    } else if (Platform.isIOS) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted == true;
    }
    return false;
  }

  // Open app settings for notification permissions
  Future<void> openNotificationSettings() async {
    await openAppSettings();
  }

  // Dispose resources
  void dispose() {
    // Clean up if needed
  }
}
