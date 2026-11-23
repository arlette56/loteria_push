'use strict';
const { describirPatron } = require('./lineas');

const LIMITE_BYTES = 4096;

const TTL_CARTA_MS = 60 * 1000;
const TTL_CASI_MS = 5 * 60 * 1000;
const TTL_FIN_MS = 60 * 60 * 1000;

function aTexto(datos) {
  return Object.fromEntries(Object.entries(datos).map(([k, v]) => [k, String(v)]));
}

function tema(sala) {
  return `sala_${sala}`;
}

function comprobarTamano(mensaje) {
  const bytes = Buffer.byteLength(JSON.stringify(mensaje), 'utf8');
  if (bytes > LIMITE_BYTES) throw new Error(`Mensaje de ${bytes} bytes excede ${LIMITE_BYTES}`);
  return mensaje;
}

function caduca(ahoraMs, ttlMs) {
  return String(Math.floor((ahoraMs + ttlMs) / 1000));
}

function mensajeCarta(ev, ahoraMs) {
  const colapso = `carta_${ev.sala}`;
  return comprobarTamano({
    topic: tema(ev.sala),
    notification: { title: `🃏 ${ev.nombre}`, body: ev.pista },
    data: aTexto({ tipo: 'carta', sala: ev.sala, n: ev.n, cartaId: ev.cartaId, nombre: ev.nombre, pista: ev.pista }),
    android: {
      priority: 'high',
      ttl: TTL_CARTA_MS,
      collapseKey: colapso,
      notification: { channelId: 'cartas', tag: colapso },
    },
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-collapse-id': colapso,
        'apns-expiration': caduca(ahoraMs, TTL_CARTA_MS),
      },
      payload: { aps: { sound: 'default', 'thread-id': tema(ev.sala) } },
    },
  });
}

function mensajeCasi(ev, ahoraMs) {
  const colapso = `casi_${ev.sala}`;
  return comprobarTamano({
    notification: { title: '¡Casi! 😮', body: 'Estás a UNA carta de cantar Lotería. ¡Atento!' },
    data: aTexto({ tipo: 'casi', sala: ev.sala, n: ev.n, cartaId: ev.cartaId }),
    android: {
      priority: 'high',
      ttl: TTL_CASI_MS,
      collapseKey: colapso,
      notification: { channelId: 'momentos', tag: colapso },
    },
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-collapse-id': colapso,
        'apns-expiration': caduca(ahoraMs, TTL_CASI_MS),
      },
      payload: { aps: { sound: 'default', 'thread-id': tema(ev.sala) } },
    },
  });
}

function mensajeLoteria(ev, ahoraMs) {
  const colapso = `fin_${ev.sala}`;
  return comprobarTamano({
    topic: tema(ev.sala),
    notification: { title: '🎉 ¡LOTERÍA!', body: `${ev.ganador} ganó con ${describirPatron(ev.patron)}. ¡Felicidades!` },
    data: aTexto({ tipo: 'loteria', sala: ev.sala, n: ev.n, ganador: ev.ganador, patron: ev.patron }),
    android: {
      priority: 'high',
      ttl: TTL_FIN_MS,
      collapseKey: colapso,
      notification: { channelId: 'momentos', tag: colapso },
    },
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-collapse-id': colapso,
        'apns-expiration': caduca(ahoraMs, TTL_FIN_MS),
      },
      payload: { aps: { sound: 'default', 'thread-id': tema(ev.sala) } },
    },
  });
}

function haciaDestino(mensaje, destino) {
  const base = { ...mensaje };
  delete base.topic;
  if (destino.tipo === 'fid') return { ...base, fid: destino.valor };
  return { ...base, token: destino.valor };
}

module.exports = {
  tema, aTexto, mensajeCarta, mensajeCasi, mensajeLoteria, haciaDestino,
  TTL_CARTA_MS, TTL_CASI_MS, TTL_FIN_MS, LIMITE_BYTES,
};
