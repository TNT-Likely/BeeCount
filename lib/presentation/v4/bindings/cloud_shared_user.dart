import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers.dart';

final cloudSharedUserProvider =
    FutureProvider.autoDispose<CloudUser?>((ref) async {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final auth = await ref.watch(authServiceProvider.future);
  final user = await auth.currentUser;
  if (!disposed) {
    var previous = user;
    final subscription = auth.authStateChanges.listen((next) {
      if (!disposed && next != previous) {
        previous = next;
        ref.invalidateSelf();
      }
    }, onError: (Object error, StackTrace stack) {
      if (!disposed) ref.invalidateSelf();
    });
    ref.onDispose(subscription.cancel);
  }
  return user;
});
