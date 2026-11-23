import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../dominio/api_juego.dart';
import '../dominio/puerto_push.dart';

class PushFcm implements PuertoPush {
  PushFcm({FirebaseMessaging? messaging}) : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  static MensajePush _mapear(RemoteMessage m) => MensajePush(
        datos: Map<String, Object?>.from(m.data),
        titulo: m.notification?.title,
        cuerpo: m.notification?.body,
      );

  static PermisoPush _mapearPermiso(AuthorizationStatus s) => switch (s) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => PermisoPush.concedido,
        AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => PermisoPush.denegado,
        AuthorizationStatus.notDetermined => PermisoPush.sinPreguntar,
      };

  @override
  Future<PermisoPush> estadoPermiso() async {
    final settings = await _messaging.getNotificationSettings();
    return _mapearPermiso(settings.authorizationStatus);
  }

  @override
  Future<PermisoPush> pedirPermiso() async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    return _mapearPermiso(settings.authorizationStatus);
  }

  @override
  Future<DestinoPush?> obtenerDestino() async {
    try {
      await _messaging.register();
    } catch (_) {}
    // ignore: deprecated_member_use
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return null;
    return DestinoPush('token', token);
  }

  @override
  Stream<DestinoPush> get destinoCambiado {
    final controller = StreamController<DestinoPush>.broadcast();
    try {
      final sub = _messaging.onRegistered.listen((_) async {
        // ignore: deprecated_member_use
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty && !controller.isClosed) {
          controller.add(DestinoPush('token', token));
        }
      });
      controller.onCancel = () => sub.cancel();
    } catch (_) {
      // ignore: deprecated_member_use
      final sub = _messaging.onTokenRefresh.listen((token) {
        if (token.isNotEmpty && !controller.isClosed) {
          controller.add(DestinoPush('token', token));
        }
      });
      controller.onCancel = () => sub.cancel();
    }
    return controller.stream;
  }

  @override
  Stream<MensajePush> get enPrimerPlano => FirebaseMessaging.onMessage.map(_mapear);

  @override
  Stream<MensajePush> get alAbrirDesdeNotificacion => FirebaseMessaging.onMessageOpenedApp.map(_mapear);

  @override
  Future<MensajePush?> mensajeInicial() async {
    final m = await _messaging.getInitialMessage();
    return m == null ? null : _mapear(m);
  }

  @override
  Future<void> suscribirTema(String tema) => _messaging.subscribeToTopic(tema);

  @override
  Future<void> desuscribirTema(String tema) => _messaging.unsubscribeFromTopic(tema);
}