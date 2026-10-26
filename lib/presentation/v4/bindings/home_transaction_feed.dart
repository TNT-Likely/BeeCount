import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_list_view/flutter_list_view.dart';

import '../../../data/repositories/base_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/home_transaction_preview.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/home_startup_preview_provider.dart';
import '../../../widgets/biz/transaction_list.dart';

/// First publish a bounded, complete preview. Only then start the full query,
/// so its decoding and relationship reads cannot block the first useful frame.
class HomeTransactionFeed extends ConsumerStatefulWidget {
  const HomeTransactionFeed({
    super.key,
    required this.ledgerId,
    required this.hideAmounts,
    required this.listKey,
    required this.controller,
    this.onDateVisibilityChanged,
    this.emptyWidget,
    this.onPreviewReady,
    this.startupPreview,
  });

  final int ledgerId;
  final bool hideAmounts;
  final GlobalKey<TransactionListState> listKey;
  final FlutterListViewController controller;
  final void Function(String, bool)? onDateVisibilityChanged;
  final Widget? emptyWidget;
  final ValueChanged<HomeTransactionPreview>? onPreviewReady;
  final HomeStartupPreview? startupPreview;

  @override
  ConsumerState<HomeTransactionFeed> createState() =>
      _HomeTransactionFeedState();
}

class _HomeTransactionFeedState extends ConsumerState<HomeTransactionFeed> {
  BaseRepository? _repository;
  int? _ledger;
  int _generation = 0;
  StreamSubscription<List<TransactionRowData>>? _subscription;
  HomeTransactionPreview? _preview;
  List<TransactionRowData>? _fullRows;
  Object? _error;
  bool _sourceLoading = false;

  void _bind(BaseRepository repository, int ledger) {
    final firstBind = _repository == null;
    _repository = repository;
    _ledger = ledger;
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _preview = null;
    _fullRows = null;
    _error = null;
    _sourceLoading = true;
    final startup = firstBind ? widget.startupPreview : null;
    if (startup?.matches(repository, ledger) == true) {
      _preview = startup!.preview;
      // The first build paints the already complete startup snapshot. Do not
      // run a second preview query or notify the parent during its build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _generation) return;
        widget.onPreviewReady?.call(startup.preview);
        _watchFull(repository, ledger, generation);
      });
      return;
    }
    unawaited(_readPreview(repository, ledger, generation));
  }

  Future<void> _readPreview(
      BaseRepository repository, int ledger, int generation) async {
    try {
      // Always read a current snapshot: splash data may predate a manual FX
      // correction, a sync pull or a relationship edit during initialization.
      final preview =
          await repository.getHomeTransactionPreview(ledgerId: ledger);
      if (!mounted || generation != _generation) return;
      widget.onPreviewReady?.call(preview);
      setState(() => _preview = preview);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _generation) {
          _watchFull(repository, ledger, generation);
        }
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _sourceLoading = false;
      });
    }
  }

  void _watchFull(BaseRepository repository, int ledger, int generation) {
    var received = false;
    try {
      _subscription =
          repository.transactionsWithCategoryAll(ledgerId: ledger).listen(
        (rows) {
          if (!mounted || generation != _generation) return;
          received = true;
          setState(() {
            // An empty source emission is authoritative; never fall back to the
            // preview after a delete/clear or a switch into an empty ledger.
            _fullRows = rows;
            _error = null;
            _sourceLoading = false;
          });
        },
        onError: (Object error, StackTrace stack) {
          if (!mounted || generation != _generation) return;
          setState(() {
            _error = error;
            _sourceLoading = false;
          });
        },
        onDone: () {
          if (!mounted || generation != _generation || received) return;
          setState(() {
            _error = StateError(
                'Full transaction source closed before its snapshot');
            _sourceLoading = false;
          });
        },
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _sourceLoading = false;
      });
    }
  }

  Future<void> _retry() async {
    final repository = _repository!, ledger = _ledger!;
    final generation = ++_generation;
    await _subscription?.cancel();
    _subscription = null;
    if (!mounted || generation != _generation) return;
    setState(() {
      _error = null;
      _sourceLoading = true;
    });
    if (_preview == null) {
      await _readPreview(repository, ledger, generation);
    } else {
      _watchFull(repository, ledger, generation);
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(repositoryProvider);
    if (_repository != repository || _ledger != widget.ledgerId) {
      _bind(repository, widget.ledgerId);
    }
    final preview = _preview;
    if (preview == null) {
      if (_error != null) {
        final l = AppLocalizations.of(context);
        return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.commonError),
          TextButton(onPressed: _retry, child: Text(l.v4RecordingRetry)),
        ]));
      }
      return const Center(
          child: SizedBox.square(
              dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return TransactionList(
        key: widget.listKey,
        ledgerId: widget.ledgerId,
        transactions: _fullRows ??
            (preview.totalCount == 0 ? const <TransactionRowData>[] : null),
        transactionsWithDetails: preview.rows,
        previewDayTotals: preview.dayTotals,
        sourceReady: _fullRows != null || preview.totalCount == 0,
        sourceLoading: _sourceLoading,
        sourceError: _error,
        onRetrySource: _retry,
        hideAmounts: widget.hideAmounts,
        flatSurface: true,
        enableVisibilityTracking: true,
        onDateVisibilityChanged: widget.onDateVisibilityChanged,
        controller: widget.controller,
        emptyWidget: widget.emptyWidget);
  }
}
