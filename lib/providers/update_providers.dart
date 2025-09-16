import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 更新进度状态
class UpdateProgress {
  final double progress;
  final String status;
  final bool isActive;

  const UpdateProgress({
    required this.progress,
    required this.status,
    required this.isActive,
  });

  factory UpdateProgress.idle() => const UpdateProgress(
    progress: 0.0,
    status: '',
    isActive: false,
  );

  factory UpdateProgress.active(double progress, String status) => UpdateProgress(
    progress: progress,
    status: status,
    isActive: true,
  );

  UpdateProgress copyWith({
    double? progress,
    String? status,
    bool? isActive,
  }) {
    return UpdateProgress(
      progress: progress ?? this.progress,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// 更新进度Provider
final updateProgressProvider = StateProvider<UpdateProgress>((ref) => UpdateProgress.idle());