'use strict';
const PATRONES = [
  ['llena', Array.from({ length: 16 }, (_, i) => i)],
  ...[0, 4, 8, 12].map((s, i) => [`fila${i + 1}`, [s, s + 1, s + 2, s + 3]]),
  ...[0, 1, 2, 3].map((s, i) => [`columna${i + 1}`, [s, s + 4, s + 8, s + 12]]),
  ['diagonal1', [0, 5, 10, 15]],
  ['diagonal2', [3, 6, 9, 12]],
  ['esquinas', [0, 3, 12, 15]],
  ['centro', [5, 6, 9, 10]],
].map(([nombre, posiciones]) => Object.freeze({ nombre, posiciones }));

function patronesCompletos(tabla, cantadas) {
  return PATRONES.filter((p) => p.posiciones.every((pos) => cantadas.has(tabla[pos]))).map((p) => p.nombre);
}

function cartaQueFalta(tabla, cantadas) {
  if (patronesCompletos(tabla, cantadas).length > 0) return null;
  for (const p of PATRONES) {
    if (p.nombre === 'llena') continue;
    const faltan = p.posiciones.map((pos) => tabla[pos]).filter((id) => !cantadas.has(id));
    if (faltan.length === 1) return faltan[0];
  }
  return null;
}

function describirPatron(nombre) {
  if (nombre === 'llena') return 'la tabla llena';
  if (nombre === 'esquinas') return 'las cuatro esquinas';
  if (nombre === 'centro') return 'el centro';
  if (nombre.startsWith('diagonal')) return 'una diagonal';
  const m = /^(fila|columna)(\d)$/.exec(nombre);
  return m ? `la ${m[1]} ${m[2]}` : nombre;
}

module.exports = { PATRONES, patronesCompletos, cartaQueFalta, describirPatron };
