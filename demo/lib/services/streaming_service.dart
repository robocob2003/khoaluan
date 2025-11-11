// lib/services/streaming_service.dart

import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Quản lý logic streaming media, bao gồm bộ đệm trượt (sliding window).
/// Lớp này không phụ thuộc vào bất kỳ service nào khác, chỉ chứa logic thuần túy.
class StreamingManager {
  final String fileId;
  final int totalChunks;

  // Callback này sẽ được gọi khi manager cần tải một chunk mới.
  // Chúng ta sẽ triển khai nó ở các bước sau.
  final Function(int chunkIndex) onChunkNeeded;

  // Callback để xóa dữ liệu chunk vật lý.
  final Function(int chunkIndex) onChunkShouldBeDeleted;

  // Sử dụng Queue để dễ dàng thêm/xóa ở hai đầu, mô phỏng một "cửa sổ trượt".
  final Queue<int> _bufferedChunkIndices = Queue<int>();

  // Kích thước của cửa sổ bộ đệm (ví dụ: luôn cố gắng giữ 20 chunk).
  final int _windowSize = 20;

  // Vị trí chunk mà người dùng đang xem.
  int _currentPlaybackIndex = 0;

  // Danh sách các chunk đang trong quá trình yêu cầu tải về.
  final Set<int> _pendingChunks = {};

  StreamingManager({
    required this.fileId,
    required this.totalChunks,
    required this.onChunkNeeded,
    required this.onChunkShouldBeDeleted,
  });

  /// Được gọi bởi media player khi vị trí phát thay đổi.
  /// Đây là "cò súng" kích hoạt toàn bộ logic.
  void updatePlaybackPosition(int newIndex) {
    if (newIndex > _currentPlaybackIndex) {
      _currentPlaybackIndex = newIndex;
      _updateBuffer();
    }
  }

  /// Được gọi khi một chunk đã được tải về thành công.
  void markChunkAsDownloaded(int chunkIndex) {
    _pendingChunks.remove(chunkIndex);
    // Có thể kích hoạt lại việc update buffer để đảm bảo không bị thiếu chunk
    _updateBuffer();
  }

  /// Logic cốt lõi: kiểm tra và cập nhật bộ đệm.
  void _updateBuffer() {
    // 1. XÓA CHUNK CŨ:
    // Xóa các chunk đã xem và nằm ngoài vùng đệm an toàn phía sau.
    // Ví dụ: giữ lại 5 chunk đã xem để người dùng có thể tua lại một chút.
    while (_bufferedChunkIndices.isNotEmpty &&
        _bufferedChunkIndices.first < _currentPlaybackIndex - 5) {
      final chunkToRemove = _bufferedChunkIndices.removeFirst();
      onChunkShouldBeDeleted(chunkToRemove); // Gọi callback để xóa file vật lý
      debugPrint("StreamingManager: 🗑️ Yêu cầu xóa chunk $chunkToRemove.");
    }

    // 2. TẢI CHUNK MỚI:
    // Lấp đầy "cửa sổ" phía trước vị trí phát hiện tại.
    for (int i = 0; i < _windowSize; i++) {
      final nextChunkIndex = _currentPlaybackIndex + i;

      // Điều kiện để yêu cầu một chunk mới:
      // - Nó phải nằm trong tổng số chunk của tệp.
      // - Nó chưa có trong bộ đệm.
      // - Nó không đang trong quá trình được tải về.
      if (nextChunkIndex < totalChunks &&
          !_bufferedChunkIndices.contains(nextChunkIndex) &&
          !_pendingChunks.contains(nextChunkIndex)) {
        _pendingChunks.add(nextChunkIndex);
        _bufferedChunkIndices.add(
            nextChunkIndex); // Thêm vào buffer ngay để tránh yêu cầu trùng lặp

        onChunkNeeded(nextChunkIndex); // Gọi callback để bắt đầu tải về
        debugPrint("StreamingManager: 📥 Yêu cầu tải chunk $nextChunkIndex.");
      }
    }
  }
}
