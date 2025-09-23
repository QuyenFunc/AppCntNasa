import 'package:json_annotation/json_annotation.dart';

part 'firms_fire_data.g.dart';

@JsonSerializable()
class FirmsFireData {
  final double latitude;
  final double longitude;
  final double? brightness; // Brightness temperature (Kelvin)
  final String? scan; // Scan size (nominal scan size in km)
  final String? track; // Track size (nominal track size in km)
  final DateTime acqDate; // Acquisition date
  final String acqTime; // Acquisition time (HHMM)
  final String satellite; // Satellite name (Terra, Aqua, etc.)
  final String instrument; // Instrument name (MODIS, VIIRS)
  final String confidence; // Confidence level (low, nominal, high)
  final String version; // Version number
  final double? brightT31; // Channel 31 brightness temperature
  final double? frp; // Fire Radiative Power (MW)
  final String? daynight; // Day or night detection (D/N)
  final String? type; // Fire type (0=presumed vegetation fire, etc.)

  const FirmsFireData({
    required this.latitude,
    required this.longitude,
    this.brightness,
    this.scan,
    this.track,
    required this.acqDate,
    required this.acqTime,
    required this.satellite,
    required this.instrument,
    required this.confidence,
    required this.version,
    this.brightT31,
    this.frp,
    this.daynight,
    this.type,
  });

  factory FirmsFireData.fromJson(Map<String, dynamic> json) =>
      _$FirmsFireDataFromJson(json);

  Map<String, dynamic> toJson() => _$FirmsFireDataToJson(this);

  // Convert from CSV format (common FIRMS export format)
  factory FirmsFireData.fromCsv(List<String> csvRow) {
    try {
      return FirmsFireData(
        latitude: double.parse(csvRow[0]),
        longitude: double.parse(csvRow[1]),
        brightness: csvRow[2].isNotEmpty ? double.tryParse(csvRow[2]) : null,
        scan: csvRow[3].isNotEmpty ? csvRow[3] : null,
        track: csvRow[4].isNotEmpty ? csvRow[4] : null,
        acqDate: DateTime.parse(csvRow[5]),
        acqTime: csvRow[6],
        satellite: csvRow[7],
        instrument: csvRow[8],
        confidence: csvRow[9],
        version: csvRow[10],
        brightT31: csvRow.length > 11 && csvRow[11].isNotEmpty ? double.tryParse(csvRow[11]) : null,
        frp: csvRow.length > 12 && csvRow[12].isNotEmpty ? double.tryParse(csvRow[12]) : null,
        daynight: csvRow.length > 13 && csvRow[13].isNotEmpty ? csvRow[13] : null,
        type: csvRow.length > 14 && csvRow[14].isNotEmpty ? csvRow[14] : null,
      );
    } catch (e) {
      throw FormatException('Invalid CSV format for FIRMS fire data: $e');
    }
  }

  // Get full acquisition datetime
  DateTime get acquisitionDateTime {
    final timeStr = acqTime.padLeft(4, '0'); // Ensure 4 digits
    final hour = int.parse(timeStr.substring(0, 2));
    final minute = int.parse(timeStr.substring(2, 4));
    
    return DateTime(
      acqDate.year,
      acqDate.month,
      acqDate.day,
      hour,
      minute,
    );
  }

  // Get confidence as enum
  FireConfidence get confidenceLevel {
    switch (confidence.toLowerCase()) {
      case 'low':
      case 'l':
        return FireConfidence.low;
      case 'nominal':
      case 'n':
        return FireConfidence.nominal;
      case 'high':
      case 'h':
        return FireConfidence.high;
      default:
        return FireConfidence.unknown;
    }
  }

  // Get fire intensity based on brightness and FRP
  FireIntensity get intensity {
    if (frp != null) {
      if (frp! > 100) return FireIntensity.extreme;
      if (frp! > 50) return FireIntensity.high;
      if (frp! > 20) return FireIntensity.moderate;
      return FireIntensity.low;
    }
    
    if (brightness != null) {
      if (brightness! > 360) return FireIntensity.extreme;
      if (brightness! > 340) return FireIntensity.high;
      if (brightness! > 320) return FireIntensity.moderate;
      return FireIntensity.low;
    }
    
    return FireIntensity.unknown;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirmsFireData &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          acqDate == other.acqDate &&
          acqTime == other.acqTime &&
          satellite == other.satellite;

  @override
  int get hashCode =>
      latitude.hashCode ^
      longitude.hashCode ^
      acqDate.hashCode ^
      acqTime.hashCode ^
      satellite.hashCode;
}

enum FireConfidence { low, nominal, high, unknown }

enum FireIntensity { low, moderate, high, extreme, unknown }
