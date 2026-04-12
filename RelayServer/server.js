const WebSocket = require('ws');
const http = require('http');

const PORT = process.env.PORT || 3900;
const server = http.createServer((req, res) => {
    res.writeHead(200);
    res.end("GUPT Relay Server is running!\n");
});

const wss = new WebSocket.Server({ server });

// Room structured as: { hostSocket, clientSocket }
const rooms = new Map();

function heartbeat() {
    this.isAlive = true;
}

const interval = setInterval(function ping() {
    wss.clients.forEach(function each(ws) {
        if (ws.isAlive === false) {
            console.log("[-] Disconnecting stale WebSocket");
            return ws.terminate();
        }
        ws.isAlive = false;
        ws.ping();
    });
}, 5000);

wss.on('close', function close() {
    clearInterval(interval);
});

wss.on('connection', (ws, req) => {
    ws.isAlive = true;
    ws.on('pong', heartbeat);
    
    // Expected paths: /host/[roomCode] or /client/[roomCode]
    const path = req.url;
    console.log(`[+] New connection attempt: ${path}`);
    
    const parts = path.split('/').filter(p => p.length > 0);
    if (parts.length !== 2) {
        console.error("[-] Invalid path. Must be /host/CODE or /client/CODE");
        ws.close(1008, "Invalid path");
        return;
    }

    const type = parts[0]; // "host" or "client"
    const roomCode = parts[1];

    if (!rooms.has(roomCode)) {
        rooms.set(roomCode, { host: null, client: null });
    }
    const room = rooms.get(roomCode);

    if (type === 'host') {
        if (room.host) {
            console.warn(`[!] Host already exists for room ${roomCode}. Replacing...`);
            room.host.close();
        }
        room.host = ws;
        console.log(`[HOST] Connected to room ${roomCode}`);
    } else if (type === 'client') {
        if (room.client) {
            console.warn(`[!] Client already exists for room ${roomCode}. Replacing...`);
            room.client.close();
        }
        room.client = ws;
        console.log(`[CLIENT] Connected to room ${roomCode}`);
    } else {
        ws.close(1008, "Invalid type (must be host or client)");
        return;
    }

    // Set binary type so we get node Buffers
    ws.binaryType = 'nodebuffer';

    let msgCount = 0;
    ws.on('message', (message) => {
        msgCount++;
        if (msgCount <= 5 || msgCount % 100 === 0) {
            console.log(`[RELAY] ${type}→peer in room ${roomCode} | msg #${msgCount} | ${message.length} bytes`);
        }
        // Forward message to the other peer if available
        if (type === 'host' && room.client && room.client.readyState === WebSocket.OPEN) {
            room.client.send(message);
        } else if (type === 'client' && room.host && room.host.readyState === WebSocket.OPEN) {
            room.host.send(message);
        }
    });

    ws.on('close', () => {
        console.log(`[-] Disconnected ${type.toUpperCase()} from room ${roomCode}`);
        if (type === 'host') {
            room.host = null;
            // Optionally close client if host leaves
            if (room.client) {
                room.client.close(1000, "Host disconnected");
            }
            rooms.delete(roomCode);
        } else if (type === 'client') {
            room.client = null;
        }
    });

    ws.on('error', (err) => {
        console.error(`Error on ${type} in room ${roomCode}:`, err.message);
    });
});

server.listen(PORT, () => {
    console.log(`🚀 GUPT WebSocket Relay Server running on port ${PORT}`);
});
