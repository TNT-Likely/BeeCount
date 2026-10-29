part of '../../ledgers_page_new.dart';

mixin _LedgerOverview on ConsumerState<LedgersPageNew>, _LedgerActions {
  Widget _buildProgressiveList(
      BuildContext context,
      WidgetRef ref,
      int? currentId,
      AsyncValue<List<LedgerDisplayItem>> localAsync,
      AsyncValue<List<LedgerDisplayItem>> remoteAsync) {
    final l = AppLocalizations.of(context);
    final local = localAsync.valueOrNull ?? [];
    final remote = remoteAsync.valueOrNull ?? [];
    if (localAsync.isLoading && local.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (localAsync.hasError && local.isEmpty) {
      return SingleChildScrollView(
          padding: const EdgeInsets.all(17),
          child: BeeStatus(
              tone: BeeTone.error,
              label: l.commonError,
              detail: '${localAsync.error}',
              action: BeeButton(
                  label: l.helpCenterRetry,
                  onPressed: () =>
                      ref.read(ledgerListRefreshProvider.notifier).state++)));
    }
    final beeCloud = ref.watch(activeCloudConfigProvider).valueOrNull?.type ==
        CloudBackendType.beecountCloud;
    final empty = local.isEmpty &&
        remote.isEmpty &&
        !remoteAsync.isLoading &&
        !remoteAsync.hasError;
    return ListView(
        padding: const EdgeInsets.fromLTRB(17, 8, 17, 24),
        children: [
          if (beeCloud) ...[
            BeeSurface(
                padding: EdgeInsets.zero,
                child: BeeMenuRow(
                    title: l.sharedJoinPageTitle,
                    leading: const BeeLineIcon('Users', size: 21),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const JoinSharedLedgerPage())))),
            const SizedBox(height: 12),
          ],
          if (empty) ...[
            BeeEmptyState(
                title: l.ledgersEmpty,
                icon: const BeeLineIcon('BookOpen', size: 32)),
            const SizedBox(height: 16),
          ],
          if (local.isNotEmpty) ...[
            _ledgerSection(l.ledgersLocal, '${local.length}'),
            ...local.map((ledger) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LedgerCard(
                    ledger: ledger,
                    selected: ledger.id == currentId,
                    onTap: () => _handleLocalLedgerTap(ledger),
                    onLongPress: () => _showLocalLedgerActions(context, ledger),
                    onMore: () => _showLocalLedgerActions(context, ledger),
                    onBudget: () => _showLocalLedgerActions(context, ledger,
                        initialAction: 'budget'),
                    onEdit: ledger.myRole == 'owner'
                        ? () => _showLocalLedgerActions(context, ledger,
                            initialAction: 'edit')
                        : null,
                    onMembers: beeCloud && ledger.isShared
                        ? () => _showLocalLedgerActions(context, ledger,
                            initialAction: 'members')
                        : null))),
          ],
          if (remoteAsync.isLoading ||
              remote.isNotEmpty ||
              remoteAsync.hasError) ...[
            _ledgerSection(l.ledgersRemote,
                remoteAsync.isLoading ? null : '${remote.length}',
                action: remote.isNotEmpty
                    ? BeeButton(
                        label: l.ledgersRestoreAll,
                        compact: true,
                        kind: BeeButtonKind.quiet,
                        loading: _isRestoring,
                        icon: const BeeLineIcon('CloudDownload', size: 17),
                        onPressed: _isRestoring
                            ? null
                            : () => _handleBatchRestore(context))
                    : null),
            if (remoteAsync.isLoading)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()))
            else if (remoteAsync.hasError)
              BeeStatus(
                  tone: BeeTone.error,
                  label: l.commonError,
                  detail: '${remoteAsync.error}',
                  action: BeeButton(
                      label: l.helpCenterRetry,
                      onPressed: () =>
                          ref.read(ledgerListRefreshProvider.notifier).state++))
            else
              ...remote.map((ledger) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LedgerCard(
                      ledger: ledger,
                      onTap: () => _handleRemoteLedgerTap(context, ledger),
                      onLongPress: () =>
                          _showRemoteLedgerActions(context, ledger),
                      onMore: () =>
                          _showRemoteLedgerActions(context, ledger)))),
            const SizedBox(height: 12),
          ],
          BeeButton(
              label: l.ledgersNew,
              icon: const BeeLineIcon('Plus', size: 18),
              onPressed: () => _showCreateLedgerDialog(context)),
        ]);
  }

  Widget _ledgerSection(String title, String? count, {Widget? action}) =>
      Padding(
          padding: const EdgeInsets.fromLTRB(3, 8, 3, 12),
          child: Row(children: [
            Expanded(
                child: Text('$title${count == null ? '' : ' · $count'}',
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).hintColor))),
            if (action != null) action,
          ]));
}
