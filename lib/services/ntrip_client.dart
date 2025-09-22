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

      // Build request headers
      String req = 'GET /$mountPoint HTTP/1.1\r\n'
          'Host: $host\r\n'
          'User-Agent: NTRIP Flutter/1.0\r\n'
          'Ntrip-Version: Ntrip/2.0\r\n';
      
      // Only add authorization if credentials are provided
      if (username.isNotEmpty && password.isNotEmpty) {
        final auth = base64.encode(utf8.encode('$username:$password'));
        req += 'Authorization: Basic $auth\r\n';
      }
      
      req += 'Connection: close\r\n'
          '\r\n'; // End headers with CRLF CRLF

      print('NTRIP Request:\n$req');
      _sock!.add(utf8.encode(req));

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

              final up = header.toUpperCase();
              if (!(up.contains(' 200 ') || up.startsWith('ICY 200'))) {
                // Handle 401 Unauthorized specifically
                if (up.contains('401')) {
                  _safeAddError('401 Unauthorized: Check NTRIP username/password and mountpoint access permissions');
                } else {
                  _safeAddError('NTRIP handshake failed: $header');
                }
                _closeInternal();
                return;
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
          _safeAddError('NTRIP socket error: $error');
          _closeInternal();
        },
        onDone: () {
          print('NTRIP connection closed by server');
          _closeInternal();
        },
      );
    } catch (e) {
      _safeAddError('NTRIP connection failed: $e');
      rethrow;
    }
  }

  // Safe error handling to avoid exceptions during error reporting
  void _safeAddError(String msg) {
    try { 
      if (!_statsCtrl.isClosed) {
        _statsCtrl.addError(Exception(msg)); 
      }
    } catch (_) {
      print('Error reporting failed: $msg');
    }
  }

  // Clean internal close without exceptions
  Future<void> _closeInternal() async {
    try {
      await _sub?.cancel();
      _sub = null;
      await _sock?.close();
      _sock = null;
      print('NTRIP client closed');
    } catch (e) {
      print('Error during close: $e');
    }
  }

  Future<void> close() async {
    await _closeInternal();
    
    if (!_statsCtrl.isClosed) {
      await _statsCtrl.close();
    }
    if (!_rawDataCtrl.isClosed) {
      await _rawDataCtrl.close();
    }
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

      // Build request headers
      String req = 'GET / HTTP/1.1\r\n'
          'Host: $host\r\n'
          'User-Agent: NTRIP Flutter/1.0\r\n'
          'Ntrip-Version: Ntrip/2.0\r\n';
      
      // Only add authorization if credentials are provided
      if (username.isNotEmpty && password.isNotEmpty) {
        final auth = base64.encode(utf8.encode('$username:$password'));
        req += 'Authorization: Basic $auth\r\n';
      }
      
      req += 'Connection: close\r\n'
          '\r\n';

      sock.add(utf8.encode(req));

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
