// lib/services/p2p_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/websocket_service.dart';
import '../services/identity_service.dart';

/// Mô hình tin nhắn đơn giản
class ChatMessage {
  final String senderId;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.senderId,
    required this.text,
    required this.timestamp,
  });
}

/// Dịch vụ quản lý kết nối P2P (WebRTC DataChannel)
class P2PService with ChangeNotifier {
  final IdentityService _identityService;
  final WebSocketService _signalingService;

  /// Cấu hình ICE/STUN server
  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  /// Quản lý danh sách kết nối P2P đang hoạt động
  final Map<String, RTCPeerConnection> _peerConnections = {};

  /// Quản lý các kênh dữ liệu (chat/gửi file)
  final Map<String, RTCDataChannel> _dataChannels = {};

  /// Lịch sử tin nhắn giữa các peer
  final Map<String, List<ChatMessage>> _chatHistory = {};
  Map<String, List<ChatMessage>> get chatHistory => _chatHistory;

  P2PService(this._identityService, this._signalingService) {
    // Lắng nghe tin nhắn điều phối (signaling)
    _signalingService.onRelayMessage = _handleSignalingMessage;
  }

  // ---------------------------------------------------------
  // 1️⃣ Tạo kết nối tới một peer khác
  // ---------------------------------------------------------
  Future<void> connectToPeer(String targetPeerId) async {
    if (_peerConnections.containsKey(targetPeerId)) {
      print('⚠️ Đã có kết nối đến $targetPeerId');
      return;
    }

    print(
        '🔗 Đang khởi tạo kết nối đến peer: ${targetPeerId.substring(0, 10)}...');

    RTCPeerConnection pc = await _createPeerConnection(targetPeerId);
    _peerConnections[targetPeerId] = pc;

    // Tạo DataChannel
    RTCDataChannelInit dataChannelInit = RTCDataChannelInit()..ordered = true;
    RTCDataChannel channel =
        await pc.createDataChannel('dataChannel', dataChannelInit);
    _dataChannels[targetPeerId] = channel;
    _setupDataChannelEvents(targetPeerId, channel);

    // Tạo offer
    RTCSessionDescription offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    // Gửi offer qua signaling server
    _signalingService.relayMessage(targetPeerId, {
      'type': 'offer',
      'sdp': offer.toMap(),
    });
  }

  // ---------------------------------------------------------
  // 2️⃣ Xử lý tin signaling nhận được
  // ---------------------------------------------------------
  Future<void> _handleSignalingMessage(
      String senderPeerId, dynamic payload) async {
    print(
        '📩 Nhận được tin nhắn ${payload['type']} từ ${senderPeerId.substring(0, 10)}...');

    if (!_peerConnections.containsKey(senderPeerId)) {
      RTCPeerConnection pc = await _createPeerConnection(senderPeerId);
      _peerConnections[senderPeerId] = pc;

      pc.onDataChannel = (channel) {
        print('📡 Nhận DataChannel từ $senderPeerId');
        _dataChannels[senderPeerId] = channel;
        _setupDataChannelEvents(senderPeerId, channel);
      };
    }

    RTCPeerConnection pc = _peerConnections[senderPeerId]!;

    switch (payload['type']) {
      case 'offer':
        final offer = RTCSessionDescription(
          payload['sdp']['sdp'],
          payload['sdp']['type'],
        );
        await pc.setRemoteDescription(offer);

        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);

        _signalingService.relayMessage(senderPeerId, {
          'type': 'answer',
          'sdp': answer.toMap(),
        });
        break;

      case 'answer':
        final answer = RTCSessionDescription(
          payload['sdp']['sdp'],
          payload['sdp']['type'],
        );
        await pc.setRemoteDescription(answer);
        break;

      case 'ice_candidate':
        final candidate = RTCIceCandidate(
          payload['candidate']['candidate'],
          payload['candidate']['sdpMid'],
          payload['candidate']['sdpMLineIndex'],
        );
        await pc.addCandidate(candidate);
        break;
    }
  }

  // ---------------------------------------------------------
  // 3️⃣ Gửi tin nhắn qua DataChannel
  // ---------------------------------------------------------
  void sendMessage(String targetPeerId, String text) {
    final channel = _dataChannels[targetPeerId];

    if (channel != null &&
        channel.state == RTCDataChannelState.RTCDataChannelOpen) {
      final messagePayload = json.encode({
        'type': 'chat',
        'content': text,
        'timestamp': DateTime.now().toIso8601String(),
      });

      channel.send(RTCDataChannelMessage(messagePayload));
      _addMessageToHistory(targetPeerId, _identityService.myPeerId!, text);
    } else {
      print(
          '⚠️ Không thể gửi tin: DataChannel chưa sẵn sàng. (Trạng thái: ${channel?.state})');
    }
  }

  // ---------------------------------------------------------
  // 4️⃣ Lắng nghe sự kiện của DataChannel
  // ---------------------------------------------------------
  void _setupDataChannelEvents(String peerId, RTCDataChannel channel) {
    channel.onMessage = (message) {
      if (message.isBinary) {
        print('📦 Nhận dữ liệu file (binary) — chưa xử lý.');
      } else {
        try {
          final data = json.decode(message.text);
          if (data['type'] == 'chat') {
            _addMessageToHistory(peerId, peerId, data['content']);
          }
        } catch (e) {
          print('❌ Lỗi khi xử lý tin nhắn DataChannel: $e');
        }
      }
    };

    channel.onDataChannelState = (state) {
      print('📶 DataChannel [${peerId.substring(0, 10)}] state: $state');

      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        if (!_chatHistory.containsKey(peerId)) {
          _chatHistory[peerId] = [];
          notifyListeners();
        }
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        print('❌ DataChannel của $peerId đã đóng.');
      }
    };
  }

  // ---------------------------------------------------------
  // 5️⃣ Helper: thêm tin nhắn vào lịch sử
  // ---------------------------------------------------------
  void _addMessageToHistory(String peerId, String senderId, String text) {
    _chatHistory.putIfAbsent(peerId, () => []);
    _chatHistory[peerId]!.add(ChatMessage(
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  // ---------------------------------------------------------
  // 6️⃣ Helper: tạo PeerConnection mới
  // ---------------------------------------------------------
  Future<RTCPeerConnection> _createPeerConnection(String peerId) async {
    RTCPeerConnection pc = await createPeerConnection(_iceConfig);

    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        _signalingService.relayMessage(peerId, {
          'type': 'ice_candidate',
          'candidate': candidate.toMap(),
        });
      }
    };

    pc.onConnectionState = (state) {
      print('🌐 Connection [${peerId.substring(0, 10)}]: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _cleanupConnection(peerId);
      }
    };

    return pc;
  }

  // ---------------------------------------------------------
  // 7️⃣ Dọn dẹp khi kết nối đóng
  // ---------------------------------------------------------
  void _cleanupConnection(String peerId) {
    _peerConnections[peerId]?.close();
    _peerConnections.remove(peerId);
    _dataChannels[peerId]?.close();
    _dataChannels.remove(peerId);

    print('🧹 Đã dọn dẹp kết nối với ${peerId.substring(0, 10)}');
    notifyListeners();
  }
}
