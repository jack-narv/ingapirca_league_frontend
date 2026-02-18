import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants/environments.dart';
import 'auth_service.dart';

class LiveMatchSocketService {
  LiveMatchSocketService({
    required this.authService,
  });

  final AuthService authService;
  IO.Socket? _socket;

  final _connectedCtrl = StreamController<bool>.broadcast();
  Stream<bool> get connected$ => _connectedCtrl.stream;

  final _matchStartedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get matchStarted$ => _matchStartedCtrl.stream;

  final _scoreCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get score$ => _scoreCtrl.stream;

  final _eventCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get event$ => _eventCtrl.stream;

  final _finishedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get finished$ => _finishedCtrl.stream;

  bool get isConnected => _socket?.connected == true;

  Future<void> connect() async {
    if (_socket != null) return;

    final token = await authService.getToken();

    _socket = IO.io(
      Environment.baseUrl, // ex: http://192.168.1.3:3000
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          // if you want auth in socket handshake (optional)
          .setExtraHeaders({
            if (token != null) 'Authorization': 'Bearer $token',
          })
          .build(),
    );

    _socket!.onConnect((_) {
      _connectedCtrl.add(true);
    });

    _socket!.onDisconnect((_) {
      _connectedCtrl.add(false);
    });

    // ---- Events from backend ----

    // In case you still have the typo in backend, listen to both:
    _socket!.on('match_started', (data) {
      if (data is Map) _matchStartedCtrl.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('mathc_started', (data) {
      if (data is Map) _matchStartedCtrl.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('score_updated', (data) {
      if (data is Map) _scoreCtrl.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('match_event', (data) {
      if (data is Map) _eventCtrl.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('match_finished', (data) {
      if (data is Map) _finishedCtrl.add(Map<String, dynamic>.from(data));
    });

    _socket!.connect();
  }

  void joinMatch(String matchId) {
    _socket?.emit('joinMatch', matchId);
  }

  void leaveMatch(String matchId) {
    _socket?.emit('leaveMatch', matchId);
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    _connectedCtrl.close();
    _matchStartedCtrl.close();
    _scoreCtrl.close();
    _eventCtrl.close();
    _finishedCtrl.close();
  }
}
