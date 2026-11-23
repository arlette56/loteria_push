import 'api_juego.dart';

enum PermisoPush { sinPreguntar, concedido, denegado }

class MensajePush {
  const MensajePush({required this.datos, this.titulo, this.cuerpo});
  final Map<String, Object?> datos;
  final String? titulo;
  final String? cuerpo;
}

abstract class PuertoPush {
  Future<PermisoPush> estadoPermiso();
  Future<PermisoPush> pedirPermiso();
  Future<DestinoPush?> obtenerDestino();
  Stream<DestinoPush> get destinoCambiado;
  Stream<MensajePush> get enPrimerPlano;
  Stream<MensajePush> get alAbrirDesdeNotificacion;
  Future<MensajePush?> mensajeInicial();
  Future<void> suscribirTema(String tema);
  Future<void> desuscribirTema(String tema);
}
