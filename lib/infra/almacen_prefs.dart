import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/almacen.dart';

class AlmacenPrefs implements Almacen {
  AlmacenPrefs({Future<SharedPreferences>? prefs}) : _prefs = prefs ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefs;

  @override
  Future<String?> leerTexto(String clave) async {
    final p = await _prefs;
    return p.getString(clave);
  }

  @override
  Future<void> guardarTexto(String clave, String valor) async {
    final p = await _prefs;
    await p.setString(clave, valor);
  }

  @override
  Future<void> borrar(String clave) async {
    final p = await _prefs;
    await p.remove(clave);
  }
}
