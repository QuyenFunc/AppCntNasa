import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class NtripStats {
  int frames = 0;
  int bytes = 0;
  final Map<int, int> msgCount = {};
  DateTime? firstTs, lastTs;
  
  double get bitrateKbps {
    if (firstTs == null || lastTs == null) return 0;
    final s = (lastTs!.difference(firstTs!).inMilliseconds) / 1000.0;
    return s <= 0 ? 0 : (bytes * 8.0) / 1000.0 / s;
  }
  
  String get summary {
    final msgTypes = msgCount.keys.toList()..sort();
    final msgSummary = msgTypes.take(5).map((type) => '$type: ${msgCount[type]}').join(', ');
    return 'Frames: $frames, Bytes: $bytes, Rate: ${bitrateKbps.toStringAsFixed(1)} kbps\nMessages: $msgSummary';
  }
}

class NtripClient {
  final String host;
  final int port;
  final String mountPoint;
  final String username;
  final String password;
  final bool useTls;

  Socket? _sock;
  StreamSubscription<Uint8List>? _sub;
  final stats = NtripStats();
  final _statsCtrl = StreamController<NtripStats>.broadcast();
  final _rawDataCtrl = StreamController<Uint8List>.broadcast();
  
  Stream<NtripStats> get statsStream => _statsCtrl.stream;
  Stream<Uint8List> get rawDataStream => _rawDataCtrl.stream;
  
  bool get isConnected => _sock != null;

  NtripClient({
    required this.host,
    required this.port,
    required this.mountPoint,
    required this.username,
    required this.password,
    this.useTls = false,
  });

  Future<void> connect({Duration timeout = const Duration(seconds: 8)}) async {
    try {
      _sock = useTls
          ? await SecureSocket.connect(host, port, timeout: timeout)
          : await Socket.connect(host, port, timeout: timeout);

      final auth = base64.encode(utf8.encode('$username:$password'));
      final req = StringBuffer()
        ..writeln('GET /$mountPoint HTTP/1.1')
        ..writeln('Host: $host')
        ..writeln('User-Agent: NTRIP Flutter/1.0')
        ..writeln('Ntrip-Version: Ntrip/2.0')
        ..writeln('Authorization: Basic $auth')
        ..writeln('Connection: close')
        ..writeln(); // kết thúc header bằng CRLF CRLF

      _sock!.add(utf8.encode(req.toString()));

      final headerBuf = BytesBuilder();
      bool headerDone = false;

      _sub = _sock!.listen(
        (chunk) {
          if (!headerDone) {
            headerBuf.add(chunk);
            final bytes = headerBuf.toBytes();
            final idx = _findHeaderEnd(bytes);
            if (idx != -1) {
              final header = utf8.decode(bytes.sublist(0, idx));
              print('NTRIP Response Header:\n$header');
              
              if (!header.contains('200') && !header.toUpperCase().contains('ICY')) {
                throw Exception('NTRIP handshake failed:\n$header');
              }
              
              headerDone = true;
              final rest = bytes.sublist(idx);
              if (rest.isNotEmpty) {
                _consumeRtcm(rest);
              }
              print('NTRIP connection established successfully');
            }
          } else {
            _consumeRtcm(chunk);
          }
        },
        onError: (error) {
          print('NTRIP connection error: $error');
          close();
        },
        onDone: () {
          print('NTRIP connection closed by server');
          close();
        },
      );
    } catch (e) {
      print('NTRIP connection failed: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    
    await _sock?.close();
    _sock = null;
    
    if (!_statsCtrl.isClosed) {
      await _statsCtrl.close();
    }
    if (!_rawDataCtrl.isClosed) {
      await _rawDataCtrl.close();
    }
    
    print('NTRIP client closed');
  }

  int _findHeaderEnd(Uint8List b) {
    for (int i = 3; i < b.length; i++) {
      if (b[i - 3] == 13 && b[i - 2] == 10 && b[i - 1] == 13 && b[i] == 10) {
        return i + 1;
      }
    }
    return -1;
  }

  void _consumeRtcm(Uint8List data) {
    stats.bytes += data.length;
    stats.lastTs = DateTime.now();
    stats.firstTs ??= stats.lastTs;

    // Emit raw data for further processing
    _rawDataCtrl.add(data);

    int i = 0;
    while (i < data.length) {
      if (data[i] != 0xD3) { 
        i++; 
        continue; 
      }
      if (i + 2 >= data.length) break;
      
      final len = ((data[i + 1] & 0x03) << 8) | data[i + 2];
      final frameLen = 3 + len + 3; // header + payload + CRC
      if (i + frameLen > data.length) break;

      final payload = data.sublist(i + 3, i + 3 + len);
      if (payload.length >= 2) {
        final msgType = ((payload[0] << 4) | (payload[1] >> 4)) & 0x0FFF;
        stats.msgCount[msgType] = (stats.msgCount[msgType] ?? 0) + 1;
      }
      stats.frames++;
      i += frameLen;
    }
    
    _statsCtrl.add(stats);
  }

  /// Get sourcetable from NTRIP caster
  static Future<String> getSourcetable({
    required String host,
    required int port,
    required String username,
    required String password,
    bool useTls = false,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    Socket sock;
    try {
      sock = useTls
          ? await SecureSocket.connect(host, port, timeout: timeout)
          : await Socket.connect(host, port, timeout: timeout);

      final auth = base64.encode(utf8.encode('$username:$password'));
      final req = StringBuffer()
        ..writeln('GET / HTTP/1.1')
        ..writeln('Host: $host')
        ..writeln('User-Agent: NTRIP Flutter/1.0')
        ..writeln('Ntrip-Version: Ntrip/2.0')
        ..writeln('Authorization: Basic $auth')
        ..writeln('Connection: close')
        ..writeln();

      sock.add(utf8.encode(req.toString()));

      final response = StringBuffer();
      await for (final chunk in sock) {
        response.write(utf8.decode(chunk));
      }

      await sock.close();
      return response.toString();
    } catch (e) {
      throw Exception('Failed to get sourcetable: $e');
    }
  }
}
