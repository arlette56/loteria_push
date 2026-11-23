import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'dominio/cartas.dart';
import 'dominio/controlador.dart';
import 'firebase_options.dart';
import 'infra/almacen_prefs.dart';
import 'infra/api_http.dart';
import 'infra/push_fcm.dart';

const String kUrlServidor = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final controlador = ControladorJuego(
    api: ApiHttp(baseUrl: kUrlServidor),
    push: PushFcm(),
    almacen: AlmacenPrefs(),
  );
  await controlador.arrancar();

  runApp(LoteriaApp(controlador: controlador));
}

class LoteriaApp extends StatelessWidget {
  const LoteriaApp({super.key, required this.controlador});

  final ControladorJuego controlador;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lotería Push',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF191970),
        useMaterial3: true,
      ),
      home: PantallaJuego(controlador: controlador),
    );
  }
}

class PantallaJuego extends StatefulWidget {
  const PantallaJuego({super.key, required this.controlador});

  final ControladorJuego controlador;

  @override
  State<PantallaJuego> createState() => _PantallaJuegoState();
}

class _PantallaJuegoState extends State<PantallaJuego> {
  final _salaCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  bool _uniendo = false;
  bool _creando = false;
  String? _mensaje;
  String? _claveCantorCreada;

  @override
  void dispose() {
    _salaCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _crearSala() async {
    setState(() {
      _creando = true;
      _mensaje = null;
    });
    try {
      final creada = await widget.controlador.api.crearSala();
      if (!mounted) return;
      _salaCtrl.text = creada.id;
      setState(() {
        _claveCantorCreada = creada.claveCantor;
        _mensaje = 'Sala ${creada.id} creada.';
      });
      if (_nombreCtrl.text.trim().isNotEmpty) {
        await _unirse();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _mensaje = '$e');
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  Future<void> _unirse() async {
    final nombre = _nombreCtrl.text.trim();
    final sala = _salaCtrl.text.trim().toUpperCase();
    if (nombre.isEmpty || sala.isEmpty) {
      setState(() => _mensaje = 'Escribe tu nombre y código de sala.');
      return;
    }
    setState(() {
      _uniendo = true;
      _mensaje = null;
    });
    try {
      await widget.controlador.unirse(sala: sala, nombre: nombre);
    } catch (e) {
      setState(() => _mensaje = '$e');
    } finally {
      if (mounted) setState(() => _uniendo = false);
    }
  }

  Future<void> _loteria() async {
    try {
      final gano = await widget.controlador.cantarLoteria();
      if (!mounted) return;
      setState(() => _mensaje = gano ? '¡Lotería válida!' : 'Aún no completas un patrón.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _mensaje = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controlador,
      builder: (context, _) {
        final partida = widget.controlador.partida;
        return Scaffold(
          appBar: AppBar(
            title: Text(partida == null ? 'Lotería Push' : 'Sala ${partida.sala} — ${partida.nombre}'),
            actions: [
              if (partida != null)
                IconButton(
                  tooltip: 'Sincronizar',
                  onPressed: widget.controlador.sincronizar,
                  icon: const Icon(Icons.sync),
                ),
              if (partida != null)
                IconButton(
                  tooltip: 'Salir',
                  onPressed: widget.controlador.salir,
                  icon: const Icon(Icons.logout),
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: partida == null ? _vistaIngreso() : _vistaTablero(),
          ),
        );
      },
    );
  }

  Widget _vistaIngreso() {
    final ocupado = _uniendo || _creando;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nombreCtrl,
          decoration: const InputDecoration(labelText: 'Tu nombre', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _salaCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Código de sala', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: ocupado ? null : _unirse,
          child: Text(_uniendo ? 'Entrando...' : 'Entrar a la sala'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: ocupado ? null : _crearSala,
          icon: const Icon(Icons.add),
          label: Text(_creando ? 'Creando sala...' : 'Crear sala nueva'),
        ),
        if (_claveCantorCreada != null) ...[
          const SizedBox(height: 12),
          SelectableText(
            'Clave cantor (${_salaCtrl.text}): $_claveCantorCreada',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
        if (_mensaje != null) ...[
          const SizedBox(height: 12),
          Text(
            _mensaje!,
            style: TextStyle(color: _mensaje!.startsWith('Sala ') ? Colors.green : Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _vistaTablero() {
    final p = widget.controlador.partida!;
    final ultima = p.ultimaCarta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              ultima == null
                  ? 'Esperando la primera carta...'
                  : 'Carta #${ultima.n}: ${ultima.nombre} — ${ultima.pista}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        if (widget.controlador.errorSincro != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Aviso: ${widget.controlador.errorSincro}', style: const TextStyle(color: Colors.orange)),
          ),
        if (p.ganador != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Ganador: ${p.ganador} (${p.patronGanador})', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            itemCount: p.tabla.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final id = p.tabla[index];
              final marcada = p.estaMarcada(id);
              return Container(
                decoration: BoxDecoration(
                  color: marcada ? const Color(0xFF191970) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF191970)),
                ),
                padding: const EdgeInsets.all(6),
                child: Center(
                  child: Text(
                    nombreDeCarta(id),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: marcada ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_mensaje != null) ...[
          const SizedBox(height: 8),
          Text(_mensaje!, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 8),
        FilledButton(
          onPressed: p.puedeCantarLoteria ? _loteria : null,
          child: const Text('¡LOTERÍA!'),
        ),
      ],
    );
  }
}