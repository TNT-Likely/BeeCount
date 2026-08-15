import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../widgets/biz/biz.dart';
import '../../widgets/ui/ui.dart';

class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  bool _loading = true;
  String? _error;
  bool _scopeDenied = false;
  bool _showAllSessions = false;
  String? _currentDeviceId;
  String? _currentDeviceFingerprint;
  List<BeeCountCloudDevice> _devices = const [];
  List<BeeCountCloudDevice> _allSessions = const [];

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(value.toLocal());
  }

  bool _isScopeDeniedError(Object error) {
    final lower = error.toString().toLowerCase();
    return lower.contains('insufficient scope');
  }

  int _recentScore(BeeCountCloudDevice device) {
    return device.lastSeenAt?.millisecondsSinceEpoch ??
        device.createdAt?.millisecondsSinceEpoch ??
        0;
  }

  String _fingerprint(BeeCountCloudDevice device) {
    String normalize(String? value) {
      final out = (value ?? '').trim().toLowerCase();
      return out.isEmpty ? '__empty__' : out;
    }

    return [
      normalize(device.name),
      normalize(device.platform),
      normalize(device.deviceModel),
      normalize(device.osVersion),
      normalize(device.appVersion),
    ].join('|');
  }

  List<BeeCountCloudDevice> _sorted(List<BeeCountCloudDevice> devices) {
    final out = devices.toList(growable: false);
    out.sort((a, b) => _recentScore(b).compareTo(_recentScore(a)));
    return out;
  }

  List<String> _targetSessionIds(BeeCountCloudDevice device) {
    if (_showAllSessions) {
      return [device.id];
    }
    final fp = _fingerprint(device);
    return _allSessions
        .where((row) => _fingerprint(row) == fp)
        .map((row) => row.id)
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  /// 获取 BeeCountCloudProvider 实例（仅 beecountCloud 后端可用）
  Future<BeeCountCloudProvider> _getCloudProvider() async {
    final config = await ref.read(activeCloudConfigProvider.future);
    if (!config.valid || config.type != CloudBackendType.beecountCloud) {
      throw StateError(
          AppLocalizations.of(context).cloudCollabUnavailableMessage);
    }
    final services = await createCloudServices(config);
    if (services.provider == null || services.provider is! BeeCountCloudProvider) {
      throw StateError(
          AppLocalizations.of(context).cloudCollabUnavailableMessage);
    }
    return services.provider as BeeCountCloudProvider;
  }

  Future<void> _reload({bool keepLoadingState = true}) async {
    setState(() {
      if (keepLoadingState) {
        _loading = true;
      }
      _error = null;
      _scopeDenied = false;
    });
    try {
      final auth = await ref.read(authServiceProvider.future);
      final user = await auth.currentUser;
      final currentDeviceId = user?.metadata?['deviceId']?.toString();

      final provider = await _getCloudProvider();
      final devices = await provider.listDevices(
        view: _showAllSessions ? 'sessions' : 'deduped',
        activeWithinDays: 30,
      );
      final sessions = _showAllSessions
          ? devices
          : await provider.listDevices(
              view: 'sessions',
              activeWithinDays: 30,
            );
      final currentFp = currentDeviceId == null
          ? null
          : sessions
              .where((row) => row.id == currentDeviceId)
              .map(_fingerprint)
              .firstOrNull;
      if (!mounted) return;
      setState(() {
        _currentDeviceId = currentDeviceId;
        _currentDeviceFingerprint = currentFp;
        _devices = _sorted(devices);
        _allSessions = _sorted(sessions);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scopeDenied = _isScopeDeniedError(e);
        _error = _scopeDenied
            ? AppLocalizations.of(context).cloudCollabScopeDeniedHint
            : '$e';
        _loading = false;
      });
    }
  }

  Future<void> _revokeDevice(BeeCountCloudDevice device) async {
    final l10n = AppLocalizations.of(context);
    final targetIds = _targetSessionIds(device)
        .where((id) => id != _currentDeviceId && id.trim().isNotEmpty)
        .toList(growable: false);
    if (targetIds.isEmpty) {
      await AppDialog.warning(
        context,
        title: l10n.cloudCollabDeviceCurrentTag,
        message: l10n.cloudCollabCurrentDeviceCannotRevoke,
      );
      return;
    }

    final title = l10n.cloudCollabDeviceRevokeTitle;
    final message = targetIds.length == 1
        ? l10n.cloudCollabDeviceRevokeMessage(device.name, targetIds.first)
        : l10n.cloudCollabDeviceRevokeMultipleMessage(
            device.name,
            '${targetIds.length}',
          );
    final confirmed = await AppDialog.confirm<bool>(
          context,
          title: title,
          message: message,
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      final provider = await _getCloudProvider();
      for (final id in targetIds) {
        await provider.revokeDevice(deviceId: id);
      }
      if (!mounted) return;
      showToast(context, l10n.cloudCollabDeviceRevoked);
      await _reload(keepLoadingState: false);
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: l10n.commonFailed,
        message: '$e',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = _devices;

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.cloudCollabDevicesPageTitle,
            subtitle: l10n.cloudCollabDevicesPageSubtitle,
            showBack: true,
            actions: [
              IconButton(
                onPressed: _loading ? null : _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${l10n.commonError}: $_error',
                                textAlign: TextAlign.center,
                              ),
                              if (_scopeDenied) ...[
                                const SizedBox(height: 8),
                                Text(
                                  l10n.cloudCollabScopeDeniedAction,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: BeeTokens.textSecondary(context),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : rows.isEmpty
                        ? Center(
                            child: Text(
                              l10n.cloudCollabNoDevices,
                              style: TextStyle(
                                  color: BeeTokens.textSecondary(context)),
                            ),
                          )
                        : Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child: SectionCard(
                                  margin: EdgeInsets.zero,
                                  child: SwitchListTile.adaptive(
                                    title: Text(
                                        l10n.cloudCollabDevicesViewAllSessions),
                                    subtitle: Text(
                                      l10n.cloudCollabDevicesViewModeHint,
                                      style: TextStyle(
                                        color: BeeTokens.textSecondary(context),
                                      ),
                                    ),
                                    value: _showAllSessions,
                                    onChanged: _loading
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _showAllSessions = value;
                                            });
                                            unawaited(_reload(
                                                keepLoadingState: false));
                                          },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: rows.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final device = rows[index];
                                    final isCurrent = _showAllSessions
                                        ? device.id == _currentDeviceId
                                        : _currentDeviceFingerprint != null &&
                                            _fingerprint(device) ==
                                                _currentDeviceFingerprint;

                                    final infoTags = <Widget>[
                                      InfoTag(device.platform),
                                      if ((device.appVersion ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        InfoTag(
                                            l10n.cloudCollabDeviceAppVersion(
                                                device.appVersion!.trim())),
                                      if ((device.osVersion ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        InfoTag(l10n.cloudCollabDeviceOsVersion(
                                            device.osVersion!.trim())),
                                      if ((device.deviceModel ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        InfoTag(l10n.cloudCollabDeviceModel(
                                            device.deviceModel!.trim())),
                                      if ((device.lastIp ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        InfoTag(l10n.cloudCollabDeviceLastIp(
                                            device.lastIp!.trim())),
                                      if (isCurrent)
                                        InfoTag(
                                            l10n.cloudCollabDeviceCurrentTag),
                                      if (!_showAllSessions &&
                                          device.sessionCount > 1)
                                        InfoTag(
                                            l10n.cloudCollabDeviceSessionCount(
                                                '${device.sessionCount}')),
                                      InfoTag(l10n.cloudCollabDeviceLastSeen(
                                          _formatDateTime(device.lastSeenAt))),
                                      InfoTag(l10n.cloudCollabDeviceCreatedAt(
                                          _formatDateTime(device.createdAt))),
                                    ];

                                    return SectionCard(
                                      margin: EdgeInsets.zero,
                                      child: ListTile(
                                        leading: Icon(
                                          isCurrent
                                              ? Icons.smartphone
                                              : Icons.devices_outlined,
                                          color:
                                              BeeTokens.iconSecondary(context),
                                        ),
                                        title: Text(
                                          device.name.trim().isEmpty
                                              ? l10n
                                                  .cloudCollabUnknownDeviceName
                                              : device.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: infoTags,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          onPressed: () =>
                                              _revokeDevice(device),
                                          icon: const Icon(
                                              Icons.mobile_off_outlined),
                                          tooltip:
                                              l10n.cloudCollabDeviceRevokeTitle,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
