// websocket-server.js

const express = require("express");
const bodyParser = require("body-parser");
const cors = require("cors");
const fs = require("fs");
const path = require("path");
const WebSocket = require("ws");
const crypto = require("crypto");

// ... (Toàn bộ code API: register, login, update-profile, users, health... giữ nguyên) ...
const app = express();
app.use(cors());
app.use(bodyParser.json());
app.use(express.static("public"));

const USERS_FILE = "users.json";

if (!fs.existsSync(USERS_FILE)) fs.writeFileSync(USERS_FILE, JSON.stringify([]));

function readUsers() { return JSON.parse(fs.readFileSync(USERS_FILE)); }
function writeUsers(users) { fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2)); }
function hashPassword(password, salt) { return crypto.createHmac('sha256', salt).update(password).digest('hex'); }

app.post("/register", (req, res) => {
  const { username, password, email, publicKey } = req.body; 
  if (!username || !password || !publicKey) {
    return res.status(400).json({ message: "Username, password, and publicKey are required" });
  }
  let users = readUsers();
  if (users.find(u => u.username.toLowerCase() === username.toLowerCase())) {
    return res.status(400).json({ message: "User already exists" });
  }
  const salt = crypto.randomBytes(16).toString('hex');
  const hashedPassword = hashPassword(password, salt);
  users.push({ username, email: email || '', salt, hashedPassword, publicKey });
  writeUsers(users);
  res.status(201).json({ message: "Register successful" });
});

app.post("/login", (req, res) => {
  const { username, password } = req.body;
  let users = readUsers();
  const user = users.find(u => u.username.toLowerCase() === username.toLowerCase());
  if (!user) return res.status(400).json({ message: "Invalid username or password" });
  const hashedPassword = hashPassword(password, user.salt);
  if (hashedPassword !== user.hashedPassword) return res.status(400).json({ message: "Invalid username or password" });
  res.json({ message: "Login successful", publicKey: user.publicKey });
});

app.put("/update-profile", (req, res) => {
  const { username, email } = req.body;
  if (!username || !email) {
    return res.status(400).json({ message: "Username and email are required" });
  }
  let users = readUsers();
  const userIndex = users.findIndex(u => u.username.toLowerCase() === username.toLowerCase());
  if (userIndex === -1) {
    return res.status(404).json({ message: "User not found" });
  }
  users[userIndex].email = email;
  writeUsers(users);
  console.log(`👤 Profile updated for ${username}. New email: ${email}`);
  res.status(200).json({ message: "Profile updated successfully", email: email });
});

app.get("/users", (req, res) => {
  const users = readUsers();
  // ---- SỬA: Đảm bảo ID trả về là index + 1 ----
  const publicUsers = users.map((u, index) => ({ 
      id: index + 1, // <-- ID phải nhất quán
      username: u.username, 
      publicKey: u.publicKey, 
      email: u.email || `${u.username}@example.com` 
  }));
  res.json(publicUsers);
});

app.get("/health", (req, res) => {
  res.status(200).json({ status: "OK" });
});

// ... (Toàn bộ logic WebSocket (wss) bên dưới) ...
const server = app.listen(3000, '0.0.0.0', () => console.log(`🚀 HTTP server running on http://192.168.1.27:3000`)); 
const wss = new WebSocket.Server({ server });

const clients = new Map(); 
const fileRooms = new Map(); 
const groupRooms = new Map(); 

