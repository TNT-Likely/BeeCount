import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/base_repository.dart';
import '../../../auth/splash_page.dart';
import '../../../../providers/database_providers.dart';
import '../../../../providers/home_startup_preview_provider.dart';

/// Enter Home only with a complete snapshot. Normally Splash already prepared
/// it, so this gate is synchronous. If data changed while the app was locked,
/// re-prepare on the startup surface instead of opening an empty Home first.
class HomeStartupGate extends ConsumerStatefulWidget {
  const HomeStartupGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<HomeStartupGate> createState() => _HomeStartupGateState();
}

class _HomeStartupGateState extends ConsumerState<HomeStartupGate> {
  BaseRepository? _repository;
  int? _ledger;
  int _generation = 0;
  bool _ready = false, _entered = false;
  Object? _error;

  void _bind(BaseRepository repository, int ledger) {
    _repository = repository;
    _ledger = ledger;
    _error = null;
    final handoff = ref.read(homeStartupPreviewHandoffProvider);
    _ready = handoff.peek(repository, ledger) != null;
    final generation = ++_generation;
    if (!_ready) _prepare(repository, ledger, generation);
  }

  Future<void> _prepare(
      BaseRepository repository, int ledger, int generation) async {
    try {
      final handoff = ref.read(homeStartupPreviewHandoffProvider);
      while (mounted && generation == _generation) {
        await handoff.prepare(repository, ledger, ref.read(databaseProvider));
        if (!mounted || generation != _generation) return;
        if (handoff.peek(repository, ledger) == null) continue;
        setState(() => _ready = true);
        return;
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Once entered, normal ledger changes belong to the live Home feed.
    if (_entered) return widget.child;
    final repository = ref.watch(repositoryProvider);
    final ledger = ref.watch(currentLedgerIdProvider);
    if (!identical(repository, _repository) || ledger != _ledger) {
      _bind(repository, ledger);
    }
    if (_ready) {
      _entered = true;
      return widget.child;
    }
    return SplashPage(
        loadError: _error != null,
        onRetry: () => setState(() => _bind(repository, ledger)));
  }
}
