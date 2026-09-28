// Relay de salas para I Want That Castle Now!
// Ruta: wss://<worker>/room/<CODIGO>?role=host|guest
// Una sala = un Durable Object con como mucho 1 anfitrión y 1 invitado.
// Los mensajes binarios se reenvían tal cual al otro extremo (el relay no
// entiende el juego). Los mensajes de texto son avisos del relay al cliente:
//   {"t":"guest_joined"} {"t":"guest_left"} {"t":"host_left"}

const CODE_RE = /^[A-Z0-9]{4,8}$/;

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
    if (role !== "host" && role !== "guest") {
      return new Response("role inválido", { status: 400 });
    }
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    if (role === "host") {
      if (this.peer("host")) return this.reject(client, server, 4409, "Ese código ya está en uso");
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
    const target = this.peer(role === "host" ? "guest" : "host");
    if (target) {
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
      const guest = this.peer("guest");
      this.notify(guest, "host_left");
      if (guest) try { guest.close(4000, "El anfitrión se fue"); } catch (_) {}
    } else if (role === "guest") {
      // Solo avisa si no es el guest que acaba de ser sustituido.
      if (!this.peer("guest") || this.peer("guest") === ws) {
        this.notify(this.peer("host"), "guest_left");
      }
    }
  }
}
