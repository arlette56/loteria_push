import 'dart:async';

import 'package:flutter/foundation.dart';

import 'almacen.dart';
import 'api_juego.dart';
import 'evento.dart';
import 'partida.dart';
import 'puerto_push.dart';
import 'sesion.dart';

class ControladorJuego extends ChangeNotifier {
  ControladorJuego({required this.api, required this.push, required this.almacen}) {
    _subs.addAll([
      push.enPrimerPlano.listen(_alLlegarPush),
      push.alAbrirDesdeNotificacion.listen(_alLlegarPush),
      push.destinoCambiado.listen(_alCambiarDestino),
    ]);
  }

  static const _claveSesion = 'sesion';

  final ApiJuego api;
  final PuertoPush push;
  final Almacen almacen;
  final List<StreamSubscription<Object?>> _subs = [];

  Partida? _partida;
  Sesion? _sesion;
  String? _errorSincro;
  bool _sincronizando = false;

  Partida? get partida => _partida;
  String? get errorSincro => _errorSincro;
  bool get sincronizando => _sincronizando;

  Future<void> arrancar() async {
    final texto = await almacen.leerTexto(_claveSesion);
    final sesion = Sesion.desdeTexto(texto);
    if (sesion == null) return;
    await _activar(sesion, suscribir: true);
    await sincronizar();
    final inicial = await push.mensajeInicial();
    if (inicial != null) await _alLlegarPush(inicial);
  }

  Future<void> unirse({required String sala, required String nombre}) async {
    final codigo = sala.trim().toUpperCase();
    final destino = await _prepararPush();
    final union = await api.unirse(codigo, nombre.trim(), destino);
    final sesion = Sesion(sala: codigo, nombre: union.nombre, tabla: union.tabla, claveJugador: union.claveJugador);
    await almacen.guardarTexto(_claveSesion, sesion.aTexto());
    await _activar(sesion, suscribir: destino != null);
    _partida!.aplicarLote(union.cartas);
    notifyListeners();
  }

  Future<DestinoPush?> _prepararPush() async {
    var estado = await push.estadoPermiso();
    if (estado == PermisoPush.sinPreguntar) estado = await push.pedirPermiso();
    if (estado != PermisoPush.concedido) return null;
    return push.obtenerDestino();
  }

  Future<void> _activar(Sesion sesion, {required bool suscribir}) async {
    _sesion = sesion;
    _partida = Partida(sala: sesion.sala, nombre: sesion.nombre, tabla: sesion.tabla);
    _errorSincro = null;
    if (suscribir) await push.suscribirTema('sala_${sesion.sala}');
    notifyListeners();
  }

  Future<void> _alLlegarPush(MensajePush msg) async {
    final p = _partida;
    if (p == null) return;
    final salaMsg = EventoJuego.salaDe(msg.datos);
    if (salaMsg != null && salaMsg != p.sala) return;
    final ev = EventoJuego.desdeDatos(msg.datos);
    if (ev == null) return;

    final res = p.aplicar(ev);
    if (res == ResultadoAplicar.duplicado) return;
    if (res == ResultadoAplicar.hueco) {
      await sincronizar();
      return;
    }
    notifyListeners();
  }

  Future<void> sincronizar() async {
    final p = _partida;
    if (p == null || _sincronizando) return;
    _sincronizando = true;
    _errorSincro = null;
    notifyListeners();
    try {
      final desde = p.ultima;
      final est = await api.estado(p.sala, desde);
      p.aplicarLote(est.cartas);
      if (est.ganador != null && est.patron != null) {
        p.aplicar(LoteriaCantada(n: est.ultima, ganador: est.ganador!, patron: est.patron!));
      }
    } catch (e) {
      _errorSincro = '$e';
    } finally {
      _sincronizando = false;
      notifyListeners();
    }
  }

  Future<bool> cantarLoteria() async {
    final p = _partida;
    final s = _sesion;
    if (p == null || s == null) return false;
    final res = await api.reclamar(p.sala, s.nombre, s.claveJugador);
    if (res.gano && res.patron != null) {
      p.aplicar(LoteriaCantada(n: p.ultima, ganador: s.nombre, patron: res.patron!));
      notifyListeners();
    }
    return res.gano;
  }

  Future<void> salir() async {
    final p = _partida;
    if (p != null) await push.desuscribirTema('sala_${p.sala}');
    _partida = null;
    _sesion = null;
    _errorSincro = null;
    await almacen.borrar(_claveSesion);
    notifyListeners();
  }

  Future<void> _alCambiarDestino(DestinoPush nuevo) async {
    final s = _sesion;
    if (s == null) return;
    await api.actualizarDestino(s.sala, s.nombre, s.claveJugador, nuevo);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}
