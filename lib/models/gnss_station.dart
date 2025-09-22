import 'package:json_annotation/json_annotation.dart';
import 'package:hive/hive.dart';

part 'gnss_station.g.dart';

@JsonSerializable()
@HiveType(typeId: 0)
class GnssStation extends HiveObject {
  @HiveField(0)
  @JsonKey(name: 'station_id')
  final String id;

  @HiveField(1)
  @JsonKey(name: 'station_name')
  final String name;

  @HiveField(2)
  @JsonKey(name: 'latitude')
  final double latitude;

  @HiveField(3)
  @JsonKey(name: 'longitude')
  final double longitude;

  @HiveField(4)
  @JsonKey(name: 'accuracy')
  final double accuracy; // in meters

  @HiveField(5)
  @JsonKey(name: 'last_updated')
  final DateTime updatedAt;

  @HiveField(6)
  @JsonKey(name: 'elevation')
  final double? elevation;

  @HiveField(7)
  @JsonKey(name: 'satellite_count')
  final int? satelliteCount;

  @HiveField(8)
  @JsonKey(name: 'signal_strength')
  final double? signalStrength;

  @HiveField(9)
  @JsonKey(name: 'status')
  final String? status;

  GnssStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.updatedAt,
    this.elevation,
    this.satelliteCount,
    this.signalStrength,
    this.status,
  });

  factory GnssStation.fromJson(Map<String, dynamic> json) =>
      _$GnssStationFromJson(json);

  Map<String, dynamic> toJson() => _$GnssStationToJson(this);

  // Helper methods
  bool get isAccurate => accuracy <= 5.0; // Warning threshold at 5 meters
  
  String get statusDisplay => status ?? 'Active';
  
  String get coordinatesString => 
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  
  String get accuracyString => '${accuracy.toStringAsFixed(2)}m';

  // For comparison and sorting
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GnssStation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  // Create a copy with updated values (for real-time updates)
  GnssStation copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? updatedAt,
    double? elevation,
    int? satelliteCount,
    double? signalStrength,
    String? status,
  }) {
    return GnssStation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      updatedAt: updatedAt ?? this.updatedAt,
      elevation: elevation ?? this.elevation,
      satelliteCount: satelliteCount ?? this.satelliteCount,
      signalStrength: signalStrength ?? this.signalStrength,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'GnssStation{id: $id, name: $name, lat: $latitude, lon: $longitude, accuracy: $accuracy, updatedAt: $updatedAt}';
  }
}

// Model for accuracy data points (for charts)
@JsonSerializable()
@HiveType(typeId: 1)
class AccuracyDataPoint extends HiveObject {
  @HiveField(0)
  final String stationId;

  @HiveField(1)
  final double accuracy;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final double? signalStrength;

  AccuracyDataPoint({
    required this.stationId,
    required this.accuracy,
    required this.timestamp,
    this.signalStrength,
  });

  factory AccuracyDataPoint.fromJson(Map<String, dynamic> json) =>
      _$AccuracyDataPointFromJson(json);

  Map<String, dynamic> toJson() => _$AccuracyDataPointToJson(this);

  factory AccuracyDataPoint.fromStation(GnssStation station) {
    return AccuracyDataPoint(
      stationId: station.id,
      accuracy: station.accuracy,
      timestamp: station.updatedAt,
      signalStrength: station.signalStrength,
    );
  }
}
