import 'dart:convert';

import 'package:http/http.dart' as http;

import '../dominio/api_juego.dart';
import '../dominio/evento.dart';

class ApiHttp implements ApiJuego {
  ApiHttp({required this.baseUrl, http.Client? cliente}) : _client = cliente ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Uri _uri(String ruta, [Map<String, String>? query]) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse("$base$ruta").replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _post(String ruta, Map<String, Object?> cuerpo, {Map<String, String>? headers}) async {
    final resp = await _client.post(
      _uri(ruta),
      headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
      body: jsonEncode(cuerpo),
    );
    return _decodificar(resp);
  }

  Future<Map<String, dynamic>> _put(String ruta, Map<String, Object?> cuerpo, {Map<String, String>? headers}) async {
    final resp = await _client.put(
      _uri(ruta),
      headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
      body: jsonEncode(cuerpo),
    );
    return _decodificar(resp);
  }

  Future<Map<String, dynamic>> _get(String ruta, {Map<String, String>? query}) async {
    final resp = await _client.get(_uri(ruta, query));
    return _decodificar(resp);
  }

  Map<String, dynamic> _decodificar(http.Response resp) {
    final texto = resp.body.isEmpty ? '{}' : resp.body;
    final data = jsonDecode(texto);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    }
    if (data is Map<String, dynamic>) {
      throw ErrorApi(
        data['error']?.toString() ?? 'HTTP_"${resp.statusCode}"',
        data['mensaje']?.toString() ?? 'Error de servidor',
      );
    }
    throw ErrorApi('HTTP_"${resp.statusCode}"', 'Error de servidor');
  }

  @override
  Future<SalaCreada> crearSala() async {
    final j = await _post('/salas', const {});
    return SalaCreada(j['id'] as String, j['claveCantor'] as String);
  }

  @override
  Future<Union> unirse(String sala, String nombre, DestinoPush? destino) async {
    final j = await _post('/salas/$sala/unirse', {
      'nombre': nombre,
      if (destino != null) 'destino': destino.toJson(),
    });
    final tabla = (j['tabla'] as List).map((e) => e as int).toList();
    final cartas = (j['cartas'] as List? ?? const [])
        .map((e) => CartaCantada.desdeJson(e as Map<String, dynamic>))
        .toList();
    return Union(
      nombre: j['nombre'] as String,
      tabla: tabla,
      claveJugador: j['claveJugador'] as String,
      cartas: cartas,
    );
  }

  @override
  Future<EstadoSala> estado(String sala, int desde) async {
    final j = await _get('/salas/$sala/estado', query: {'desde': '$desde'});
    final cartas = (j['cartas'] as List? ?? const [])
        .map((e) => CartaCantada.desdeJson(e as Map<String, dynamic>))
        .toList();
    return EstadoSala(
      ultima: j['ultima'] as int? ?? 0,
      cartas: cartas,
      ganador: j['ganador'] as String?,
      patron: j['patron'] as String?,
    );
  }

  @override
  Future<CartaCantada> cantar(String sala, String claveCantor) async {
    final j = await _post('/salas/$sala/cantar', const {}, headers: {'x-cantor-clave': claveCantor});
    return CartaCantada.desdeJson(j['evento'] as Map<String, dynamic>);
  }

  @override
  Future<ResultadoReclamo> reclamar(String sala, String nombre, String claveJugador) async {
    final j = await _post(
      '/salas/$sala/loteria',
      {'nombre': nombre},
      headers: {'x-jugador-clave': claveJugador},
    );
    return ResultadoReclamo(gano: j['gano'] as bool? ?? false, patron: j['patron'] as String?);
  }

  @override
  Future<void> actualizarDestino(String sala, String nombre, String claveJugador, DestinoPush destino) async {
    await _put(
      '/salas/$sala/destino',
      {'nombre': nombre, 'destino': destino.toJson()},
      headers: {'x-jugador-clave': claveJugador},
    );
  }
}
