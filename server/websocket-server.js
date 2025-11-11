// server/websocket-server.js
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });

/**
 * Map này sẽ lưu:
 * key: peerId (là public key của user)
 * value: kết nối WebSocket (ws) của user đó
 */
const peers = new Map();

console.log('✅ P2P Signaling Server đang chạy trên port 8080');

wss.on('connection', (ws) => {
    let currentPeerId = null; // ID của peer đang kết nối này

    ws.on('message', (message) => {
        let data;
        try {
            data = JSON.parse(message);
        } catch (e) {
            console.error('Lỗi parse JSON:', e);
            return;
        }

        // console.log('Nhận:', data.type);

        switch (data.type) {
            /**
             * Bước 1: Peer đăng ký ID của mình với server
             * { type: 'register', peerId: '...' }
             */
            case 'register':
                currentPeerId = data.peerId;
                peers.set(currentPeerId, ws);
                console.log(`Peer đã đăng ký: ${currentPeerId.substring(0, 10)}...`);
                break;

            /**
             * Bước 2: Chuyển tiếp (relay) tin nhắn đến một peer cụ thể
             * Tin nhắn này sẽ là offer, answer, hoặc ice_candidate
             * { type: 'relay', targetPeerId: '...', payload: { ... } }
             */
            case 'relay':
                const targetPeerId = data.targetPeerId;
                const targetPeer = peers.get(targetPeerId);

                if (targetPeer && targetPeer.readyState === WebSocket.OPEN) {
                    // Gửi đi mà không cần biết nội dung payload là gì
                    targetPeer.send(JSON.stringify({
                        type: 'relay',
                        senderPeerId: currentPeerId, // Ghi rõ người gửi
                        payload: data.payload 
                    }));
                } else {
                    console.log(`Peer ${targetPeerId.substring(0, 10)}... không online hoặc không tìm thấy.`);
                }
                break;

            default:
                console.log('Loại tin nhắn không xác định:', data.type);
        }
    });

    ws.on('close', () => {
        if (currentPeerId) {
            peers.delete(currentPeerId);
            console.log(`Peer đã ngắt kết nối: ${currentPeerId.substring(0, 10)}...`);
        }
    });

    ws.on('error', (err) => {
        console.error('WebSocket error:', err);
    });
}); 