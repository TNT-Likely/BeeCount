import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/platform_info.dart';

final iosAutoBillingSupportsAppIntentsProvider =
    Provider<bool>((ref) => PlatformInfo.supportsAppIntents);
final iosAutoBillingActionsProvider =
    Provider<IOSAutoBillingActions>((ref) => IOSAutoBillingActions());

/// Original URLs and external-application launch mode. No shortcut is executed
/// by this binding: the system still presents the import / tutorial destination.
class IOSAutoBillingActions {
  static final shortcutUri = Uri.parse(
      'https://www.icloud.com/shortcuts/fda5016c98eb474f840f2f91396bd241');
  static final tutorialUri = Uri.parse('https://xhslink.com/o/fKlXTFfHNm');
  Future<bool> openShortcut() => _open(shortcutUri);
  Future<bool> openTutorial() => _open(tutorialUri);
  Future<bool> _open(Uri uri) async =>
      await canLaunchUrl(uri) &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
}
