// Relay de salas para I Want That Castle Now!
// Ruta: wss://<worker>/room/<CODIGO>?role=host|guest|spectator
// Una sala = un Durable Object con 1 anfitrión, 1 invitado y hasta
// MAX_SPECTATORS espectadores (solo miran).
// Los mensajes binarios del anfitrión se reenvían al invitado y a todos los
// espectadores; los del invitado, al anfitrión; los de un espectador se
// descartan (no pueden actuar). El relay no entiende el juego.
// Los mensajes de texto son avisos del relay al cliente:
//   {"t":"guest_joined"} {"t":"guest_left"} {"t":"host_left"}
//   {"t":"spectator_joined"} {"t":"spectator_left"}  (al anfitrión)

const CODE_RE = /^[A-Z0-9]{4,8}$/;
const MAX_SPECTATORS = 8;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const match = url.pathname.match(/^\/room\/([A-Za-z0-9]+)$/);
    if (!match) {
      return new Response("IWTCN relay OK", { status: 200 });
    }
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Se esperaba WebSocket", { status: 426 });
    }
    const code = match[1].toUpperCase();
    if (!CODE_RE.test(code)) {
      return new Response("Código inválido", { status: 400 });
    }
    const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
    return stub.fetch(request);
  },
};

export class Room {
  constructor(state) {
    this.state = state;
  }

  peer(role) {
    return this.state.getWebSockets(role)[0] ?? null;
  }

  async fetch(request) {
    const role = new URL(request.url).searchParams.get("role");
    if (role !== "host" && role !== "guest" && role !== "spectator") {
      return new Response("role inválido", { status: 400 });
    }
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    if (role === "host") {
      if (this.peer("host")) return this.reject(client, server, 4409, "Ese código ya está en uso");
    } else if (role === "spectator") {
      if (!this.peer("host")) return this.reject(client, server, 4404, "La sala no existe");
      if (this.state.getWebSockets("spectator").length >= MAX_SPECTATORS) {
        return this.reject(client, server, 4429, "La sala tiene demasiados espectadores");
      }
    } else {
      if (!this.peer("host")) return this.reject(client, server, 4404, "La sala no existe");
      const old = this.peer("guest");
      if (old) {
        // Reconexión: el socket anterior ya estaba muerto pero sin detectar.
        old.close(4410, "Sustituido por una nueva conexión");
      }
    }

    this.state.acceptWebSocket(server, [role]);
    if (role === "guest") this.notify(this.peer("host"), "guest_joined");
    if (role === "spectator") this.notify(this.peer("host"), "spectator_joined");
    return new Response(null, { status: 101, webSocket: client });
  }

  reject(client, server, code, reason) {
    server.accept();
    server.close(code, reason);
    return new Response(null, { status: 101, webSocket: client });
  }

  notify(ws, type) {
    if (ws) {
      try { ws.send(JSON.stringify({ t: type })); } catch (_) {}
    }
  }

  webSocketMessage(ws, message) {
    if (typeof message === "string") return; // ping de mantenimiento del cliente
    const role = this.state.getTags(ws)[0];
    if (role === "spectator") return; // los espectadores no pueden enviar nada
    const targets = role === "host"
      ? [this.peer("guest"), ...this.state.getWebSockets("spectator")]
      : [this.peer("host")];
    for (const target of targets) {
      if (!target) continue;
      try { target.send(message); } catch (_) {}
    }
  }

  webSocketClose(ws, code, reason) {
    this.onGone(ws);
    try { ws.close(code, reason); } catch (_) {}
  }

  webSocketError(ws) {
    this.onGone(ws);
  }

  onGone(ws) {
    const role = this.state.getTags(ws)[0];
    if (role === "host") {
      for (const viewer of [this.peer("guest"), ...this.state.getWebSockets("spectator")]) {
        this.notify(viewer, "host_left");
        if (viewer) try { viewer.close(4000, "El anfitrión se fue"); } catch (_) {}
      }
    } else if (role === "spectator") {
      this.notify(this.peer("host"), "spectator_left");
    } else if (role === "guest") {
      // Solo avisa si no es el guest que acaba de ser sustituido.
      if (!this.peer("guest") || this.peer("guest") === ws) {
        this.notify(this.peer("host"), "guest_left");
      }
    }
  }
}
