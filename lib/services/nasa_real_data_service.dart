import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/gnss_station.dart';

class NasaRealDataService {
  static final NasaRealDataService _instance = NasaRealDataService._internal();
  factory NasaRealDataService() => _instance;
  NasaRealDataService._internal();

  // NASA Real APIs - these require authentication
  static const String gnssStationUrl = 'https://cddis.nasa.gov/archive/gnss/data';
  static const String igsNetworkUrl = 'https://www.igs.org/network';
  static const String ntripSourceUrl = 'https://caster.cddis.eosdis.nasa.gov/sourcetable.txt';

  // Fetch real-time GNSS data from NASA APIs
  Future<List<GnssStation>> fetchRealTimeData() async {
    debugPrint('Attempting to fetch real GNSS data from NASA CDDIS...');
    
    try {
      // Try to fetch from NTRIP sourcetable first
      final stations = await _fetchFromNtripSource();
      if (stations.isNotEmpty) {
        return stations;
      }
      
      // Try IGS network data
      final igsStations = await _fetchFromIgsNetwork();
      if (igsStations.isNotEmpty) {
        return igsStations;
      }
      
      throw Exception('No real GNSS station data available from NASA sources');
      
    } catch (e) {
      debugPrint('Error fetching real-time data: $e');
      rethrow;
    }
  }

  // Fetch stations from NTRIP sourcetable
  Future<List<GnssStation>> _fetchFromNtripSource() async {
    try {
      final response = await http.get(
        Uri.parse(ntripSourceUrl),
        headers: {'User-Agent': 'NASA_GNSS_Client/1.0'},
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return _parseNtripSourcetable(response.body);
      } else {
        throw Exception('NTRIP sourcetable request failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching NTRIP sourcetable: $e');
      rethrow;
    }
  }
  
  // Fetch stations from IGS network
  Future<List<GnssStation>> _fetchFromIgsNetwork() async {
    try {
      final response = await http.get(
        Uri.parse(igsNetworkUrl),
        headers: {'User-Agent': 'NASA_GNSS_Client/1.0'},
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return _parseIgsNetworkData(response.body);
      } else {
        throw Exception('IGS network request failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching IGS network data: $e');
      rethrow;
    }
  }
  
  // Parse NTRIP sourcetable format
  List<GnssStation> _parseNtripSourcetable(String data) {
    final stations = <GnssStation>[];
    final lines = data.split('\n');
    
    for (final line in lines) {
      if (line.startsWith('STR;')) {
        try {
          final parts = line.split(';');
          if (parts.length >= 10) {
            final mountpoint = parts[1];
            final name = parts[2];
            final lat = double.tryParse(parts[9]) ?? 0.0;
            final lon = double.tryParse(parts[10]) ?? 0.0;
            
            if (lat != 0.0 && lon != 0.0) {
              stations.add(GnssStation(
                id: mountpoint,
                name: name.isNotEmpty ? name : 'GNSS Station $mountpoint',
                latitude: lat,
                longitude: lon,
                accuracy: 1.0, // Default accuracy
                updatedAt: DateTime.now(),
                status: 'active',
              ));
            }
          }
        } catch (e) {
          debugPrint('Error parsing sourcetable line: $e');
        }
      }
    }
    
    debugPrint('Parsed ${stations.length} stations from NTRIP sourcetable');
    return stations;
  }
  
  // Parse IGS network data (simplified - real implementation would be more complex)
  List<GnssStation> _parseIgsNetworkData(String data) {
    final stations = <GnssStation>[];
    
    try {
      // This would need to parse actual IGS network format
      // For now, return empty list since we need authentication
      debugPrint('IGS network parsing not implemented - requires authentication');
    } catch (e) {
      debugPrint('Error parsing IGS data: $e');
    }
    
    return stations;
  }

}
