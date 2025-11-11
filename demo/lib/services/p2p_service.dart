// demo/lib/services/p2p_service.dart
import 'dart:convert';
import 'dart:typed_data'; // Sẽ dùng cho truyền file
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/websocket_service.dart';
import '../services/identity_service.dart';

// Model đơn giản để lưu trữ tin nhắn chat
class ChatMessage {
  final String senderId;
  final String text;
  final DateTime timestamp;
  ChatMessage(
      {required this.senderId, required this.text, required this.timestamp});
}

// Service chính quản lý logic P2P
class P2PService with ChangeNotifier {
  final IdentityService _identityService;
  final WebSocketService _signalingService;

  // Cấu hình STUN server (cần thiết để vượt NAT/Tường lửa)
  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  // Quản lý các kết nối P2P đang hoạt động
  final Map<String, RTCPeerConnection> _peerConnections = {};

  // Quản lý các kênh dữ liệu (để chat/gửi file)
  final Map<String, RTCDataChannel> _dataChannels = {};

  // Quản lý lịch sử tin nhắn
  final Map<String, List<ChatMessage>> _chatHistory = {};
  Map<String, List<ChatMessage>> get chatHistory => _chatHistory;

  P2PService(this._identityService, this._signalingService) {
    // Quan trọng: Lắng nghe các tin nhắn 'relay' từ WebSocketService
    _signalingService.onRelayMessage = _handleSignalingMessage;
  }

  // --- Logic Chính: Tạo Kết nối ---

  // 1. (Người gọi) Bắt đầu kết nối đến một peer
  Future<void> connectToPeer(String targetPeerId) async {
    if (_peerConnections.containsKey(targetPeerId)) {
      print('Đã có kết nối đến $targetPeerId');
      return;
    }
    print('Đang kết nối đến peer: ${targetPeerId.substring(0, 10)}...');

    RTCPeerConnection pc = await _createPeerConnection(targetPeerId);
    _peerConnections[targetPeerId] = pc;

    RTCDataChannelInit dataChannelInit = RTCDataChannelInit();
    dataChannelInit.ordered = true;
    RTCDataChannel channel =
        await pc.createDataChannel('dataChannel', dataChannelInit);
    _dataChannels[targetPeerId] = channel;
    _setupDataChannelEvents(targetPeerId, channel); // Cài đặt listener

    RTCSessionDescription offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    _signalingService.relayMessage(targetPeerId, {
      'type': 'offer',
      'sdp': offer.toMap(),
    });
  }

  // 2. (Người nhận) Xử lý tin nhắn điều phối nhận được
  Future<void> _handleSignalingMessage(
      String senderPeerId, dynamic payload) async {
    print(
        'Nhận được tin nhắn ${payload['type']} từ ${senderPeerId.substring(0, 10)}...');

    if (!_peerConnections.containsKey(senderPeerId)) {
      RTCPeerConnection pc = await _createPeerConnection(senderPeerId);
      _peerConnections[senderPeerId] = pc;

      pc.onDataChannel = (channel) {
        print('Nhận được Data Channel từ $senderPeerId');
        _dataChannels[senderPeerId] = channel;
        _setupDataChannelEvents(senderPeerId, channel); // Cài đặt listener
      };
    }

    RTCPeerConnection pc = _peerConnections[senderPeerId]!;

    switch (payload['type']) {
      case 'offer':
        RTCSessionDescription offer = RTCSessionDescription(
          payload['sdp']['sdp'],
          payload['sdp']['type'],
        );
        await pc.setRemoteDescription(offer);

        RTCSessionDescription answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);

        _signalingService.relayMessage(senderPeerId, {
          'type': 'answer',
          'sdp': answer.toMap(),
        });
        break;

      case 'answer':
        RTCSessionDescription answer = RTCSessionDescription(
          payload['sdp']['sdp'],
          payload['sdp']['type'],
        );
        await pc.setRemoteDescription(answer);
        break;

      case 'ice_candidate':
        RTCIceCandidate candidate = RTCIceCandidate(
          payload['candidate']['candidate'],
          payload['candidate']['sdpMid'],
          payload['candidate']['sdpMLineIndex'],
        );
        await pc.addCandidate(candidate);
        break;
    }
  }

  // --- Gửi & Nhận Dữ liệu ---

  // 3. Gửi tin nhắn 1-1
  void sendMessage(String targetPeerId, String text) {
    final channel = _dataChannels[targetPeerId];

    // --- SỬA LỖI Ở ĐÂY (NẾU CÓ) ---
    // Phải là `RTCDataChannelState.DataChannelOpen`
    if (channel != null &&
        channel.state == RTCDataChannelState.DataChannelOpen) {
      // --- KẾT THÚC SỬA ---

      final messagePayload = json.encode({
        'type': 'chat',
        'content': text,
        'timestamp': DateTime.now().toIso8601String(), // Đã sửa lỗi 801
      });

      channel.send(RTCDataChannelMessage(messagePayload));
      _addMessageToHistory(targetPeerId, _identityService.myPeerId!, text);
    } else {
      print('Không thể gửi tin nhắn: Data Channel chưa sẵn sàng.');
    }
  }

  // 4. Cài đặt các sự kiện cho Data Channel (lắng nghe tin nhắn/file)
  void _setupDataChannelEvents(String peerId, RTCDataChannel channel) {
    channel.onMessage = (message) {
      if (message.isBinary) {
        print('Nhận được dữ liệu file (chưa xử lý)');
      } else {
        try {
          final data = json.decode(message.text);
          if (data['type'] == 'chat') {
            _addMessageToHistory(peerId, peerId, data['content']);
          }
        } catch (e) {
          print('Lỗi khi xử lý tin nhắn Data Channel: $e');
        }
      }
    };

    channel.onDataChannelState = (state) {
      print('Data Channel [${peerId.substring(0, 10)}] state: $state');

      // --- SỬA LỖI Ở ĐÂY (NẾU CÓ) ---
      // Phải là `RTCDataChannelState.DataChannelOpen`
      if (state == RTCDataChannelState.DataChannelOpen) {
        // --- KẾT THÚC SỬA ---

        if (!_chatHistory.containsKey(peerId)) {
          _chatHistory[peerId] = [];
          notifyListeners();
        }
      }
    };
  }

  // --- Các hàm Helper ---

  void _addMessageToHistory(String peerId, String senderId, String text) {
    if (!_chatHistory.containsKey(peerId)) {
      _chatHistory[peerId] = [];
    }
    _chatHistory[peerId]!.add(ChatMessage(
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

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
      print('Connection State [${peerId.substring(0, 10)}]: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _cleanupConnection(peerId);
      }
    };

    return pc;
  }

  void _cleanupConnection(String peerId) {
    _peerConnections[peerId]?.close();
    _peerConnections.remove(peerId);
    _dataChannels[peerId]?.close();
    _dataChannels.remove(peerId);

    print('Đã dọn dẹp kết nối với ${peerId.substring(0, 10)}');
    notifyListeners();
  }
}
