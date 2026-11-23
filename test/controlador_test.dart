import 'package:flutter_test/flutter_test.dart';
import 'package:loteria_push/dominio/almacen.dart';
import 'package:loteria_push/dominio/api_juego.dart';
import 'package:loteria_push/dominio/controlador.dart';
import 'package:loteria_push/dominio/puerto_push.dart';
import 'package:loteria_push/dominio/sesion.dart';

import 'falsos.dart';

void main() {
  late ApiFalsa api;
  late PuertoPushFalso push;
  late Almacen almacen;
  late ControladorJuego c;

  setUp(() {
    api = ApiFalsa();
    push = PuertoPushFalso();
    almacen = AlmacenMemoria();
    c = ControladorJuego(api: api, push: push, almacen: almacen);
  });

  tearDown(() => c.dispose());

  test('unirse pide permiso si hace falta, guarda sesión y se suscribe al tema de la sala', () async {
    await c.unirse(sala: 'abcde', nombre: 'Ana');
    expect(push.vecesPidioPermiso, 1);
    expect(push.temas, {'sala_ABCDE'});
    expect(c.partida!.nombre, 'Ana');
    expect(Sesion.desdeTexto(await almacen.leerTexto('sesion'))?.sala, 'ABCDE');
    expect(api.destinoAlUnirse?.valor, 'token-del-telefono-xxxxxxxxxx');
  });

  test('si el usuario niega el permiso, igual puede jugar sin push', () async {
    push.respuestaDelUsuario = PermisoPush.denegado;
    await c.unirse(sala: 'ABCDE', nombre: 'Ana');
    expect(c.partida, isNotNull);
    expect(api.destinoAlUnirse, isNull);
    expect(push.temas, isEmpty);
  });

  test('llega una carta por push en orden: se marca y notifica a la pantalla', () async {
    await c.unirse(sala: 'ABCDE', nombre: 'Ana');
    var avisos = 0;
    c.addListener(() => avisos++);
    push.emitirEnPrimerPlano(mensajeCarta(1, 5));
    await Future<void>.delayed(Duration.zero);
    expect(c.partida!.ultima, 1);
    expect(c.partida!.estaMarcada(5), isTrue);
    expect(avisos, 1);
  });

  test('llega un push con HUECO (se perdió la carta 2): pide al servidor las que faltan', () async {
    await c.unirse(sala: 'ABCDE', nombre: 'Ana');
    api.cartasServidor.addAll([carta(1, 1), carta(2, 2), carta(3, 3)]);
    push.emitirEnPrimerPlano(mensajeCarta(3, 3));
    await Future<void>.delayed(Duration.zero);
    expect(api.llamadasEstado, 1);
    expect(api.ultimoDesde, 0);
    expect(c.partida!.ultima, 3);
  });

  test('llega un push DUPLICADO: no consulta al servidor ni avisa de más', () async {
    await c.unirse(sala: 'ABCDE', nombre: 'Ana');
    push.emitirEnPrimerPlano(mensajeCarta(1, 1));
    await Future<void>.delayed(Duration.zero);
    var avisos = 0;
    c.addListener(() => avisos++);
    push.emitirEnPrimerPlano(mensajeCarta(1, 1));
    await Future<void>.delayed(Duration.zero);
    expect(api.llamadasEstado, 0);
    expect(avisos, 0);
  });

  test('si el servidor falla al cerrar un hueco, no revienta: queda la aviso para reintentar', () async {
    await c.unirse(sala: 'ABCDE', nombre: 'Ana');
    api.errorEnEstado = const ErrorApi('RED', 'sin conexión');
    push.emitirEnPrimerPlano(mensajeCarta(2, 2));
    await Future<void>.delayed(Duration.zero);
    expect(c.partida!.ultima, 0);
    expect(c.errorSincro, isNotNull);
  });

  test('al abrir la app desde una notificación, sincroniza desde su última carta', () async {
    await c.unirse(sala: 'ABCDE', nombre: 'Ana');
    api.cartasServidor.addAll([carta(1, 1), carta(2, 2)]);
    push.emitirEnPrimerPlano(mensajeCarta(1, 1));
    await Future<void>.delayed(Duration.zero);

    api.cartasServidor.add(carta(3, 3));
    push.emitirAperturaDesdeNotificacion(mensajeCarta(3, 3));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(api.ultimoDesde, 1);
    expect(c.partida!.ultima, 3);
  });

  test('arrancar con sesión guardada restaura partida y se pone al día', () async {
    final previa = Sesion(sala: 'ABCDE', nombre: 'Ana', tabla: List.generate(16, (i) => i + 1), claveJugador: 'k1');
    await almacen.guardarTexto('sesion', previa.aTexto());
    api.cartasServidor.addAll([carta(1, 1), carta(2, 2)]);

    await c.arrancar();
    expect(c.partida!.nombre, 'Ana');
    expect(c.partida!.ultima, 2);
    expect(push.temas, {'sala_ABCDE'});
  });

  test('cantar Lotería envía el reclamo al servidor y guarda el resultado', () async {
    await c.unirse(sala: 'ABCDE', nombre: 'Ana');
    api.reclamoGana = true;
    final ok = await c.cantarLoteria();
    expect(ok, isTrue);
    expect(c.partida!.ganador, 'Ana');
  });

  test('salir limpia la sesión, borra el almacenamiento y se desuscribe del tema', () async {
    await c.unirse(sala: 'ABCDE', nombre: 'Ana');
    await c.salir();
    expect(c.partida, isNull);
    expect(await almacen.leerTexto('sesion'), isNull);
    expect(push.temas, isEmpty);
  });

  test('si FCM rota el token mientras jugamos, se actualiza en el servidor', () async {
    await c.unirse(sala: 'ABCDE', nombre: 'Ana');
    push.emitirNuevoDestino(const DestinoPush('token', 'token-nuevo-xxxxxxxxxxxx'));
    await Future<void>.delayed(Duration.zero);
    expect(api.destinosActualizados.single.valor, 'token-nuevo-xxxxxxxxxxxx');
  });
}
