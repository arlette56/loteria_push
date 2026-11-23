'use strict';

function crearEnviadorConsola(log = console.log) {
  return {
    async enviar(mensaje) {
      log('[push simulado]', JSON.stringify(mensaje));
      return 'simulado';
    },
  };
}

function crearEnviadorFcm({ dryRun = false } = {}) {
  const admin = require('firebase-admin');
  admin.initializeApp();
  const messaging = admin.messaging();
  return {
    enviar: (mensaje) => messaging.send(mensaje, dryRun),
  };
}

function esDestinoMuerto(err) {
  const codigo = err && err.code;
  return (
    codigo === 'messaging/registration-token-not-registered' ||
    codigo === 'messaging/invalid-registration-token'
  );
}

module.exports = { crearEnviadorConsola, crearEnviadorFcm, esDestinoMuerto };
