import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../services/export/share_poster_service.dart';

final shareCardPlatformProvider =
    Provider<ShareCardPlatform>((ref) => const ShareCardPlatform());

/// Keeps the established Gal gallery and temporary PNG/system share contract.
class ShareCardPlatform {
  const ShareCardPlatform();
  Future<SavePosterResult> save(Uint8List bytes) =>
      SharePosterService.savePosterToGallery(bytes);

  Future<ShareResultStatus?> share(Uint8List bytes, Rect anchor) async {
    Object? failure;
    ShareResultStatus? status;
    await SharePosterService.sharePoster(
      bytes,
      sharePositionOrigin: anchor,
      onResult: (result) => status = result.status,
      onError: (error) => failure = error,
    );
    if (failure != null) throw failure!;
    return status;
  }
}