wss.on("connection", (ws) => {
  console.log("✅ New WebSocket client connected");
  ws.on("message", (data) => {
    try {
      const msg = JSON.parse(data);
      
      if (msg.type === "auth") {
        // ... (Giữ nguyên)
        const username = msg.username;
        if (username) {
            ws.username = username;
            clients.set(username.toLowerCase(), ws);
            console.log(`🔑 User authenticated as: ${username}`);
        }
        return;
      }

      if (msg.type === 'ping') {
        // ... (Giữ nguyên)
        ws.send(JSON.stringify({ type: 'pong' }));
        return;
      }

      // (Tất cả logic join/leave/broadcast khác giữ nguyên y hệt)
      // ...
      if (msg.type === 'join_group_room') {
        // ... (Giữ nguyên)
        const groupId = msg.groupId;
        if (!groupRooms.has(groupId)) {
          groupRooms.set(groupId, new Set());
        }
        groupRooms.get(groupId).add(ws);
        console.log(`💬 User ${ws.username} joined group chat room: ${groupId}`);
        return;
      }

      if (msg.type === 'leave_group_room') {
        // ... (Giữ nguyên)
        const groupId = msg.groupId;
        if (groupRooms.has(groupId)) {
          groupRooms.get(groupId).delete(ws);
          if (groupRooms.get(groupId).size === 0) {
            groupRooms.delete(groupId);
          }
        }
        console.log(`💬 User ${ws.username} left group chat room: ${groupId}`);
        return;
      }

      if (msg.type === 'join_file_room') {
        // ... (Giữ nguyên)
        const fileId = msg.fileId;
        if (!fileRooms.has(fileId)) {
          fileRooms.set(fileId, new Set());
        }
        fileRooms.get(fileId).add(ws);
        console.log(`🚪 User ${ws.username} joined file room: ${fileId}`);
        return;
      }
      
      if (msg.type === 'leave_file_room') {
        // ... (Giữ nguyên)
        const fileId = msg.fileId;
        if (fileRooms.has(fileId)) {
          fileRooms.get(fileId).delete(ws);
          if (fileRooms.get(fileId).size === 0) {
            fileRooms.delete(fileId);
          }
        }
        console.log(`🚪 User ${ws.username} left file room: ${fileId}`);
        return;
      }

      const p2pBroadcastTypes = ['announce_chunk'];
      if (p2pBroadcastTypes.includes(msg.type)) {
        // ... (Giữ nguyên)
        const room = fileRooms.get(msg.fileId);
        if (room) {
          console.log(`📢 Broadcasting (P2P) '${msg.type}' in room ${msg.fileId} from ${ws.username}`);
          room.forEach(client => {
            if (client !== ws && client.readyState === WebSocket.OPEN) {
              client.send(data.toString());
            }
          });
        }
        return;
      }
      
      const groupBroadcastTypes = ['group_message', 'file_metadata', 'file_chunk', 'file_comment', 'file_tags'];
      
      if (groupBroadcastTypes.includes(msg.type) && msg.groupId) {
        // ... (GiGữ nguyên)
        const room = groupRooms.get(msg.groupId);
        if (room) {
          console.log(`📢 Broadcasting (Group) '${msg.type}' in room ${msg.groupId} from ${ws.username}`);
          room.forEach(client => {
            if (client !== ws && client.readyState === WebSocket.OPEN) {
              client.send(data.toString());
            }
          });
        }
        return;
      }
      
      // ---- SỬA LOGIC CHUYỂN TIẾP 1-1 ----
      // Thêm 'friend_reject' vào đây
      const oneToOneTypes = [
          'message', 
          'typing', 
          'file_metadata', 
          'file_chunk', 
          'request_download', 
          'request_specific_chunk',
          'group_invite', 
          'friend_request', 
          'friend_accept',
          'friend_reject' // <-- THÊM MỚI
      ];
      
      // Logic 1-1
      const recipientUsername = msg.to?.toLowerCase();
      if (recipientUsername && oneToOneTypes.includes(msg.type)) {
        // ------------------------------------
        const recipientWs = clients.get(recipientUsername);
        if (recipientWs && recipientWs.readyState === WebSocket.OPEN) {
          console.log(`↪️  Forwarding 1-to-1 message of type '${msg.type}' from ${msg.from} to ${msg.to}`);
          recipientWs.send(data.toString());
        } else {
          console.log(`❌ Recipient '${msg.to}' not found or not connected.`);
        }
      } else {
         console.log(`⚠️  Dropping message of type '${msg.type}' from ${ws.username}. No 'to' field or 'groupId' found.`);
      }

    } catch (error) {
      console.log("- Error processing message:", error);
    }
  });

  ws.on("close", () => {
    // ... (Toàn bộ logic 'close' giữ nguyên y hệt)
    if (ws.username) {
      clients.delete(ws.username.toLowerCase());
      console.log(`❌ WebSocket client '${ws.username}' disconnected`);
      
      fileRooms.forEach((room, fileId) => {
        if (room.has(ws)) {
          room.delete(ws);
          console.log(`🚪 User ${ws.username} removed from file room ${fileId} due to disconnect.`);
          if (room.size === 0) {
            fileRooms.delete(fileId);
          }
        }
      });
      
      groupRooms.forEach((room, groupId) => {
        if (room.has(ws)) {
          room.delete(ws);
          console.log(`💬 User ${ws.username} removed from group room ${groupId} due to disconnect.`);
          if (room.size === 0) {
            groupRooms.delete(groupId);
          }
        }
      });

    } else {
      console.log("❌ Anonymous WebSocket client disconnected");
    }
  });
});
