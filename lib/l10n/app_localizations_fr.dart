// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Comptabilité Abeille';

  @override
  String get tabHome => 'Accueil';

  @override
  String get tabAnalytics => 'Graphiques';

  @override
  String get tabLedgers => 'Livres';

  @override
  String get tabMine => 'Mon';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get commonEmpty => 'Aucune donnée';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonSuccess => 'Succès';

  @override
  String get commonFailed => 'Échec';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonPrevious => 'Précédent';

  @override
  String get commonFinish => 'Terminer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonNoteHint => 'Note...';

  @override
  String get commonFilter => 'Filtrer';

  @override
  String get commonClear => 'Effacer';

  @override
  String get commonSelectAll => 'Tout sélectionner';

  @override
  String get commonSettings => 'Paramètres';

  @override
  String get commonHelp => 'Aide';

  @override
  String get commonAbout => 'À propos';

  @override
  String get commonLanguage => 'Langue';

  @override
  String get commonCurrent => 'Actuel';

  @override
  String get commonTutorial => 'Tutoriel';

  @override
  String get commonConfigure => 'Configurer';

  @override
  String get commonWeekdayMonday => 'Lundi';

  @override
  String get commonWeekdayTuesday => 'Mardi';

  @override
  String get commonWeekdayWednesday => 'Mercredi';

  @override
  String get commonWeekdayThursday => 'Jeudi';

  @override
  String get commonWeekdayFriday => 'Vendredi';

  @override
  String get commonWeekdaySaturday => 'Samedi';

  @override
  String get commonWeekdaySunday => 'Dimanche';

  @override
  String get homeTitle => 'Comptabilité Abeille';

  @override
  String get homeIncome => 'Revenus';

  @override
  String get homeExpense => 'Dépenses';

  @override
  String get homeBalance => 'Solde';

  @override
  String get homeTotal => 'Total';

  @override
  String get homeAverage => 'Moyenne';

  @override
  String get homeDailyAvg => 'Moyenne quotidienne';

  @override
  String get homeMonthlyAvg => 'Moyenne mensuelle';

  @override
  String get homeNoRecords => 'Aucun enregistrement';

  @override
  String get homeAddRecord =>
      'Ajouter un enregistrement en appuyant sur le bouton plus';

  @override
  String get homeHideAmounts => 'Masquer les montants';

  @override
  String get homeShowAmounts => 'Afficher les montants';

  @override
  String get homeSelectDate => 'Sélectionner la date';

  @override
  String get homeAppTitle => 'Comptabilité Abeille';

  @override
  String get homeSearch => 'Rechercher';

  @override
  String get homeShowAmount => 'Afficher les montants';

  @override
  String get homeHideAmount => 'Masquer les montants';

  @override
  String homeYear(int year) {
    return '$year';
  }

  @override
  String homeMonth(String month) {
    return '${month}M';
  }

  @override
  String get homeNoRecordsSubtext =>
      'Appuyez sur le bouton plus en bas pour ajouter un enregistrement';

  @override
  String get widgetTodayExpense => 'Dépense d\'Aujourd\'hui';

  @override
  String get widgetTodayIncome => 'Revenu d\'Aujourd\'hui';

  @override
  String get widgetMonthExpense => 'Dépense du Mois';

  @override
  String get widgetMonthIncome => 'Revenu du Mois';

  @override
  String get widgetMonthSuffix => '';

  @override
  String get searchTitle => 'Rechercher';

  @override
  String get searchHint => 'Rechercher notes, catégories ou montants...';

  @override
  String get searchAmountRange => 'Filtre de plage de montant';

  @override
  String get searchMinAmount => 'Montant minimum';

  @override
  String get searchMaxAmount => 'Montant maximum';

  @override
  String get searchTo => 'à';

  @override
  String get searchNoInput =>
      'Entrez des mots-clés pour commencer la recherche';

  @override
  String get searchNoResults => 'Aucun résultat correspondant trouvé';

  @override
  String get searchResultsEmpty => 'Aucun résultat correspondant trouvé';

  @override
  String get searchResultsEmptyHint =>
      'Essayez d\'autres mots-clés ou ajustez les conditions de filtre';

  @override
  String get searchBatchMode => 'Opérations groupées';

  @override
  String searchBatchModeWithCount(Object selected, Object total) {
    return 'Opérations groupées ($selected/$total)';
  }

  @override
  String get searchExitBatchMode => 'Quitter les opérations groupées';

  @override
  String get searchSelectAll => 'Tout sélectionner';

  @override
  String get searchDeselectAll => 'Tout désélectionner';

  @override
  String searchSelectedCount(Object count) {
    return '$count sélectionné(s)';
  }

  @override
  String get searchBatchSetNote => 'Définir une note';

  @override
  String get searchBatchChangeCategory => 'Changer de catégorie';

  @override
  String get searchBatchDeleteConfirmTitle => 'Confirmer la suppression';

  @override
  String searchBatchDeleteConfirmMessage(Object count) {
    return 'Voulez-vous vraiment supprimer les $count transactions sélectionnées?\nCette action ne peut pas être annulée.';
  }

  @override
  String get searchBatchSetNoteTitle => 'Définir une note groupée';

  @override
  String searchBatchSetNoteMessage(Object count) {
    return 'Définir la même note pour les $count transactions sélectionnées';
  }

  @override
  String get searchBatchSetNoteHint =>
      'Saisir le contenu de la note (laisser vide pour effacer les notes)';

  @override
  String get searchBatchChangeCategoryTitle => 'Changer de catégorie groupée';

  @override
  String searchBatchChangeCategoryMessage(Object count) {
    return 'Définir une nouvelle catégorie pour les $count transactions sélectionnées';
  }

  @override
  String get searchBatchChangeCategoryLabel => 'Sélectionner une catégorie';

  @override
  String searchBatchDeleteSuccess(Object count) {
    return '$count transactions supprimées avec succès';
  }

  @override
  String searchBatchDeleteFailed(Object error) {
    return 'Échec de la suppression: $error';
  }

  @override
  String searchBatchSetNoteSuccess(Object count) {
    return 'Note définie avec succès pour $count transactions';
  }

  @override
  String searchBatchSetNoteFailed(Object error) {
    return 'Échec de la définition de la note: $error';
  }

  @override
  String searchBatchChangeCategorySuccess(Object count) {
    return 'Catégorie modifiée avec succès pour $count transactions';
  }

  @override
  String searchBatchChangeCategoryFailed(Object error) {
    return 'Échec du changement de catégorie: $error';
  }

  @override
  String searchResultsCount(Object count) {
    return '$count résultat(s)';
  }

  @override
  String get analyticsTitle => 'Analyses';

  @override
  String get analyticsMonth => 'Mois';

  @override
  String get analyticsYear => 'Année';

  @override
  String get analyticsAll => 'Tout';

  @override
  String get analyticsSummary => 'Résumé';

  @override
  String get analyticsCategoryRanking => 'Classement par Catégories';

  @override
  String get analyticsCurrentPeriod => 'Période Actuelle';

  @override
  String get analyticsNoDataSubtext =>
      'Glissez à gauche/droite pour changer de période, ou appuyez pour basculer revenus/dépenses';

  @override
  String get analyticsSwipeHint =>
      'Glissez à gauche/droite pour changer de période';

  @override
  String get analyticsTipContent =>
      '1) Glissez à gauche/droite en bas pour basculer Dépenses/Revenus/Solde\\n2) Glissez à gauche/droite dans la zone graphique pour changer de période';

  @override
  String analyticsSwitchTo(String type) {
    return 'Basculer vers $type';
  }

  @override
  String get analyticsTipHeader =>
      'Astuce : La capsule en haut peut basculer Mois/Année/Tout';

  @override
  String get analyticsSwipeToSwitch => 'Glisser pour changer';

  @override
  String get analyticsAllYears => 'Toutes les Années';

  @override
  String get analyticsToday => 'Aujourd\'hui';

  @override
  String get splashAppName => 'Comptabilité Abeille';

  @override
  String get splashSlogan => 'Chaque Centime Compte';

  @override
  String get splashSecurityTitle => 'Sécurité des Données Open Source';

  @override
  String get splashSecurityFeature1 =>
      '• Stockage local des données, contrôle total de la confidentialité';

  @override
  String get splashSecurityFeature2 =>
      '• Code source transparent, sécurité fiable';

  @override
  String get splashSecurityFeature3 =>
      '• Synchronisation cloud optionnelle, données cohérentes sur tous les appareils';

  @override
  String get splashInitializing => 'Initialisation des données...';

  @override
  String get ledgersTitle => 'Livres de comptes';

  @override
  String get ledgersNew => 'Nouveau Livre';

  @override
  String get ledgersClear => 'Effacer le Livre Actuel';

  @override
  String get ledgersClearConfirm => 'Effacer le livre actuel ?';

  @override
  String ledgersClearMessage(Object name) {
    return 'Toutes les transactions dans ce livre seront supprimées et ne pourront pas être récupérées.';
  }

  @override
  String get ledgersEdit => 'Modifier le livre';

  @override
  String get ledgersDelete => 'Supprimer le livre';

  @override
  String get ledgersDeleteConfirm =>
      'Êtes-vous sûr de vouloir supprimer ce livre ?';

  @override
  String get ledgersDeleteMessage =>
      'Êtes-vous sûr de vouloir supprimer ce livre et tous ses enregistrements ? Cette action ne peut pas être annulée.\\nSi une sauvegarde existe dans le cloud, elle sera également supprimée.';

  @override
  String get ledgersDeleted => 'Supprimé';

  @override
  String get ledgersDeleteFailed => 'Échec de la suppression';

  @override
  String get ledgersClearTitle => 'Clear Ledger';

  @override
  String get ledgersClearSuccess => 'Ledger cleared';

  @override
  String get ledgersDeleteLocal => 'Delete Local Ledger Only';

  @override
  String get ledgersDeleteLocalTitle => 'Delete Local Ledger';

  @override
  String ledgersDeleteLocalMessage(Object name) {
    return 'Are you sure to delete local ledger \"$name\"?\\nCloud backup will be kept and you can restore it anytime.';
  }

  @override
  String get ledgersDeleteLocalSuccess => 'Local ledger deleted';

  @override
  String ledgersRecordsDeleted(int count) {
    return 'Suppression de $count enregistrements';
  }

  @override
  String get ledgersName => 'Nom du livre';

  @override
  String get ledgersDefaultLedgerName => 'Livre par Défaut';

  @override
  String get ledgersDefaultAccountName => 'Espèces';

  @override
  String get accountTitle => 'Compte';

  @override
  String get ledgersCurrency => 'Devise';

  @override
  String get ledgersSelectCurrency => 'Sélectionner la devise';

  @override
  String get ledgersSearchCurrency => 'Rechercher : Chinois ou code';

  @override
  String get ledgersCreate => 'Créer';

  @override
  String get ledgersActions => 'Actions';

  @override
  String ledgersRecords(String count) {
    return 'Enregistrements : $count';
  }

  @override
  String ledgersBalance(String balance) {
    return 'Solde : $balance';
  }

  @override
  String get ledgerCardTransactions => 'transactions';

  @override
  String get ledgerCardRemoteOnly => 'Cloud only';

  @override
  String get ledgerCardDownloadCloud => 'Download from Cloud';

  @override
  String get ledgerCardJustNow => 'Just now';

  @override
  String ledgerCardMinutesAgo(int minutes) {
    return '$minutes minutes ago';
  }

  @override
  String ledgerCardHoursAgo(int hours) {
    return '$hours hours ago';
  }

  @override
  String ledgerCardDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get ledgersLocal => 'Local Ledgers';

  @override
  String get ledgersRemote => 'Cloud Ledgers';

  @override
  String get ledgersEmpty => 'No ledgers';

  @override
  String get ledgersRestoreAll => 'Restore All';

  @override
  String ledgersSwitched(String name) {
    return 'Switched to ledger \"$name\"';
  }

  @override
  String get ledgersDownloadTitle => 'Download Ledger';

  @override
  String ledgersDownloadMessage(String name) {
    return 'Confirm download ledger \"$name\" to local?';
  }

  @override
  String get ledgersDownloading => 'Downloading...';

  @override
  String ledgersDownloadSuccess(String name) {
    return 'Ledger \"$name\" downloaded successfully';
  }

  @override
  String get ledgersDownload => 'Download';

  @override
  String get ledgersDeleteRemote => 'Delete Cloud Ledger';

  @override
  String get ledgersDeleteRemoteConfirm => 'Delete Cloud Ledger';

  @override
  String ledgersDeleteRemoteMessage(String name) {
    return 'Confirm delete cloud ledger \"$name\"? This action cannot be undone.';
  }

  @override
  String get ledgersDeleting => 'Deleting...';

  @override
  String get ledgersDeleteRemoteSuccess => 'Cloud ledger deleted';

  @override
  String get ledgersRestoreAllTitle => 'Batch Restore';

  @override
  String ledgersRestoreAllMessage(int count) {
    return 'Confirm restore all cloud ledgers? Total $count.';
  }

  @override
  String get ledgersRestoring => 'Restoring...';

  @override
  String get ledgersRestoreComplete => 'Restore Complete';

  @override
  String ledgersRestoreResult(int success, int failed) {
    return 'Success: $success, Failed: $failed';
  }

  @override
  String get categoryTitle => 'Gestion des Catégories';

  @override
  String get categoryNew => 'Nouvelle Catégorie';

  @override
  String get categoryExpense => 'Catégories de Dépenses';

  @override
  String get categoryIncome => 'Catégories de Revenus';

  @override
  String get categoryEmpty => 'Aucune catégorie';

  @override
  String get categoryDefault => 'Catégorie par Défaut';

  @override
  String get categoryCustomTag => 'Personnalisé';

  @override
  String get categoryReorderTip =>
      'Appui long pour faire glisser et réorganiser les catégories';

  @override
  String categoryLoadFailed(String error) {
    return 'Échec du chargement : $error';
  }

  @override
  String get iconPickerTitle => 'Sélectionner l\'Icône';

  @override
  String get iconCategoryFood => 'Nourriture';

  @override
  String get iconCategoryTransport => 'Transport';

  @override
  String get iconCategoryShopping => 'Shopping';

  @override
  String get iconCategoryEntertainment => 'Divertissement';

  @override
  String get iconCategoryLife => 'Vie';

  @override
  String get iconCategoryHealth => 'Santé';

  @override
  String get iconCategoryEducation => 'Éducation';

  @override
  String get iconCategoryWork => 'Travail';

  @override
  String get iconCategoryFinance => 'Finance';

  @override
  String get iconCategoryReward => 'Récompense';

  @override
  String get iconCategoryOther => 'Autre';

  @override
  String get iconCategoryDining => 'Restaurant';

  @override
  String get importTitle => 'Importer des Factures';

  @override
  String get importSelectFile =>
      'Veuillez sélectionner un fichier à importer (CSV/TSV/XLSX supportés)';

  @override
  String get importBillType => 'Type de Facture';

  @override
  String get importBillTypeGeneric => 'CSV Générique';

  @override
  String get importBillTypeAlipay => 'Alipay';

  @override
  String get importBillTypeWechat => 'WeChat';

  @override
  String get importChooseFile => 'Choisir un Fichier';

  @override
  String get importNoFileSelected => 'Aucun fichier sélectionné';

  @override
  String get importHint =>
      'Conseil : Veuillez sélectionner un fichier pour commencer l\'importation (CSV/TSV/XLSX)';

  @override
  String get importReading => 'Lecture du fichier…';

  @override
  String get importPreparing => 'Préparation…';

  @override
  String importColumnNumber(Object number) {
    return 'Colonne $number';
  }

  @override
  String get importConfirmMapping => 'Confirmer la Correspondance';

  @override
  String get importCategoryMapping => 'Correspondance des Catégories';

  @override
  String get importNoDataParsed =>
      'Aucune donnée analysée, veuillez retourner à la page précédente pour vérifier le contenu CSV ou le séparateur.';

  @override
  String get importFieldDate => 'Date';

  @override
  String get importFieldType => 'Type';

  @override
  String get importFieldAmount => 'Montant';

  @override
  String get importFieldCategory => 'Catégorie';

  @override
  String get importFieldAccount => 'Compte';

  @override
  String get importFieldNote => 'Note';

  @override
  String get importPreview => 'Aperçu : ';

  @override
  String importPreviewLimit(Object shown, Object total) {
    return 'Affiche les $shown premiers enregistrements sur $total';
  }

  @override
  String get importCategoryNotSelected =>
      'Catégorie non sélectionnée, veuillez retourner à l\'étape précédente et définir la colonne de catégorie.';

  @override
  String get importCategoryMappingDescription =>
      'Veuillez faire correspondre les noms de catégories sources avec les catégories existantes (ou conserver le nom d\'origine pour créer/fusionner automatiquement)';

  @override
  String get importKeepOriginalName =>
      'Conserver le nom d\'origine (créer/fusionner automatiquement)';

  @override
  String importProgress(Object fail, Object ok) {
    return 'Importation en cours… réussi $ok, échoué $fail';
  }

  @override
  String get importCancelImport => 'Annuler l\'Importation';

  @override
  String get importCompleteTitle => 'Importation Terminée';

  @override
  String importCompletedCount(Object count) {
    return '$count enregistrements importés avec succès';
  }

  @override
  String get importFailed => 'Importation Échouée';

  @override
  String importFailedMessage(Object error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String get importSelectCategoryFirst =>
      'Veuillez d\'abord sélectionner la correspondance des catégories';

  @override
  String get importNextStep => 'Étape Suivante';

  @override
  String get importPreviousStep => 'Étape Précédente';

  @override
  String get importStartImport => 'Démarrer l\'Importation';

  @override
  String get importAutoDetect => 'Auto-détection';

  @override
  String get importInProgress => 'Importation en Cours';

  @override
  String importProgressDetail(
      Object done, Object fail, Object ok, Object total) {
    return 'Terminé : $done/$total, réussi $ok, échoué $fail';
  }

  @override
  String get importBackgroundImport => 'Importation en Arrière-plan';

  @override
  String get importCancelled => '(Annulé)';

  @override
  String importCompleted(Object cancelled, Object fail, Object ok) {
    return 'Importation terminée$cancelled : réussi $ok, échoué $fail';
  }

  @override
  String importSkippedNonTransactionTypes(Object count) {
    return '$count enregistrements non-transaction ignorés (transferts, dettes, etc.)';
  }

  @override
  String importTransactionFailed(Object error) {
    return 'Échec de l\'importation, toutes les modifications ont été annulées : $error';
  }

  @override
  String importFileOpenError(String error) {
    return 'Impossible d\'ouvrir le sélecteur de fichiers : $error';
  }

  @override
  String get mineTitle => 'Mon';

  @override
  String get mineSettings => 'Paramètres';

  @override
  String get mineTheme => 'Thème';

  @override
  String get mineFont => 'Paramètres de Police';

  @override
  String get mineReminder => 'Paramètres de Rappel';

  @override
  String get mineData => 'Gestion des Données';

  @override
  String get mineImport => 'Importer';

  @override
  String get mineExport => 'Exporter';

  @override
  String get mineCloud => 'Service Cloud';

  @override
  String get mineAbout => 'À propos';

  @override
  String get mineVersion => 'Version';

  @override
  String get mineUpdate => 'Mettre à jour';

  @override
  String get mineLanguageSettings => 'Paramètres de Langue';

  @override
  String get mineLanguageSettingsSubtitle =>
      'Changer la langue de l\'application';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => 'Suivre le système';

  @override
  String get deleteConfirmTitle => 'Confirmer la Suppression';

  @override
  String get deleteConfirmMessage =>
      'Êtes-vous sûr de vouloir supprimer cet enregistrement ?';

  @override
  String get logCopied => 'Journal copié';

  @override
  String get waitingRestore =>
      'En attente du démarrage de la tâche de restauration…';

  @override
  String get restoreTitle => 'Restauration Cloud';

  @override
  String get copyLog => 'Copier le Journal';

  @override
  String restoreProgress(Object current, Object total) {
    return 'Restauration ($current/$total)';
  }

  @override
  String get restorePreparing => 'Préparation…';

  @override
  String restoreLedgerProgress(String ledger, int done, int total) {
    return 'Livre : $ledger  Enregistrements : $done/$total';
  }

  @override
  String get mineSlogan => 'Comptabilité Abeille, Chaque Centime Compte';

  @override
  String get mineAvatarTitle => 'Avatar Settings';

  @override
  String get mineAvatarFromGallery => 'Choose from Gallery';

  @override
  String get mineAvatarFromCamera => 'Take Photo';

  @override
  String get mineAvatarDelete => 'Delete Avatar';

  @override
  String get mineShareApp => 'Share App';

  @override
  String get mineShareAppSubtitle =>
      'Generate share poster and save to gallery';

  @override
  String get mineShareGenerating => 'Generating share poster...';

  @override
  String get mineShareSuccess => 'Saved Successfully';

  @override
  String get mineShareSuccessMessage =>
      'Share poster has been saved to gallery';

  @override
  String get mineShareFailed => 'Save failed, please check gallery permissions';

  @override
  String get sharePosterAppName => 'BeeCount';

  @override
  String get sharePosterSlogan => 'Smart Accounting, Beautiful Life';

  @override
  String get sharePosterFeature1 => '✨ Completely Open Source & Free';

  @override
  String get sharePosterFeature2 => '🤖 AI Smart Bill Recognition';

  @override
  String get sharePosterFeature3 => '⚡ Automated Accounting';

  @override
  String get sharePosterFeature4 => '🔒 Privacy & Security';

  @override
  String get sharePosterFeature5 => '☁️ Cloud Sync & Backup';

  @override
  String get sharePosterFeature6 => '📊 Multiple Ledgers';

  @override
  String get sharePosterScanText => 'Scan to visit open source project';

  @override
  String get sharePosterPreviewTitle => 'Share Poster Preview';

  @override
  String get sharePosterSave => 'Save to Gallery';

  @override
  String get sharePosterShare => 'Share';

  @override
  String get sharePosterSaveSuccess => 'Saved to gallery';

  @override
  String get sharePosterSaveFailed => 'Failed to save';

  @override
  String get sharePosterPermissionDenied =>
      'Gallery permission denied, please enable in settings';

  @override
  String get mineDaysCount => 'Jours de Comptabilité';

  @override
  String get mineTotalRecords => 'Total d\'Enregistrements';

  @override
  String get mineCurrentBalance => 'Solde Actuel';

  @override
  String get mineCloudService => 'Service Cloud';

  @override
  String get mineCloudServiceLoading => 'Chargement…';

  @override
  String mineCloudServiceError(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get mineCloudServiceDefault => 'Service Cloud par Défaut (Activé)';

  @override
  String get mineCloudServiceOffline => 'Mode par Défaut (Hors ligne)';

  @override
  String get mineCloudServiceCustom => 'Supabase Personnalisé';

  @override
  String get mineCloudServiceWebDAV => 'Service Cloud Personnalisé (WebDAV)';

  @override
  String get mineSyncTitle => 'Synchronisation';

  @override
  String get mineSyncNotLoggedIn => 'Non connecté';

  @override
  String get mineSyncNotConfigured => 'Cloud non configuré';

  @override
  String get mineSyncNoRemote => 'Aucune sauvegarde cloud';

  @override
  String mineSyncInSync(Object count) {
    return 'Synchronisé ($count enregistrements locaux)';
  }

  @override
  String get mineSyncInSyncSimple => 'Synchronisé';

  @override
  String mineSyncLocalNewer(Object count) {
    return 'Local plus récent ($count enregistrements locaux, téléversement recommandé)';
  }

  @override
  String get mineSyncLocalNewerSimple => 'Local plus récent';

  @override
  String get mineSyncCloudNewer =>
      'Cloud plus récent (téléchargement et fusion recommandés)';

  @override
  String get mineSyncCloudNewerSimple => 'Cloud plus récent';

  @override
  String get mineSyncDifferent => 'Local et cloud différents';

  @override
  String get mineSyncError => 'Échec d\'obtention du statut';

  @override
  String get mineSyncDetailTitle => 'Détails du Statut de Synchronisation';

  @override
  String mineSyncLocalRecords(Object count) {
    return 'Enregistrements locaux : $count';
  }

  @override
  String mineSyncCloudRecords(Object count) {
    return 'Enregistrements cloud : $count';
  }

  @override
  String mineSyncCloudLatest(Object time) {
    return 'Heure du dernier enregistrement cloud : $time';
  }

  @override
  String mineSyncLocalFingerprint(Object fingerprint) {
    return 'Empreinte locale : $fingerprint';
  }

  @override
  String mineSyncCloudFingerprint(Object fingerprint) {
    return 'Empreinte cloud : $fingerprint';
  }

  @override
  String mineSyncMessage(Object message) {
    return 'Message : $message';
  }

  @override
  String get mineUploadTitle => 'Téléverser';

  @override
  String get mineUploadNeedLogin => 'Connexion requise';

  @override
  String get mineUploadNeedCloudService =>
      'Disponible uniquement en mode service cloud';

  @override
  String get mineUploadInProgress => 'Téléversement en cours…';

  @override
  String get mineUploadRefreshing => 'Actualisation…';

  @override
  String get mineUploadSynced => 'Synchronisé';

  @override
  String get mineUploadSuccess => 'Téléversé';

  @override
  String get mineUploadSuccessMessage =>
      'Livre actuel synchronisé vers le cloud';

  @override
  String get mineDownloadTitle => 'Télécharger';

  @override
  String get mineDownloadNeedCloudService =>
      'Disponible uniquement en mode service cloud';

  @override
  String get mineDownloadComplete => 'Terminé';

  @override
  String mineDownloadResult(Object deleted, Object inserted, Object skipped) {
    return 'Nouvelles importations : $inserted\nExistantes ignorées : $skipped\nDoublons nettoyés : $deleted';
  }

  @override
  String get mineLoginTitle => 'Connexion / Inscription';

  @override
  String get mineLoginSubtitle =>
      'Nécessaire uniquement pour la synchronisation';

  @override
  String get mineLoggedInEmail => 'Connecté';

  @override
  String get mineLogoutSubtitle => 'Appuyez pour vous déconnecter';

  @override
  String get mineLogoutConfirmTitle => 'Déconnexion';

  @override
  String get mineLogoutConfirmMessage =>
      'Êtes-vous sûr de vouloir vous déconnecter ?\nVous ne pourrez pas utiliser la synchronisation cloud après la déconnexion.';

  @override
  String get mineLogoutButton => 'Déconnexion';

  @override
  String get mineAutoSyncTitle => 'Synchronisation automatique du livre';

  @override
  String get mineAutoSyncSubtitle =>
      'Téléversement automatique vers le cloud après enregistrement';

  @override
  String get mineAutoSyncNeedLogin => 'Connexion requise pour activer';

  @override
  String get mineAutoSyncNeedCloudService =>
      'Disponible uniquement en mode service cloud';

  @override
  String get mineImportProgressTitle => 'Importation en arrière-plan…';

  @override
  String mineImportProgressSubtitle(
      Object done, Object fail, Object ok, Object total) {
    return 'Progression : $done/$total, Réussi $ok, Échoué $fail';
  }

  @override
  String get mineImportCompleteTitle => 'Importation terminée';

  @override
  String mineImportCompleteSubtitle(Object fail, Object ok) {
    return 'Réussi $ok, Échoué $fail';
  }

  @override
  String get mineCategoryManagement => 'Gestion des Catégories';

  @override
  String get mineCategoryManagementSubtitle =>
      'Modifier les catégories personnalisées';

  @override
  String get mineCategoryMigration => 'Migration de Catégories';

  @override
  String get mineCategoryMigrationSubtitle =>
      'Migrer les données de catégorie vers d\'autres catégories';

  @override
  String get mineRecurringTransactions => 'Factures Récurrentes';

  @override
  String get mineRecurringTransactionsSubtitle =>
      'Gérer les factures récurrentes';

  @override
  String get mineReminderSettings => 'Rappels de Comptabilité';

  @override
  String get mineReminderSettingsSubtitle =>
      'Définir les rappels quotidiens de comptabilité';

  @override
  String get minePersonalize => 'Personnalisation';

  @override
  String get mineDisplayScale => 'Échelle d\'Affichage';

  @override
  String get mineDisplayScaleSubtitle =>
      'Ajuster la taille du texte et des éléments d\'interface';

  @override
  String get mineAboutTitle => 'À Propos';

  @override
  String mineAboutMessage(Object version) {
    return 'Application : Comptabilité Abeille\nVersion : $version\nCode source : https://github.com/TNT-Likely/BeeCount\nLicence : Voir LICENSE dans le dépôt';
  }

  @override
  String get mineAboutOpenGitHub => 'Ouvrir GitHub';

  @override
  String get mineCheckUpdate => 'Vérifier les Mises à Jour';

  @override
  String get mineCheckUpdateInProgress => 'Vérification des mises à jour...';

  @override
  String get mineCheckUpdateSubtitle => 'Vérification de la dernière version';

  @override
  String get mineUpdateDownload => 'Télécharger la Mise à Jour';

  @override
  String get mineFeedback => 'Commentaires';

  @override
  String get mineFeedbackSubtitle => 'Signaler un problème ou une suggestion';

  @override
  String get mineHelp => 'Aide';

  @override
  String get mineHelpSubtitle => 'Voir la documentation et FAQ';

  @override
  String get mineSupportAuthor => 'Soutenir l\'auteur';

  @override
  String get mineSupportAuthorSubtitle =>
      'Ajouter une étoile au projet sur GitHub';

  @override
  String get mineRefreshStats => 'Actualiser les Statistiques (Debug)';

  @override
  String get mineRefreshStatsSubtitle =>
      'Déclencher le recalcul du provider de statistiques global';

  @override
  String get mineRefreshSync => 'Actualiser le Statut de Synchro (Debug)';

  @override
  String get mineRefreshSyncSubtitle =>
      'Déclencher l\'actualisation du provider de statut de synchronisation';

  @override
  String get categoryEditTitle => 'Modifier la Catégorie';

  @override
  String get categoryNewTitle => 'Nouvelle Catégorie';

  @override
  String get categoryDetailTooltip => 'Détails de la Catégorie';

  @override
  String get categoryMigrationTooltip => 'Migration de Catégorie';

  @override
  String get categoryMigrationTitle => 'Migration de Catégorie';

  @override
  String get categoryMigrationDescription =>
      'Instructions de Migration de Catégorie';

  @override
  String get categoryMigrationDescriptionContent =>
      '• Migrer tous les enregistrements de transaction d\'une catégorie vers une autre\n• Après migration, toutes les données de transaction de la catégorie source seront transférées vers la catégorie cible\n• Cette opération ne peut pas être annulée, veuillez choisir avec prudence';

  @override
  String get categoryMigrationFromLabel => 'Catégorie Source';

  @override
  String get categoryMigrationFromHint => 'Sélectionner la catégorie à migrer';

  @override
  String get categoryMigrationToLabel => 'Catégorie Cible';

  @override
  String get categoryMigrationToHint => 'Sélectionner la catégorie cible';

  @override
  String get categoryMigrationToHintFirst =>
      'Veuillez d\'abord sélectionner la catégorie source';

  @override
  String get categoryMigrationStartButton => 'Démarrer la Migration';

  @override
  String categoryMigrationTransactionCount(int count) {
    return '$count enregistrements';
  }

  @override
  String get categoryMigrationCannotTitle => 'Impossible de Migrer';

  @override
  String get categoryMigrationCannotMessage =>
      'Les catégories sélectionnées ne peuvent pas être migrées, veuillez vérifier l\'état de la catégorie.';

  @override
  String get categoryExpenseType => 'Catégorie de Dépense';

  @override
  String get categoryIncomeType => 'Catégorie de Revenu';

  @override
  String get categoryDefaultTitle => 'Catégorie par Défaut';

  @override
  String get categoryDefaultMessage =>
      'Les catégories par défaut ne peuvent pas être modifiées, mais vous pouvez consulter les détails et migrer les données';

  @override
  String get categoryNameDining => 'Restaurant';

  @override
  String get categoryNameTransport => 'Transport';

  @override
  String get categoryNameShopping => 'Shopping';

  @override
  String get categoryNameEntertainment => 'Divertissement';

  @override
  String get categoryNameHome => 'Maison';

  @override
  String get categoryNameFamily => 'Famille';

  @override
  String get categoryNameCommunication => 'Communication';

  @override
  String get categoryNameUtilities => 'Services Publics';

  @override
  String get categoryNameHousing => 'Logement';

  @override
  String get categoryNameMedical => 'Médical';

  @override
  String get categoryNameEducation => 'Éducation';

  @override
  String get categoryNamePets => 'Animaux';

  @override
  String get categoryNameSports => 'Sport';

  @override
  String get categoryNameDigital => 'Numérique';

  @override
  String get categoryNameTravel => 'Voyage';

  @override
  String get categoryNameAlcoholTobacco => 'Alcool et Tabac';

  @override
  String get categoryNameBabyCare => 'Soins Bébé';

  @override
  String get categoryNameBeauty => 'Beauté';

  @override
  String get categoryNameRepair => 'Réparation';

  @override
  String get categoryNameSocial => 'Social';

  @override
  String get categoryNameLearning => 'Apprentissage';

  @override
  String get categoryNameCar => 'Voiture';

  @override
  String get categoryNameTaxi => 'Taxi';

  @override
  String get categoryNameSubway => 'Métro';

  @override
  String get categoryNameDelivery => 'Livraison';

  @override
  String get categoryNameProperty => 'Propriété';

  @override
  String get categoryNameParking => 'Stationnement';

  @override
  String get categoryNameDonation => 'Don';

  @override
  String get categoryNameGift => 'Cadeau';

  @override
  String get categoryNameTax => 'Impôt';

  @override
  String get categoryNameBeverage => 'Boisson';

  @override
  String get categoryNameClothing => 'Vêtements';

  @override
  String get categoryNameSnacks => 'Collations';

  @override
  String get categoryNameRedPacket => 'Enveloppe Rouge';

  @override
  String get categoryNameFruit => 'Fruits';

  @override
  String get categoryNameGame => 'Jeu';

  @override
  String get categoryNameBook => 'Livre';

  @override
  String get categoryNameLover => 'Partenaire';

  @override
  String get categoryNameDecoration => 'Décoration';

  @override
  String get categoryNameDailyGoods => 'Articles Quotidiens';

  @override
  String get categoryNameLottery => 'Loterie';

  @override
  String get categoryNameStock => 'Actions';

  @override
  String get categoryNameSocialSecurity => 'Sécurité Sociale';

  @override
  String get categoryNameExpress => 'Express';

  @override
  String get categoryNameWork => 'Travail';

  @override
  String get categoryNameSalary => 'Salaire';

  @override
  String get categoryNameInvestment => 'Investissement';

  @override
  String get categoryNameBonus => 'Bonus';

  @override
  String get categoryNameReimbursement => 'Remboursement';

  @override
  String get categoryNamePartTime => 'Temps Partiel';

  @override
  String get categoryNameInterest => 'Intérêt';

  @override
  String get categoryNameRefund => 'Remboursement';

  @override
  String get categoryNameSecondHand => 'Vente d\'Occasion';

  @override
  String get categoryNameSocialBenefit => 'Aide Sociale';

  @override
  String get categoryNameTaxRefund => 'Remboursement d\'Impôt';

  @override
  String get categoryNameProvidentFund => 'Fonds de Prévoyance';

  @override
  String get categoryNameLabel => 'Nom de la Catégorie';

  @override
  String get categoryNameHint => 'Entrer le nom de la catégorie';

  @override
  String get categoryNameHintDefault =>
      'Le nom de catégorie par défaut ne peut pas être modifié';

  @override
  String get categoryNameRequired => 'Veuillez entrer le nom de la catégorie';

  @override
  String get categoryNameTooLong =>
      'Le nom de catégorie ne peut pas dépasser 4 caractères';

  @override
  String get categoryIconLabel => 'Icône de Catégorie';

  @override
  String get categoryIconDefaultMessage =>
      'L\'icône de catégorie par défaut ne peut pas être modifiée';

  @override
  String get categoryDangerousOperations => 'Opérations Dangereuses';

  @override
  String get categoryDeleteTitle => 'Supprimer la Catégorie';

  @override
  String get categoryDeleteSubtitle =>
      'Impossible de récupérer après suppression';

  @override
  String get categoryDefaultCannotSave =>
      'La catégorie par défaut ne peut pas être enregistrée';

  @override
  String get categorySaveError => 'Échec de l\'enregistrement';

  @override
  String categoryUpdated(Object name) {
    return 'Catégorie \"$name\" mise à jour';
  }

  @override
  String categoryCreated(Object name) {
    return 'Catégorie \"$name\" créée';
  }

  @override
  String get categoryCannotDelete => 'Impossible de supprimer';

  @override
  String categoryCannotDeleteMessage(Object count) {
    return 'Cette catégorie a $count enregistrements de transaction, veuillez les traiter d\'abord.';
  }

  @override
  String get categoryDeleteConfirmTitle => 'Supprimer la Catégorie';

  @override
  String categoryDeleteConfirmMessage(Object name) {
    return 'Êtes-vous sûr de vouloir supprimer la catégorie \"$name\" ? Cette action ne peut pas être annulée.';
  }

  @override
  String get categoryDeleteError => 'Échec de la suppression';

  @override
  String categoryDeleted(Object name) {
    return 'Catégorie \"$name\" supprimée';
  }

  @override
  String get personalizeTitle => 'Personnaliser';

  @override
  String get personalizeCustomColor => 'Choisir une couleur personnalisée';

  @override
  String get personalizeCustomTitle => 'Personnalisé';

  @override
  String personalizeHue(Object value) {
    return 'Teinte ($value°)';
  }

  @override
  String personalizeSaturation(Object value) {
    return 'Saturation ($value%)';
  }

  @override
  String personalizeBrightness(Object value) {
    return 'Luminosité ($value%)';
  }

  @override
  String get personalizeSelectColor => 'Sélectionner cette couleur';

  @override
  String get fontSettingsTitle => 'Échelle d\'Affichage';

  @override
  String fontSettingsCurrentScale(Object scale) {
    return 'Échelle actuelle : x$scale';
  }

  @override
  String get fontSettingsPreview => 'Aperçu en Direct';

  @override
  String get fontSettingsPreviewText =>
      'J\'ai dépensé 23,50 € pour le déjeuner aujourd\'hui, noter ;\nEnregistré pendant 45 jours ce mois, 320 entrées ;\nLa persévérance est la victoire !';

  @override
  String fontSettingsCurrentLevel(Object level, Object scale) {
    return 'Niveau actuel : $level (échelle x$scale)';
  }

  @override
  String get fontSettingsQuickLevel => 'Niveaux Rapides';

  @override
  String get fontSettingsCustomAdjust => 'Ajustement Personnalisé';

  @override
  String get fontSettingsDescription =>
      'Note : Ce paramètre garantit un affichage cohérent à 1,0x sur tous les appareils, avec compensation automatique des différences ; ajustez les valeurs pour une mise à l\'échelle personnalisée.';

  @override
  String get fontSettingsExtraSmall => 'Très Petit';

  @override
  String get fontSettingsVerySmall => 'Très Petit';

  @override
  String get fontSettingsSmall => 'Petit';

  @override
  String get fontSettingsStandard => 'Standard';

  @override
  String get fontSettingsLarge => 'Grand';

  @override
  String get fontSettingsBig => 'Gros';

  @override
  String get fontSettingsVeryBig => 'Très Gros';

  @override
  String get fontSettingsExtraBig => 'Extrêmement Gros';

  @override
  String get fontSettingsMoreStyles => 'Plus de Styles';

  @override
  String get fontSettingsPageTitle => 'Titre de Page';

  @override
  String get fontSettingsBlockTitle => 'Titre de Bloc';

  @override
  String get fontSettingsBodyExample => 'Texte de Corps';

  @override
  String get fontSettingsLabelExample => 'Texte d\'Étiquette';

  @override
  String get fontSettingsStrongNumber => 'Nombre Fort';

  @override
  String get fontSettingsListTitle => 'Titre d\'Élément de Liste';

  @override
  String get fontSettingsListSubtitle => 'Texte d\'Aide';

  @override
  String get fontSettingsScreenInfo => 'Info d\'Adaptation d\'Écran';

  @override
  String get fontSettingsScreenDensity => 'Densité d\'Écran';

  @override
  String get fontSettingsScreenWidth => 'Largeur d\'Écran';

  @override
  String get fontSettingsDeviceScale => 'Échelle de l\'Appareil';

  @override
  String get fontSettingsUserScale => 'Échelle Utilisateur';

  @override
  String get fontSettingsFinalScale => 'Échelle Finale';

  @override
  String get fontSettingsBaseDevice => 'Appareil de Base';

  @override
  String get fontSettingsRecommendedScale => 'Échelle Recommandée';

  @override
  String get fontSettingsYes => 'Oui';

  @override
  String get fontSettingsNo => 'Non';

  @override
  String get fontSettingsScaleExample =>
      'Cette boîte et l\'espacement s\'adaptent automatiquement selon l\'appareil';

  @override
  String get fontSettingsPreciseAdjust => 'Ajustement Précis';

  @override
  String get fontSettingsResetTo1x => 'Réinitialiser à 1,0x';

  @override
  String get fontSettingsAdaptBase => 'Adapter à la Base';

  @override
  String get reminderTitle => 'Rappel d\'enregistrement';

  @override
  String get reminderSubtitle =>
      'Définir l\'heure de rappel d\'enregistrement quotidien';

  @override
  String get reminderDailyTitle => 'Rappel d\'enregistrement quotidien';

  @override
  String get reminderDailySubtitle =>
      'Lorsqu\'activé, vous rappellera d\'enregistrer à l\'heure spécifiée';

  @override
  String get reminderTimeTitle => 'Heure du rappel';

  @override
  String get reminderTestNotification => 'Envoyer une notification de test';

  @override
  String get reminderTestSent => 'Notification de test envoyée';

  @override
  String get reminderTestTitle => 'Notification de test';

  @override
  String get reminderTestBody =>
      'Ceci est une notification de test, appuyez pour voir l\'effet';

  @override
  String get reminderTestDelayBody =>
      'Ceci est une notification de test différée de 15 secondes';

  @override
  String get reminderQuickTest => 'Test rapide (15s plus tard)';

  @override
  String get reminderQuickTestMessage =>
      'Test rapide défini pour 15 secondes plus tard, veuillez garder l\'application en arrière-plan';

  @override
  String get reminderFlutterTest =>
      '🔧 Tester la notification de clic Flutter (Dev)';

  @override
  String get reminderFlutterTestMessage =>
      'Notification de test Flutter envoyée, appuyez pour voir si elle ouvre l\'application';

  @override
  String get reminderAlarmTest =>
      '🔧 Tester la Notification de Clic AlarmManager (Dev)';

  @override
  String get reminderAlarmTestMessage =>
      'Notification de test AlarmManager définie (1 seconde plus tard), appuyez pour voir si elle ouvre l\'application';

  @override
  String get reminderDirectTest => '🔧 Test Direct NotificationReceiver (Dev)';

  @override
  String get reminderDirectTestMessage =>
      'Appelé directement NotificationReceiver pour créer une notification, vérifier si le clic fonctionne';

  @override
  String get reminderCheckStatus =>
      '🔧 Vérifier le Statut des Notifications (Dev)';

  @override
  String get reminderNotificationStatus => 'Statut des Notifications';

  @override
  String reminderPendingCount(Object count) {
    return 'Notifications en attente : $count';
  }

  @override
  String get reminderNoPending => 'Aucune notification en attente';

  @override
  String get reminderCheckBattery =>
      'Vérifier l\'État d\'Optimisation de la Batterie';

  @override
  String get reminderBatteryStatus => 'État d\'Optimisation de la Batterie';

  @override
  String reminderManufacturer(Object value) {
    return 'Fabricant : $value';
  }

  @override
  String reminderModel(Object value) {
    return 'Modèle : $value';
  }

  @override
  String reminderAndroidVersion(Object value) {
    return 'Version Android : $value';
  }

  @override
  String get reminderBatteryIgnored => 'Optimisation batterie : Ignorée ✅';

  @override
  String get reminderBatteryNotIgnored =>
      'Optimisation batterie : Non ignorée ⚠️';

  @override
  String get reminderBatteryAdvice =>
      'Recommande de désactiver l\'optimisation de la batterie pour des notifications correctes';

  @override
  String get reminderGoToSettings => 'Aller aux Paramètres';

  @override
  String get reminderCheckChannel =>
      'Vérifier les Paramètres du Canal de Notification';

  @override
  String get reminderChannelStatus => 'Statut du Canal de Notification';

  @override
  String get reminderChannelEnabled => 'Canal activé : Oui ✅';

  @override
  String get reminderChannelDisabled => 'Canal activé : Non ❌';

  @override
  String reminderChannelImportance(Object value) {
    return 'Importance : $value';
  }

  @override
  String get reminderChannelSoundOn => 'Son : Activé 🔊';

  @override
  String get reminderChannelSoundOff => 'Son : Désactivé 🔇';

  @override
  String get reminderChannelVibrationOn => 'Vibration : Activée 📳';

  @override
  String get reminderChannelVibrationOff => 'Vibration : Désactivée';

  @override
  String get reminderChannelDndBypass => 'Ne Pas Déranger : Peut contourner';

  @override
  String get reminderChannelDndNoBypass =>
      'Ne Pas Déranger : Ne peut pas contourner';

  @override
  String get reminderChannelAdvice => '⚠️ Paramètres recommandés :';

  @override
  String get reminderChannelAdviceImportance =>
      '• Importance : Urgent ou Élevé';

  @override
  String get reminderChannelAdviceSound => '• Activer son et vibration';

  @override
  String get reminderChannelAdviceBanner =>
      '• Autoriser notifications bannière';

  @override
  String get reminderChannelAdviceXiaomi =>
      '• Téléphones Xiaomi nécessitent configuration individuelle de chaque canal';

  @override
  String get reminderChannelGood => '✅ Canal de notification bien configuré';

  @override
  String get reminderOpenAppSettings =>
      'Ouvrir les Paramètres de l\'Application';

  @override
  String get reminderAppSettingsMessage =>
      'Veuillez autoriser les notifications et désactiver l\'optimisation de la batterie dans les paramètres';

  @override
  String get reminderIOSTest => '🍎 Test de Débogage de Notification iOS';

  @override
  String get reminderIOSTestTitle => 'Test de Notification iOS';

  @override
  String get reminderIOSTestMessage =>
      'Notification de test envoyée.\n\n🍎 Limitations du simulateur iOS :\n• Les notifications peuvent ne pas s\'afficher dans le centre de notifications\n• Les alertes bannière peuvent ne pas fonctionner\n• Mais la console Xcode affichera les logs\n\n💡 Méthodes de débogage :\n• Vérifier la sortie de la console Xcode\n• Vérifier les informations de log Flutter\n• Utiliser un appareil réel pour une expérience complète';

  @override
  String get reminderDescription =>
      'Conseil : Lorsque le rappel d\'enregistrement est activé, le système enverra des notifications à l\'heure spécifiée quotidiennement pour vous rappeler d\'enregistrer les revenus et dépenses.';

  @override
  String get reminderIOSInstructions =>
      '🍎 Paramètres de notification iOS :\n• Paramètres > Notifications > Comptabilité Abeille\n• Activer \"Autoriser les Notifications\"\n• Définir le style de notification : Bannière ou Alerte\n• Activer son et vibration\n\n⚠️ Note Importante :\n• Les notifications locales iOS dépendent du processus de l\'application\n• Ne fermez pas l\'application depuis le gestionnaire de tâches\n• Les notifications fonctionnent quand l\'application est en arrière-plan ou premier plan\n• Forcer la fermeture désactivera les notifications\n\n💡 Conseils d\'Utilisation :\n• Appuyez simplement sur le bouton Accueil pour quitter l\'application\n• iOS gérera automatiquement les applications en arrière-plan\n• Gardez l\'application en arrière-plan pour recevoir les rappels';

  @override
  String get reminderAndroidInstructions =>
      'Si les notifications ne fonctionnent pas correctement, vérifiez :\n• L\'application est autorisée à envoyer des notifications\n• Désactiver l\'optimisation de la batterie/économie d\'énergie pour l\'application\n• Autoriser l\'application à s\'exécuter en arrière-plan et démarrage automatique\n• Android 12+ nécessite une permission d\'alarme exacte\n\n📱 Paramètres spéciaux téléphone Xiaomi :\n• Paramètres > Gestion d\'Applications > Comptabilité Abeille > Gestion des Notifications\n• Appuyer sur le canal \"Rappel d\'Enregistrement\"\n• Définir importance sur \"Urgent\" ou \"Élevé\"\n• Activer \"Notifications bannière\", \"Son\", \"Vibration\"\n• Centre de Sécurité > Gestion d\'Applications > Permissions > Démarrage Automatique\n\n🔒 Méthodes de verrouillage en arrière-plan :\n• Trouver Comptabilité Abeille dans les tâches récentes\n• Tirer vers le bas la carte de l\'application pour afficher l\'icône de verrouillage\n• Appuyer sur l\'icône de verrouillage pour empêcher le nettoyage';

  @override
  String get categoryDetailLoadFailed => 'Échec du chargement';

  @override
  String get categoryDetailSummaryTitle => 'Résumé de Catégorie';

  @override
  String get categoryDetailTotalCount => 'Nombre Total';

  @override
  String get categoryDetailTotalAmount => 'Montant Total';

  @override
  String get categoryDetailAverageAmount => 'Montant Moyen';

  @override
  String get categoryDetailSortTitle => 'Trier';

  @override
  String get categoryDetailSortTimeDesc => 'Heure ↓';

  @override
  String get categoryDetailSortTimeAsc => 'Heure ↑';

  @override
  String get categoryDetailSortAmountDesc => 'Montant ↓';

  @override
  String get categoryDetailSortAmountAsc => 'Montant ↑';

  @override
  String get categoryDetailNoTransactions => 'Aucune transaction';

  @override
  String get categoryDetailNoTransactionsSubtext =>
      'Aucune transaction dans cette catégorie encore';

  @override
  String get categoryDetailDeleteFailed => 'Échec de la suppression';

  @override
  String get categoryMigrationConfirmTitle => 'Confirmer la Migration';

  @override
  String categoryMigrationConfirmMessage(
      Object count, Object fromName, Object toName) {
    return 'Migrer $count transactions de \"$fromName\" vers \"$toName\" ?\n\nCette opération ne peut pas être annulée !';
  }

  @override
  String get categoryMigrationConfirmOk => 'Confirmer la Migration';

  @override
  String get categoryMigrationCompleteTitle => 'Migration Terminée';

  @override
  String categoryMigrationCompleteMessage(
      Object count, Object fromName, Object toName) {
    return '$count transactions migrées avec succès de \"$fromName\" vers \"$toName\".';
  }

  @override
  String get categoryMigrationFailedTitle => 'Migration Échouée';

  @override
  String categoryMigrationFailedMessage(Object error) {
    return 'Erreur de migration : $error';
  }

  @override
  String categoryMigrationTransactionLabel(int count) {
    return '$count enregistrements';
  }

  @override
  String get categoryPickerExpenseTab => 'Dépense';

  @override
  String get categoryPickerIncomeTab => 'Revenu';

  @override
  String get categoryPickerCancel => 'Annuler';

  @override
  String get categoryPickerEmpty => 'Aucune catégorie';

  @override
  String get cloudBackupFound => 'Sauvegarde Cloud Trouvée';

  @override
  String get cloudBackupRestoreMessage =>
      'Les livres cloud et locaux ne sont pas cohérents, restaurer depuis le cloud ?\n(Entrera dans la page de progression de restauration)';

  @override
  String get cloudBackupRestoreFailed => 'Échec de la Restauration';

  @override
  String get mineCloudBackupRestoreTitle => 'Sauvegarde Cloud Trouvée';

  @override
  String get mineAutoSyncRemoteDesc =>
      'Téléversement automatique vers le cloud après enregistrement';

  @override
  String get mineAutoSyncLoginRequired => 'Connexion requise pour activer';

  @override
  String get mineImportCompleteAllSuccess => 'Tout Réussi';

  @override
  String get mineImportCompleteTitleShort => 'Importation Terminée';

  @override
  String get mineAboutAppName => 'Application : Comptabilité Abeille';

  @override
  String mineAboutVersion(Object version) {
    return 'Version : $version';
  }

  @override
  String get mineAboutRepo =>
      'Code source : https://github.com/TNT-Likely/BeeCount';

  @override
  String get mineAboutLicense => 'Licence : Voir LICENSE dans le dépôt';

  @override
  String get mineCheckUpdateDetecting => 'Vérification des mises à jour...';

  @override
  String get mineCheckUpdateSubtitleDetecting =>
      'Vérification de la dernière version';

  @override
  String get mineUpdateDownloadTitle => 'Télécharger la Mise à Jour';

  @override
  String get mineDebugRefreshStats => 'Actualiser les Statistiques (Debug)';

  @override
  String get mineDebugRefreshStatsSubtitle =>
      'Déclencher le recalcul du provider de statistiques global';

  @override
  String get mineDebugRefreshSync => 'Actualiser le Statut de Synchro (Debug)';

  @override
  String get mineDebugRefreshSyncSubtitle =>
      'Déclencher l\'actualisation du provider de statut de synchronisation';

  @override
  String get cloudCurrentService => 'Service Cloud Actuel';

  @override
  String get cloudConnected => 'Connecté';

  @override
  String get cloudOfflineMode => 'Mode Hors Ligne';

  @override
  String get cloudAvailableServices => 'Services Cloud Disponibles';

  @override
  String get cloudReadCustomConfigFailed =>
      'Échec de lecture de la configuration personnalisée';

  @override
  String get cloudNotConfigured => 'Non configuré';

  @override
  String get cloudNotTested => 'Non testé';

  @override
  String get cloudConnectionNormal => 'Connexion normale';

  @override
  String get cloudConnectionFailed => 'Connexion échouée';

  @override
  String get cloudAddCustomService => 'Ajouter un service cloud personnalisé';

  @override
  String get cloudCustomServiceName => 'Service Cloud Personnalisé';

  @override
  String get cloudDefaultServiceName => 'Service Cloud par Défaut';

  @override
  String get cloudUseYourSupabase => 'Utiliser votre propre Supabase';

  @override
  String get cloudTest => 'Tester';

  @override
  String get cloudSwitchService => 'Changer de Service Cloud';

  @override
  String get cloudSwitchToBuiltinConfirm =>
      'Êtes-vous sûr de vouloir basculer vers le service cloud par défaut ? Cela vous déconnectera.';

  @override
  String get cloudSwitchToCustomConfirm =>
      'Êtes-vous sûr de vouloir basculer vers le service cloud personnalisé ? Cela vous déconnectera.';

  @override
  String get cloudSwitched => 'Basculé';

  @override
  String get cloudSwitchedToBuiltin =>
      'Basculé vers le service cloud par défaut et déconnecté';

  @override
  String get cloudSwitchFailed => 'Échec du basculement';

  @override
  String get cloudActivateFailed => 'Échec de l\'activation';

  @override
  String get cloudActivateFailedMessage => 'Configuration enregistrée invalide';

  @override
  String get cloudActivated => 'Activé';

  @override
  String get cloudActivatedMessage =>
      'Basculé vers le service cloud personnalisé et déconnecté, veuillez vous reconnecter';

  @override
  String get cloudEditCustomService => 'Modifier le service cloud personnalisé';

  @override
  String get cloudAddCustomServiceTitle =>
      'Ajouter un service cloud personnalisé';

  @override
  String get cloudSupabaseUrlLabel => 'URL Supabase';

  @override
  String get cloudSupabaseUrlHint => 'https://xxx.supabase.co';

  @override
  String get cloudAnonKeyLabel => 'Clé Anon';

  @override
  String get cloudAnonKeyHint =>
      'Conseil : Ne remplissez pas la clé service_role ; La clé Anon est publique.';

  @override
  String get cloudInvalidInput => 'Entrée invalide';

  @override
  String get cloudValidationEmptyFields =>
      'L\'URL et la clé ne peuvent pas être vides';

  @override
  String get cloudValidationHttpsRequired =>
      'L\'URL doit commencer par https://';

  @override
  String get cloudValidationKeyTooShort =>
      'La longueur de la clé est trop courte, peut être invalide';

  @override
  String get cloudValidationServiceRoleKey =>
      'La clé service_role n\'est pas autorisée';

  @override
  String get cloudValidationHttpRequired =>
      'L\'URL doit commencer par http:// ou https://';

  @override
  String get cloudSelectServiceType => 'Sélectionner le Type de Service Cloud';

  @override
  String get cloudWebdavUrlLabel => 'URL du Serveur WebDAV';

  @override
  String get cloudWebdavUrlHint => 'https://dav.jianguoyun.com/dav/';

  @override
  String get cloudWebdavUsernameLabel => 'Nom d\'utilisateur';

  @override
  String get cloudWebdavPasswordLabel => 'Mot de passe';

  @override
  String get cloudWebdavPathLabel => 'Chemin Distant';

  @override
  String get cloudWebdavPathHint => '/BeeCount';

  @override
  String get cloudWebdavHint =>
      'Compatible avec Nutstore, Nextcloud, Synology, etc.';

  @override
  String get cloudConfigUpdated => 'Configuration mise à jour';

  @override
  String get cloudConfigSaved => 'Configuration enregistrée';

  @override
  String get cloudTestComplete => 'Test terminé';

  @override
  String get cloudTestSuccess => 'Test de connexion réussi !';

  @override
  String get cloudTestFailed =>
      'Test de connexion échoué, veuillez vérifier la configuration.';

  @override
  String get cloudTestError => 'Test échoué';

  @override
  String get cloudClearConfig => 'Effacer la configuration';

  @override
  String get cloudClearConfigConfirm =>
      'Êtes-vous sûr de vouloir effacer la configuration du service cloud personnalisé ? (Environnement de développement uniquement)';

  @override
  String get cloudConfigCleared =>
      'Configuration du service cloud personnalisé effacée';

  @override
  String get cloudClearFailed => 'Échec de l\'effacement';

  @override
  String get cloudServiceDescription =>
      'Service cloud intégré à l\'application (gratuit mais peut être instable, recommande d\'utiliser le vôtre ou de sauvegarder régulièrement)';

  @override
  String get cloudServiceDescriptionNotConfigured =>
      'La build actuelle n\'a pas de configuration de service cloud intégrée';

  @override
  String cloudServiceDescriptionCustom(String url) {
    return 'Serveur : $url';
  }

  @override
  String get authLogin => 'Connexion';

  @override
  String get authSignup => 'Inscription';

  @override
  String get authRegister => 'S\'inscrire';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authPassword => 'Mot de passe';

  @override
  String get authPasswordRequirement =>
      'Mot de passe (au moins 6 caractères, inclure lettres et chiffres)';

  @override
  String get authConfirmPassword => 'Confirmer le Mot de passe';

  @override
  String get authInvalidEmail => 'Veuillez entrer une adresse e-mail valide';

  @override
  String get authPasswordRequirementShort =>
      'Le mot de passe doit contenir lettres et chiffres, au moins 6 caractères';

  @override
  String get authPasswordMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get authResendVerification => 'Renvoyer l\'e-mail de vérification';

  @override
  String get authSignupSuccess => 'Inscription réussie';

  @override
  String get authVerificationEmailSent =>
      'E-mail de vérification envoyé, veuillez vérifier votre boîte mail avant de vous connecter.';

  @override
  String get authBackToMinePage => 'Retour à Ma Page';

  @override
  String get authVerificationEmailResent => 'E-mail de vérification renvoyé.';

  @override
  String get authResendAction => 'renvoyer la vérification';

  @override
  String get authErrorInvalidCredentials => 'E-mail ou mot de passe incorrect.';

  @override
  String get authErrorEmailNotConfirmed =>
      'E-mail non vérifié, veuillez compléter la vérification avant de vous connecter.';

  @override
  String get authErrorRateLimit =>
      'Trop de tentatives, veuillez réessayer plus tard.';

  @override
  String get authErrorNetworkIssue =>
      'Erreur réseau, veuillez vérifier votre connexion et réessayer.';

  @override
  String get authErrorLoginFailed =>
      'Échec de connexion, veuillez réessayer plus tard.';

  @override
  String get authErrorEmailInvalid =>
      'Adresse e-mail invalide, veuillez vérifier l\'orthographe.';

  @override
  String get authErrorEmailExists =>
      'Cet e-mail est déjà enregistré, veuillez vous connecter directement ou réinitialiser le mot de passe.';

  @override
  String get authErrorWeakPassword =>
      'Mot de passe trop simple, veuillez inclure lettres et chiffres, au moins 6 caractères.';

  @override
  String get authErrorSignupFailed =>
      'Échec d\'inscription, veuillez réessayer plus tard.';

  @override
  String authErrorUserNotFound(String action) {
    return 'E-mail non enregistré, impossible de $action.';
  }

  @override
  String authErrorEmailNotVerified(String action) {
    return 'E-mail non vérifié, impossible de $action.';
  }

  @override
  String authErrorActionFailed(String action) {
    return '$action échoué, veuillez réessayer plus tard.';
  }

  @override
  String get importSelectCsvFile =>
      'Veuillez sélectionner un fichier à importer (CSV/TSV/XLSX supportés)';

  @override
  String get exportTitle => 'Exporter';

  @override
  String get exportDescription =>
      'Cliquez sur le bouton ci-dessous pour sélectionner l\'emplacement de sauvegarde et exporter le livre actuel vers un fichier CSV.';

  @override
  String get exportButtonIOS => 'Exporter et partager';

  @override
  String get exportButtonAndroid => 'Exporter les données';

  @override
  String exportSavedTo(String path) {
    return 'Enregistré dans : $path';
  }

  @override
  String get exportSelectFolder => 'Sélectionner le dossier d\'exportation';

  @override
  String get exportCsvHeaderType => 'Type';

  @override
  String get exportCsvHeaderCategory => 'Catégorie';

  @override
  String get exportCsvHeaderAmount => 'Montant';

  @override
  String get exportCsvHeaderAccount => 'Compte';

  @override
  String get exportCsvHeaderNote => 'Note';

  @override
  String get exportCsvHeaderTime => 'Heure';

  @override
  String get exportShareText => 'Fichier d\'exportation BeeCount';

  @override
  String get exportSuccessTitle => 'Exportation réussie';

  @override
  String exportSuccessMessageIOS(String path) {
    return 'Enregistré et disponible dans l\'historique de partage :\n$path';
  }

  @override
  String exportSuccessMessageAndroid(String path) {
    return 'Enregistré dans :\n$path';
  }

  @override
  String get exportFailedTitle => 'Exportation échouée';

  @override
  String get exportTypeIncome => 'Revenu';

  @override
  String get exportTypeExpense => 'Dépense';

  @override
  String get exportTypeTransfer => 'Transfert';

  @override
  String get personalizeThemeHoney => 'Jaune abeille';

  @override
  String get personalizeThemeOrange => 'Orange flamme';

  @override
  String get personalizeThemeGreen => 'Vert émeraude';

  @override
  String get personalizeThemePurple => 'Lotus violet';

  @override
  String get personalizeThemePink => 'Rose cerise';

  @override
  String get personalizeThemeBlue => 'Bleu ciel';

  @override
  String get personalizeThemeMint => 'Lune de forêt';

  @override
  String get personalizeThemeSand => 'Dune du coucher de soleil';

  @override
  String get personalizeThemeLavender => 'Neige et pin';

  @override
  String get personalizeThemeSky => 'Pays des merveilles brumeux';

  @override
  String get personalizeThemeWarmOrange => 'Orange chaud';

  @override
  String get personalizeThemeMintGreen => 'Vert menthe';

  @override
  String get personalizeThemeRoseGold => 'Or rose';

  @override
  String get personalizeThemeDeepBlue => 'Bleu profond';

  @override
  String get personalizeThemeMapleRed => 'Rouge érable';

  @override
  String get personalizeThemeEmerald => 'Émeraude';

  @override
  String get personalizeThemeLavenderPurple => 'Lavande';

  @override
  String get personalizeThemeAmber => 'Ambre';

  @override
  String get personalizeThemeRouge => 'Rouge vermillon';

  @override
  String get personalizeThemeIndigo => 'Bleu indigo';

  @override
  String get personalizeThemeOlive => 'Vert olive';

  @override
  String get personalizeThemeCoral => 'Rose corail';

  @override
  String get personalizeThemeDarkGreen => 'Vert foncé';

  @override
  String get personalizeThemeViolet => 'Violet';

  @override
  String get personalizeThemeSunset => 'Orange coucher de soleil';

  @override
  String get personalizeThemePeacock => 'Bleu paon';

  @override
  String get personalizeThemeLime => 'Vert citron';

  @override
  String get analyticsMonthlyAvg => 'Moyenne mensuelle';

  @override
  String get analyticsDailyAvg => 'Moyenne quotidienne';

  @override
  String get analyticsOverallAvg => 'Moyenne générale';

  @override
  String get analyticsTotalIncome => 'Total des revenus : ';

  @override
  String get analyticsTotalExpense => 'Total des dépenses : ';

  @override
  String get analyticsBalance => 'Solde : ';

  @override
  String analyticsAvgIncome(String avgLabel) {
    return '$avgLabel revenus : ';
  }

  @override
  String analyticsAvgExpense(String avgLabel) {
    return '$avgLabel dépenses : ';
  }

  @override
  String get analyticsExpense => 'Dépenses';

  @override
  String get analyticsIncome => 'Revenus';

  @override
  String analyticsTotal(String type) {
    return 'Total $type : ';
  }

  @override
  String analyticsAverage(String avgLabel) {
    return '$avgLabel : ';
  }

  @override
  String get updateCheckTitle => 'Vérifier les mises à jour';

  @override
  String get updateNewVersionFound => 'Nouvelle version trouvée';

  @override
  String updateNewVersionTitle(String version) {
    return 'Nouvelle version $version trouvée';
  }

  @override
  String get updateNoApkFound => 'Lien de téléchargement APK non trouvé';

  @override
  String get updateAlreadyLatest => 'Vous avez déjà la dernière version';

  @override
  String get updateCheckFailed =>
      'Erreur lors de la vérification des mises à jour';

  @override
  String get updatePermissionDenied => 'Permission refusée';

  @override
  String get updateUserCancelled => 'Utilisateur annulé';

  @override
  String get updateDownloadTitle => 'Télécharger la mise à jour';

  @override
  String updateDownloading(String percent) {
    return 'Téléchargement : $percent%';
  }

  @override
  String get updateDownloadBackgroundHint =>
      'Vous pouvez mettre l\'application en arrière-plan, le téléchargement continuera';

  @override
  String get updateCancelButton => 'Annuler';

  @override
  String get updateBackgroundDownload => 'Téléchargement en arrière-plan';

  @override
  String get updateLaterButton => 'Plus tard';

  @override
  String get updateDownloadButton => 'Télécharger';

  @override
  String get updateFoundCachedTitle => 'Version téléchargée trouvée';

  @override
  String updateFoundCachedMessage(String path) {
    return 'Un installateur téléchargé précédemment a été trouvé, installer directement ?\\n\\nCliquez sur \"OK\" pour installer immédiatement, cliquez sur \"Annuler\" pour fermer cette boîte de dialogue.\\n\\nChemin du fichier : $path';
  }

  @override
  String get updateInstallingCachedApk => 'Installation de l\'APK en cache';

  @override
  String get updateDownloadComplete => 'Téléchargement terminé';

  @override
  String get updateInstallStarted =>
      'Téléchargement terminé, installateur démarré';

  @override
  String get updateInstallFailed => 'Installation échouée';

  @override
  String get updateDownloadCompleteManual =>
      'Téléchargement terminé, peut être installé manuellement';

  @override
  String get updateDownloadCompleteException =>
      'Téléchargement terminé, veuillez installer manuellement (exception de dialogue)';

  @override
  String get updateDownloadCompleteManualContext =>
      'Téléchargement terminé, veuillez installer manuellement';

  @override
  String get updateDownloadFailed => 'Téléchargement échoué';

  @override
  String get updateInstallTitle => 'Téléchargement terminé';

  @override
  String get updateInstallMessage =>
      'Téléchargement du fichier APK terminé, installer immédiatement ?\\n\\nNote : L\'application ira temporairement en arrière-plan pendant l\'installation, c\'est normal.';

  @override
  String get updateInstallNow => 'Installer maintenant';

  @override
  String get updateInstallLater => 'Installer plus tard';

  @override
  String get updateNotificationTitle =>
      'Téléchargement de mise à jour BeeCount';

  @override
  String get updateNotificationBody =>
      'Téléchargement de la nouvelle version...';

  @override
  String get updateNotificationComplete =>
      'Téléchargement terminé, appuyez pour installer';

  @override
  String get updateNotificationPermissionTitle =>
      'Permission de notification refusée';

  @override
  String get updateNotificationPermissionMessage =>
      'Impossible d\'obtenir la permission de notification, la progression du téléchargement ne s\'affichera pas dans la barre de notification, mais la fonction de téléchargement fonctionne normalement.';

  @override
  String get updateNotificationGuideTitle =>
      'Si vous devez activer les notifications, suivez ces étapes :';

  @override
  String get updateNotificationStep1 => 'Ouvrir les paramètres système';

  @override
  String get updateNotificationStep2 =>
      'Trouver \"Gestion d\'applications\" ou \"Paramètres d\'applications\"';

  @override
  String get updateNotificationStep3 => 'Trouver l\'application \"BeeCount\"';

  @override
  String get updateNotificationStep4 =>
      'Cliquer sur \"Gestion des permissions\" ou \"Gestion des notifications\"';

  @override
  String get updateNotificationStep5 =>
      'Activer \"Permission de notification\"';

  @override
  String get updateNotificationMiuiHint =>
      'Utilisateurs MIUI : Le système Xiaomi a un contrôle strict des permissions de notification, peut nécessiter des paramètres supplémentaires dans le Centre de sécurité';

  @override
  String get updateNotificationGotIt => 'Compris';

  @override
  String get updateCheckFailedTitle =>
      'Erreur lors de la vérification des mises à jour';

  @override
  String get updateDownloadFailedTitle => 'Téléchargement échoué';

  @override
  String get updateGoToGitHub => 'Aller sur GitHub';

  @override
  String get updateCannotOpenLink => 'Impossible d\'ouvrir le lien';

  @override
  String get updateManualVisit =>
      'Veuillez visiter manuellement dans le navigateur :\\nhttps://github.com/TNT-Likely/BeeCount/releases';

  @override
  String get updateNoLocalApkTitle => 'Aucun package de mise à jour trouvé';

  @override
  String get updateNoLocalApkMessage =>
      'Aucun fichier de package de mise à jour téléchargé trouvé.\\n\\nVeuillez d\'abord télécharger la nouvelle version via \"Vérifier les mises à jour\".';

  @override
  String get updateInstallPackageTitle => 'Installer le package de mise à jour';

  @override
  String get updateMultiplePackagesTitle =>
      'Plusieurs packages de mise à jour trouvés';

  @override
  String updateMultiplePackagesMessage(int count, String path) {
    return '$count fichiers de package de mise à jour trouvés.\\n\\nIl est recommandé d\'utiliser la version téléchargée la plus récente, ou d\'installer manuellement dans le gestionnaire de fichiers.\\n\\nEmplacement du fichier : $path';
  }

  @override
  String get updateSearchFailedTitle => 'Recherche échouée';

  @override
  String updateSearchFailedMessage(String error) {
    return 'Une erreur s\'est produite lors de la recherche de packages de mise à jour locaux : $error';
  }

  @override
  String get updateFoundCachedPackageTitle =>
      'Package de mise à jour téléchargé trouvé';

  @override
  String updateFoundCachedPackageMessage(String fileName, String fileSize) {
    return 'Package de mise à jour téléchargé précédemment détecté :\\n\\nNom du fichier : $fileName\\nTaille : ${fileSize}MB\\n\\nInstaller immédiatement ?';
  }

  @override
  String get updateIgnoreButton => 'Ignorer';

  @override
  String get updateInstallFailedTitle => 'Installation échouée';

  @override
  String get updateInstallFailedMessage =>
      'Impossible de démarrer l\'installateur APK, veuillez vérifier les permissions du fichier.';

  @override
  String get updateErrorTitle => 'Erreur';

  @override
  String updateReadCacheFailedMessage(String error) {
    return 'Erreur lors de la lecture du package de mise à jour en cache : $error';
  }

  @override
  String get updateCheckingPermissions => 'Vérification des permissions...';

  @override
  String get updateCheckingCache => 'Vérification du cache local...';

  @override
  String get updatePreparingDownload => 'Préparation du téléchargement...';

  @override
  String get updateUserCancelledDownload =>
      'Utilisateur a annulé le téléchargement';

  @override
  String get updateStartingInstaller => 'Démarrage de l\'installateur...';

  @override
  String get updateInstallerStarted => 'Installateur démarré';

  @override
  String get updateInstallationFailed => 'Installation échouée';

  @override
  String get updateDownloadCompleted => 'Téléchargement terminé';

  @override
  String get updateDownloadCompletedManual =>
      'Téléchargement terminé, peut être installé manuellement';

  @override
  String get updateDownloadCompletedDialog =>
      'Téléchargement terminé, veuillez installer manuellement (exception de dialogue)';

  @override
  String get updateDownloadCompletedContext =>
      'Téléchargement terminé, veuillez installer manuellement';

  @override
  String get updateDownloadFailedGeneric => 'Téléchargement échoué';

  @override
  String get updateCheckingUpdate => 'Vérification des mises à jour...';

  @override
  String get updateCurrentLatestVersion => 'Vous avez déjà la dernière version';

  @override
  String get updateCheckFailedGeneric =>
      'Erreur lors de la vérification des mises à jour';

  @override
  String updateDownloadProgress(String percent) {
    return 'Téléchargement : $percent%';
  }

  @override
  String get updateNoApkFoundError => 'Lien de téléchargement APK non trouvé';

  @override
  String updateCheckingUpdateError(String error) {
    return 'Erreur lors de la vérification des mises à jour : $error';
  }

  @override
  String get updateNotificationChannelName => 'Téléchargement de mise à jour';

  @override
  String get updateNotificationDownloadingIndeterminate =>
      'Téléchargement de la nouvelle version...';

  @override
  String updateNotificationDownloadingProgress(String progress) {
    return 'Progression du téléchargement : $progress%';
  }

  @override
  String get updateNotificationDownloadCompleteTitle =>
      'Téléchargement terminé';

  @override
  String get updateNotificationDownloadCompleteMessage =>
      'Nouvelle version téléchargée, appuyez pour installer';

  @override
  String get updateUserCancelledDownloadDialog =>
      'Utilisateur a annulé le téléchargement';

  @override
  String get updateCannotOpenLinkError => 'Impossible d\'ouvrir le lien';

  @override
  String get updateNoLocalApkFoundMessage =>
      'Aucun fichier de package de mise à jour téléchargé trouvé.\\n\\nVeuillez d\'abord télécharger la nouvelle version via \"Vérifier les mises à jour\".';

  @override
  String updateInstallPackageFoundMessage(
      String fileName, String fileSize, String time) {
    return 'Package de mise à jour trouvé :\\n\\nNom du fichier : $fileName\\nTaille : ${fileSize}MB\\nHeure de téléchargement : $time\\n\\nInstaller immédiatement ?';
  }

  @override
  String updateMultiplePackagesFoundMessage(int count, String path) {
    return '$count fichiers de package de mise à jour trouvés.\\n\\nIl est recommandé d\'utiliser la version téléchargée la plus récente, ou d\'installer manuellement dans le gestionnaire de fichiers.\\n\\nEmplacement du fichier : $path';
  }

  @override
  String updateSearchLocalApkError(String error) {
    return 'Une erreur s\'est produite lors de la recherche de packages de mise à jour locaux : $error';
  }

  @override
  String updateCachedPackageFoundMessage(String fileName, String fileSize) {
    return 'Package de mise à jour téléchargé précédemment détecté :\\n\\nNom du fichier : $fileName\\nTaille : ${fileSize}MB\\n\\nInstaller immédiatement ?';
  }

  @override
  String updateReadCachedPackageError(String error) {
    return 'Erreur lors de la lecture du package de mise à jour en cache : $error';
  }

  @override
  String get reminderQuickTestSent =>
      'Test rapide défini pour 15 secondes plus tard, veuillez garder l\'application en arrière-plan';

  @override
  String get reminderFlutterTestSent =>
      'Notification de test Flutter envoyée, cliquez pour voir si elle ouvre l\'application';

  @override
  String get reminderAlarmTestSent =>
      'Notification de test AlarmManager définie (1 seconde plus tard), cliquez pour voir si elle ouvre l\'application';

  @override
  String get updateOk => 'OK';

  @override
  String get updateCannotOpenLinkTitle => 'Impossible d\'ouvrir le lien';

  @override
  String get updateCachedVersionTitle => 'Version téléchargée trouvée';

  @override
  String get updateCachedVersionMessage =>
      'Un package d\'installation téléchargé précédemment a été trouvé... Cliquez sur \\\"OK\\\" pour installer immédiatement, cliquez sur \\\"Annuler\\\" pour fermer...';

  @override
  String get updateConfirmDownload => 'Télécharger et installer maintenant';

  @override
  String get updateDownloadCompleteTitle => 'Téléchargement terminé';

  @override
  String get updateInstallConfirmMessage =>
      'Nouvelle version téléchargée. Installer maintenant ?';

  @override
  String get updateNotificationPermissionGuideText =>
      'Les notifications de progression de téléchargement sont désactivées, mais cela n\'affecte pas la fonctionnalité de téléchargement. Pour voir la progression :';

  @override
  String get updateNotificationGuideStep1 =>
      'Aller dans Paramètres système > Gestion d\'applications';

  @override
  String get updateNotificationGuideStep2 =>
      'Trouver l\'application \\\"BeeCount\\\"';

  @override
  String get updateNotificationGuideStep3 =>
      'Activer les permissions de notification';

  @override
  String get updateNotificationGuideInfo =>
      'Les téléchargements continueront normalement en arrière-plan même sans notifications';

  @override
  String get currencyCNY => 'Yuan chinois';

  @override
  String get currencyUSD => 'Dollar américain';

  @override
  String get currencyEUR => 'Euro';

  @override
  String get currencyJPY => 'Yen japonais';

  @override
  String get currencyHKD => 'Dollar de Hong Kong';

  @override
  String get currencyTWD => 'Nouveau dollar taïwanais';

  @override
  String get currencyGBP => 'Livre sterling';

  @override
  String get currencyAUD => 'Dollar australien';

  @override
  String get currencyCAD => 'Dollar canadien';

  @override
  String get currencyKRW => 'Won sud-coréen';

  @override
  String get currencySGD => 'Dollar de Singapour';

  @override
  String get currencyMYR => 'Ringgit malaisien';

  @override
  String get currencyTHB => 'Baht thaïlandais';

  @override
  String get currencyIDR => 'Roupie indonésienne';

  @override
  String get currencyPHP => 'Peso philippin';

  @override
  String get currencyVND => 'Dong vietnamien';

  @override
  String get currencyINR => 'Roupie indienne';

  @override
  String get currencyRUB => 'Rouble russe';

  @override
  String get currencyBYN => 'Rouble biélorusse';

  @override
  String get currencyNZD => 'Dollar néo-zélandais';

  @override
  String get currencyCHF => 'Franc suisse';

  @override
  String get currencySEK => 'Couronne suédoise';

  @override
  String get currencyNOK => 'Couronne norvégienne';

  @override
  String get currencyDKK => 'Couronne danoise';

  @override
  String get currencyBRL => 'Réal brésilien';

  @override
  String get currencyMXN => 'Peso mexicain';

  @override
  String get webdavConfiguredTitle => 'Service cloud WebDAV configuré';

  @override
  String get webdavConfiguredMessage =>
      'Le service cloud WebDAV utilise les identifiants fournis lors de la configuration, aucune connexion supplémentaire n\'est requise.';

  @override
  String get recurringTransactionTitle => 'Transactions Récurrentes';

  @override
  String get recurringTransactionAdd => 'Ajouter une Transaction Récurrente';

  @override
  String get recurringTransactionEdit => 'Modifier une Transaction Récurrente';

  @override
  String get recurringTransactionFrequency => 'Fréquence';

  @override
  String get recurringTransactionDaily => 'Quotidien';

  @override
  String get recurringTransactionWeekly => 'Hebdomadaire';

  @override
  String get recurringTransactionMonthly => 'Mensuel';

  @override
  String get recurringTransactionYearly => 'Annuel';

  @override
  String get recurringTransactionInterval => 'Intervalle';

  @override
  String get recurringTransactionDayOfMonth => 'Jour du Mois';

  @override
  String get recurringTransactionStartDate => 'Date de Début';

  @override
  String get recurringTransactionEndDate => 'Date de Fin';

  @override
  String get recurringTransactionNoEndDate => 'Sans Date de Fin';

  @override
  String get recurringTransactionEnabled => 'Activé';

  @override
  String get recurringTransactionDisabled => 'Désactivé';

  @override
  String get recurringTransactionNextGeneration => 'Prochaine Génération';

  @override
  String get recurringTransactionDeleteConfirm =>
      'Êtes-vous sûr de vouloir supprimer cette transaction récurrente ?';

  @override
  String get recurringTransactionEmpty => 'Aucune Transaction Récurrente';

  @override
  String get recurringTransactionEmptyHint =>
      'Appuyez sur le bouton + en haut à droite pour ajouter';

  @override
  String recurringTransactionEveryNDays(int n) {
    return 'Tous les $n jour(s)';
  }

  @override
  String recurringTransactionEveryNWeeks(int n) {
    return 'Toutes les $n semaine(s)';
  }

  @override
  String recurringTransactionEveryNMonths(int n) {
    return 'Tous les $n mois';
  }

  @override
  String recurringTransactionEveryNYears(int n) {
    return 'Tous les $n an(s)';
  }

  @override
  String get cloudDefaultServiceDisplayName => 'Service Cloud par Défaut';

  @override
  String get cloudNotConfiguredDisplay => 'Non Configuré';

  @override
  String get syncNotConfiguredMessage => 'Cloud non configuré';

  @override
  String get syncNotLoggedInMessage => 'Non connecté';

  @override
  String get syncCloudBackupCorruptedMessage =>
      'Le contenu de la sauvegarde cloud est corrompu, possiblement dû à des problèmes d\'encodage des versions antérieures. Veuillez cliquer sur \'Téléverser le livre actuel vers le cloud\' pour écraser et corriger.';

  @override
  String get syncNoCloudBackupMessage => 'Aucune sauvegarde cloud';

  @override
  String get syncAccessDeniedMessage =>
      '403 Accès refusé (vérifier la politique RLS de stockage et le chemin)';

  @override
  String get cloudTestConnection => 'Tester la Connexion';

  @override
  String get cloudLocalStorageTitle => 'Stockage local';

  @override
  String get cloudLocalStorageSubtitle =>
      'Les données sont uniquement enregistrées sur l\'appareil local';

  @override
  String get cloudCustomSupabaseTitle => 'Supabase personnalisé';

  @override
  String get cloudCustomSupabaseSubtitle =>
      'Cliquez pour configurer Supabase auto-hébergé';

  @override
  String get cloudCustomWebdavTitle => 'WebDAV personnalisé';

  @override
  String get cloudCustomWebdavSubtitle =>
      'Cliquez pour configurer Nutstore/Nextcloud etc.';

  @override
  String get cloudStatusNotTested => 'Non testé';

  @override
  String get cloudStatusNormal => 'Connexion normale';

  @override
  String get cloudStatusFailed => 'Connexion échouée';

  @override
  String get cloudCannotOpenLink => 'Impossible d\'ouvrir le lien';

  @override
  String get cloudErrorAuthFailed =>
      'Authentification échouée : Clé API invalide';

  @override
  String cloudErrorServerStatus(String code) {
    return 'Le serveur a renvoyé le code d\'état $code';
  }

  @override
  String get cloudErrorWebdavNotSupported =>
      'Le serveur ne prend pas en charge le protocole WebDAV';

  @override
  String get cloudErrorAuthFailedCredentials =>
      'Authentification échouée : Nom d\'utilisateur ou mot de passe incorrect';

  @override
  String get cloudErrorAccessDenied =>
      'Accès refusé : Veuillez vérifier les autorisations';

  @override
  String cloudErrorPathNotFound(String path) {
    return 'Chemin du serveur introuvable : $path';
  }

  @override
  String cloudErrorNetwork(String message) {
    return 'Erreur réseau : $message';
  }

  @override
  String get cloudTestSuccessTitle => 'Test Réussi';

  @override
  String get cloudTestSuccessMessage =>
      'Connexion normale, configuration valide';

  @override
  String get cloudTestFailedTitle => 'Test Échoué';

  @override
  String get cloudTestFailedMessage => 'Connexion échouée';

  @override
  String get cloudTestErrorTitle => 'Erreur de Test';

  @override
  String get cloudSwitchConfirmTitle => 'Changer de service cloud';

  @override
  String get cloudSwitchConfirmMessage =>
      'Changer de service cloud déconnectera le compte actuel. Confirmer ?';

  @override
  String get cloudSwitchFailedTitle => 'Changement échoué';

  @override
  String get cloudSwitchFailedConfigMissing =>
      'Veuillez d\'abord configurer ce service cloud';

  @override
  String get cloudConfigInvalidTitle => 'Configuration invalide';

  @override
  String get cloudConfigInvalidMessage =>
      'Veuillez saisir des informations complètes';

  @override
  String get cloudSaveFailed => 'Échec de l\'enregistrement';

  @override
  String cloudSwitchedTo(String type) {
    return 'Basculé vers $type';
  }

  @override
  String get cloudConfigureSupabaseTitle => 'Configurer Supabase';

  @override
  String get cloudConfigureWebdavTitle => 'Configurer WebDAV';

  @override
  String get cloudSupabaseAnonKeyHintLong => 'Collez la clé anon complète';

  @override
  String get cloudWebdavRemotePathHelp =>
      'Chemin du répertoire distant pour le stockage des données';

  @override
  String get cloudWebdavRemotePathLabel => 'Chemin Distant';

  @override
  String get cloudWebdavRemotePathHelperText =>
      'Chemin du répertoire distant pour le stockage des données';

  @override
  String get accountsTitle => 'Gestion des Comptes';

  @override
  String get accountsManageDesc =>
      'Gérer les comptes de paiement et les soldes';

  @override
  String get accountsEmptyMessage =>
      'Aucun compte encore, appuyez en haut à droite pour ajouter';

  @override
  String get accountAddTooltip => 'Ajouter un Compte';

  @override
  String get accountAddButton => 'Ajouter un Compte';

  @override
  String get accountBalance => 'Solde';

  @override
  String get accountEditTitle => 'Modifier le Compte';

  @override
  String get accountNewTitle => 'Nouveau Compte';

  @override
  String get accountNameLabel => 'Nom du Compte';

  @override
  String get accountNameHint => 'p. ex. : ICBC, Alipay, etc.';

  @override
  String get accountNameRequired => 'Veuillez entrer le nom du compte';

  @override
  String get accountTypeLabel => 'Type de Compte';

  @override
  String get accountTypeCash => 'Espèces';

  @override
  String get accountTypeBankCard => 'Carte Bancaire';

  @override
  String get accountTypeCreditCard => 'Carte de Crédit';

  @override
  String get accountTypeAlipay => 'Alipay';

  @override
  String get accountTypeWechat => 'WeChat';

  @override
  String get accountTypeOther => 'Autre';

  @override
  String get accountInitialBalance => 'Solde Initial';

  @override
  String get accountInitialBalanceHint => 'Entrer le solde initial (optionnel)';

  @override
  String get accountDeleteWarningTitle => 'Confirmer la Suppression';

  @override
  String accountDeleteWarningMessage(int count) {
    return 'Ce compte a $count transactions associées. Après suppression, les informations de compte dans les enregistrements de transaction seront effacées. Confirmer la suppression ?';
  }

  @override
  String get accountDeleteConfirm => 'Confirmer la suppression de ce compte ?';

  @override
  String get accountSelectTitle => 'Sélectionner le Compte';

  @override
  String get accountNone => 'Aucun Compte';

  @override
  String get accountsEnableFeature => 'Activer la Fonction de Compte';

  @override
  String get accountsFeatureDescription =>
      'Gérer plusieurs comptes de paiement et suivre les changements de solde pour chaque compte';

  @override
  String get privacyOpenSourceUrlError => 'Impossible d\'ouvrir le lien';

  @override
  String get updateCorruptedFileTitle => 'Package d\'Installation Corrompu';

  @override
  String get updateCorruptedFileMessage =>
      'Le package d\'installation téléchargé précédemment est incomplet ou corrompu. Supprimer et re-télécharger ?';

  @override
  String get welcomeTitle => 'Bienvenue dans BeeCount';

  @override
  String get welcomeDescription =>
      'Une application de comptabilité qui respecte vraiment votre vie privée';

  @override
  String get welcomePrivacyTitle => 'Vos Données, Votre Contrôle';

  @override
  String get welcomePrivacyFeature1 =>
      'Données stockées localement sur votre appareil';

  @override
  String get welcomePrivacyFeature2 =>
      'Jamais téléversées vers des serveurs tiers';

  @override
  String get welcomePrivacyFeature3 =>
      'Aucune publicité, aucune collecte de données';

  @override
  String get welcomePrivacyFeature4 => 'Aucune inscription de compte requise';

  @override
  String get welcomeOpenSourceTitle => 'Open Source & Transparent';

  @override
  String get welcomeOpenSourceFeature1 => 'Code source 100% open source';

  @override
  String get welcomeOpenSourceFeature2 =>
      'Supervision communautaire, aucune porte dérobée';

  @override
  String get welcomeOpenSourceFeature3 =>
      'Gratuit pour Utilisation Personnelle';

  @override
  String get welcomeViewGitHub => 'Voir le Code Source sur GitHub';

  @override
  String get welcomeCloudSyncTitle => 'Synchronisation Cloud Optionnelle';

  @override
  String get welcomeCloudSyncDescription =>
      'Vous ne voulez pas utiliser de services cloud commerciaux ? BeeCount prend en charge plusieurs méthodes de synchronisation';

  @override
  String get welcomeCloudSyncFeature1 => 'Utilisation complètement hors ligne';

  @override
  String get welcomeCloudSyncFeature2 => 'Synchronisation WebDAV auto-hébergée';

  @override
  String get welcomeCloudSyncFeature3 => 'Service Supabase auto-hébergé';

  @override
  String get lab => 'Laboratoire';

  @override
  String get labDesc => 'Essayer les fonctionnalités expérimentales';

  @override
  String get widgetManagement => 'Widget d\'Écran d\'Accueil';

  @override
  String get widgetManagementDesc =>
      'Vue rapide des revenus et dépenses sur l\'écran d\'accueil';

  @override
  String get widgetPreview => 'Aperçu du Widget';

  @override
  String get widgetPreviewDesc =>
      'Le widget affiche automatiquement les données réelles du livre actuel, la couleur du thème suit les paramètres de l\'application';

  @override
  String get howToAddWidget => 'Comment Ajouter un Widget';

  @override
  String get iosWidgetStep1 =>
      'Appui long sur la zone vide de l\'écran d\'accueil pour entrer en mode édition';

  @override
  String get iosWidgetStep2 => 'Appuyer sur le bouton \"+\" en haut à gauche';

  @override
  String get iosWidgetStep3 =>
      'Rechercher et sélectionner \"Comptabilité Abeille\"';

  @override
  String get iosWidgetStep4 =>
      'Sélectionner widget moyen et ajouter à l\'écran d\'accueil';

  @override
  String get androidWidgetStep1 =>
      'Appui long sur la zone vide de l\'écran d\'accueil';

  @override
  String get androidWidgetStep2 => 'Sélectionner \"Widgets\"';

  @override
  String get androidWidgetStep3 =>
      'Trouver et appui long sur widget \"Comptabilité Abeille\"';

  @override
  String get androidWidgetStep4 =>
      'Faire glisser vers une position appropriée sur l\'écran d\'accueil';

  @override
  String get aboutWidget => 'À Propos du Widget';

  @override
  String get widgetDescription =>
      'Le widget se synchronise automatiquement pour afficher les données de revenus et dépenses d\'aujourd\'hui et de ce mois, rafraîchissement toutes les 30 minutes. Les données se mettent à jour immédiatement à l\'ouverture de l\'application.';

  @override
  String get appName => 'Comptabilité Abeille';

  @override
  String get monthSuffix => '';

  @override
  String get todayExpense => 'Dépense d\'Aujourd\'hui';

  @override
  String get todayIncome => 'Revenu d\'Aujourd\'hui';

  @override
  String get monthExpense => 'Dépense du Mois';

  @override
  String get monthIncome => 'Revenu du Mois';

  @override
  String get autoScreenshotBilling => 'Comptabilité Auto par Capture d\'Écran';

  @override
  String get autoScreenshotBillingDesc =>
      'Identification automatique des informations de paiement après capture d\'écran';

  @override
  String get autoScreenshotBillingTitle =>
      'Comptabilité Auto par Capture d\'Écran';

  @override
  String get featureDescription => 'Description de la Fonctionnalité';

  @override
  String get featureDescriptionContent =>
      'Après avoir pris une capture d\'écran de la page de paiement, le système identifiera automatiquement le montant et les informations du commerçant, et créera un enregistrement de dépense.\n\n⚡ Vitesse d\'identification : 1-2 secondes\n🤖 Correspondance intelligente de catégorie\n📝 Remplissage automatique des notes\n\nNote :\n• Sans service d\'accessibilité : légèrement plus lent (3-5s)\n• Avec service d\'accessibilité activé : identification instantanée';

  @override
  String get autoBilling => 'Comptabilité Automatique';

  @override
  String get enabled => 'Activé';

  @override
  String get disabled => 'Désactivé';

  @override
  String get accessibilityService => 'Service d\'Accessibilité';

  @override
  String get accessibilityServiceEnabled =>
      'Activé - Identification Instantanée';

  @override
  String get accessibilityServiceDisabled =>
      'Désactivé - Identification Plus Lente';

  @override
  String get improveRecognitionSpeed =>
      'Améliorer la Vitesse d\'Identification';

  @override
  String get accessibilityGuideContent =>
      'Avec le service d\'accessibilité activé, les captures d\'écran peuvent être identifiées instantanément sans attendre l\'écriture du fichier.';

  @override
  String get setupSteps => 'Étapes de Configuration :';

  @override
  String get accessibilityStep1 =>
      'Appuyer sur le bouton \"Ouvrir Paramètres d\'Accessibilité\" ci-dessous';

  @override
  String get accessibilityStep2 =>
      'Trouver \"Comptabilité Abeille-Identification Capture\" dans la liste';

  @override
  String get accessibilityStep3 => 'Activer l\'interrupteur de service';

  @override
  String get accessibilityStep4 => 'Retourner à l\'application pour utiliser';

  @override
  String get openAccessibilitySettings => 'Ouvrir Paramètres d\'Accessibilité';

  @override
  String get accessibilityServiceNote =>
      '💡 Note : Le service d\'accessibilité est uniquement utilisé pour détecter les actions de capture d\'écran, et ne lira ni ne modifiera vos autres données.';

  @override
  String get supportedPayments => 'Méthodes de Paiement Prises en Charge';

  @override
  String get supportedAlipay => '✅ Alipay';

  @override
  String get supportedWechat => '✅ WeChat Pay';

  @override
  String get supportedUnionpay => '✅ UnionPay';

  @override
  String get supportedOthers =>
      '⚠️ Les autres méthodes de paiement peuvent avoir une précision d\'identification plus faible';

  @override
  String get photosPermissionRequired =>
      'Permission photos requise pour surveiller les captures d\'écran';

  @override
  String get enableSuccess => 'Comptabilité automatique activée';

  @override
  String get disableSuccess => 'Comptabilité automatique désactivée';

  @override
  String get autoBillingBatteryTitle => 'Maintenir en Arrière-plan';

  @override
  String get autoBillingBatteryGuideTitle =>
      'Paramètres d\'Optimisation de Batterie';

  @override
  String get autoBillingBatteryDesc =>
      'La comptabilité automatique nécessite que l\'application reste en arrière-plan. Certains téléphones nettoient automatiquement les applications en arrière-plan après verrouillage, ce qui peut causer l\'échec de la comptabilité automatique. Il est recommandé de désactiver l\'optimisation de la batterie pour garantir un fonctionnement correct.';

  @override
  String get autoBillingCheckBattery =>
      'Vérifier l\'Optimisation de la Batterie';

  @override
  String get autoBillingBatteryWarning =>
      '⚠️ L\'optimisation de la batterie n\'est pas désactivée. L\'application peut être automatiquement nettoyée par le système, causant l\'échec de la comptabilité automatique. Veuillez appuyer sur le bouton \"Paramètres\" ci-dessus pour désactiver l\'optimisation de la batterie.';

  @override
  String get enableFailed => 'Échec de l\'activation';

  @override
  String get disableFailed => 'Échec de la désactivation';

  @override
  String get openSettingsFailed => 'Échec de l\'ouverture des paramètres';

  @override
  String get reselectImage => 'Resélectionner';

  @override
  String get viewOriginalText => 'Afficher le texte original';

  @override
  String get createBill => 'Créer une Facture';

  @override
  String get ocrBilling => 'Comptabilité par Scan OCR';

  @override
  String get ocrBillingDesc =>
      'Scanner automatiquement les captures d\'écran de paiement pour identifier le montant';

  @override
  String get quickActions => 'Actions Rapides';

  @override
  String get iosAutoFeatureDesc =>
      'Utiliser l\'application iOS \"Raccourcis\" pour identifier automatiquement les informations de paiement depuis les captures d\'écran et créer des transactions. Une fois configuré, cela se déclenchera automatiquement à chaque capture d\'écran.';

  @override
  String get iosAutoShortcutQuickAdd => 'Ajouter Rapidement un Raccourci';

  @override
  String get iosAutoShortcutQuickAddDesc =>
      'Cliquez sur le bouton ci-dessous pour importer directement le raccourci configuré, ou ouvrez manuellement l\'application Raccourcis.';

  @override
  String get iosAutoShortcutImport => 'Importation de Raccourci en Un Clic';

  @override
  String get iosAutoShortcutOpenApp =>
      'Ou Ouvrir Manuellement l\'Application Raccourcis';

  @override
  String get iosAutoShortcutConfigTitle =>
      'Étapes de Configuration (Recommandé - Paramètre URL) :';

  @override
  String get iosAutoShortcutStep1 => 'Ouvrir l\'application \"Raccourcis\"';

  @override
  String get iosAutoShortcutStep2 =>
      'Appuyer sur \"+\" en haut à droite pour créer un nouveau raccourci';

  @override
  String get iosAutoShortcutStep3 =>
      'Ajouter l\'action \"Prendre Capture d\'Écran\" (obtenir dernière capture)';

  @override
  String get iosAutoShortcutStep4 =>
      'Ajouter l\'action \"Extraire Texte de la Capture d\'Écran\"';

  @override
  String get iosAutoShortcutStep5 =>
      'Ajouter l\'action \"Remplacer Texte\" : remplacer \"\\n\" dans le texte extrait par \",\" (virgule)';

  @override
  String get iosAutoShortcutStep6 =>
      'Ajouter l\'action \"Encodage URL\" : encoder le texte remplacé';

  @override
  String get iosAutoShortcutStep7 =>
      'Ajouter l\'action \"Ouvrir URL\", URL :\nbeecount://auto-billing?text=[texte encodé URL]';

  @override
  String get iosAutoShortcutStep8 =>
      'Appuyer sur paramètres raccourci (trois points en haut à droite)';

  @override
  String get iosAutoShortcutStep9 =>
      'Dans \"Quand...\" ajouter déclencheur \"Quand Capture d\'Écran est prise\"';

  @override
  String get iosAutoShortcutStep10 =>
      'Enregistrer et tester : identification automatique après capture d\'écran';

  @override
  String get iosAutoShortcutRecommendedTip =>
      '✅ Recommandé : Passage de paramètre URL, aucune permission nécessaire, meilleure expérience. Étapes clés :\n• Remplacer retours à la ligne \\n par virgule , (éviter troncature URL)\n• Utiliser encodage URL (éviter texte chinois illisible)\n• Le texte de capture d\'écran ne dépasse généralement pas la limite de 2048 caractères';

  @override
  String get iosAutoBackTapTitle =>
      '💡 Double Appui Arrière pour Déclencher (Recommandé)';

  @override
  String get iosAutoBackTapDesc =>
      'Paramètres > Accessibilité > Tactile > Appui Arrière\n• Sélectionner \"Appui Double\" ou \"Appui Triple\"\n• Choisir le raccourci que vous venez de créer\n• Après configuration, double appui arrière du téléphone pendant paiement pour enregistrement auto, aucune capture d\'écran nécessaire';

  @override
  String iosAutoImportFailed(Object error) {
    return 'Échec d\'importation : $error';
  }

  @override
  String iosAutoOpenAppFailed(Object error) {
    return 'Échec d\'ouverture : $error';
  }

  @override
  String get iosAutoCannotOpenLink =>
      'Impossible d\'ouvrir le lien, veuillez vérifier la connexion réseau';

  @override
  String get iosAutoCannotOpenShortcuts =>
      'Impossible d\'ouvrir l\'application Raccourcis';

  @override
  String get aiSettingsTitle => 'Identification IA';

  @override
  String get aiSettingsSubtitle =>
      'Configurer les modèles IA et la stratégie d\'identification';

  @override
  String get aiEnableTitle => 'Activer l\'Identification IA';

  @override
  String get aiEnableSubtitle =>
      'Utiliser l\'IA pour améliorer la précision OCR et extraire montant, commerçant, heure, etc.';

  @override
  String get aiEnableToastOn => 'Amélioration IA activée';

  @override
  String get aiEnableToastOff => 'Amélioration IA désactivée';

  @override
  String get aiStrategyTitle => 'Stratégie d\'Exécution';

  @override
  String get aiStrategyLocalFirst => 'Local d\'Abord (Recommandé)';

  @override
  String get aiStrategyLocalFirstDesc =>
      'Utiliser le modèle local d\'abord, basculer vers le cloud en cas d\'échec';

  @override
  String get aiStrategyCloudFirst => 'Cloud d\'Abord';

  @override
  String get aiStrategyCloudFirstDesc =>
      'Utiliser l\'API cloud d\'abord, rétrograder vers local en cas d\'échec';

  @override
  String get aiStrategyLocalOnly => 'Local Uniquement';

  @override
  String get aiStrategyLocalOnlyDesc =>
      'Utiliser uniquement le modèle local, complètement hors ligne';

  @override
  String get aiStrategyCloudOnly => 'Cloud Uniquement';

  @override
  String get aiStrategyCloudOnlyDesc =>
      'Utiliser uniquement l\'API cloud, pas de téléchargement de modèle';

  @override
  String get aiStrategyUnavailable =>
      'Modèle local en formation, bientôt disponible';

  @override
  String aiStrategySwitched(String strategy) {
    return 'Basculé vers : $strategy';
  }

  @override
  String get aiCloudApiTitle => 'API Zhipu GLM';

  @override
  String get aiCloudApiKeyLabel => 'Clé API';

  @override
  String get aiCloudApiKeyHint => 'Entrer votre clé API Zhipu AI';

  @override
  String get aiCloudApiKeyHelper =>
      'Le modèle GLM-4-Flash est complètement gratuit';

  @override
  String get aiCloudApiKeySaved => 'Clé API enregistrée';

  @override
  String get aiCloudApiGetKey => 'Obtenir la Clé API';

  @override
  String get aiLocalModelTitle => 'Modèle Local';

  @override
  String get aiLocalModelTraining => 'En Formation';

  @override
  String get aiLocalModelManagement => 'Gestion des Modèles';

  @override
  String get aiLocalModelUnavailable =>
      'Modèle local en formation, pas encore disponible';

  @override
  String get aiFabSettingTitle => 'Bouton Ajout Rapide Prioriser Caméra';

  @override
  String get aiFabSettingDescCamera =>
      'Appui pour caméra, appui long pour manuel';

  @override
  String get aiFabSettingDescManual =>
      'Appui pour manuel, appui long pour caméra';

  @override
  String get aiOcrRecognizing => 'Identification de la facture...';

  @override
  String get aiOcrNoAmount =>
      'Aucun montant valide identifié, veuillez ajouter manuellement';

  @override
  String get aiOcrNoLedger => 'Livre non trouvé';

  @override
  String aiOcrSuccess(String type, String amount) {
    return '✅ Facture $type créée ¥$amount';
  }

  @override
  String aiOcrFailed(String error) {
    return 'Échec d\'identification : $error';
  }

  @override
  String get aiOcrCreateFailed => 'Échec de création de la facture';

  @override
  String get aiTypeIncome => 'Revenu';

  @override
  String get aiTypeExpense => 'Dépense';

  @override
  String get ocrRecognitionResult => 'Résultat de reconnaissance';

  @override
  String get ocrAmount => 'Montant';

  @override
  String get ocrNoAmountDetected => 'Aucun montant détecté';

  @override
  String get ocrManualAmountInput => 'Ou saisir le montant manuellement';

  @override
  String get ocrMerchant => 'Marchand';

  @override
  String get ocrSuggestedCategory => 'Catégorie suggérée';

  @override
  String get ocrTime => 'Heure';

  @override
  String get cloudSyncAndBackup => 'Synchronisation et sauvegarde cloud';

  @override
  String get cloudSyncAndBackupDesc =>
      'Configuration du service cloud, gestion de la synchronisation des données';

  @override
  String get cloudSyncPageTitle => 'Synchronisation et sauvegarde cloud';

  @override
  String get cloudSyncPageSubtitle =>
      'Gérer les services cloud et la synchronisation des données';

  @override
  String get dataManagement => 'Gestion des données';

  @override
  String get dataManagementDesc => 'Importer, exporter, catégories et comptes';

  @override
  String get dataManagementPageTitle => 'Gestion des données';

  @override
  String get dataManagementPageSubtitle =>
      'Gérer les données de transaction et les catégories';

  @override
  String get smartBilling => 'Enregistrement intelligent';

  @override
  String get smartBillingDesc =>
      'Reconnaissance IA, scan OCR, enregistrement automatique';

  @override
  String get smartBillingPageTitle => 'Enregistrement intelligent';

  @override
  String get smartBillingPageSubtitle =>
      'Fonctions d\'enregistrement IA et automatisation';

  @override
  String get automation => 'Automatisation';

  @override
  String get automationDesc => 'Transactions récurrentes et rappels';

  @override
  String get automationPageTitle => 'Fonctions d\'automatisation';

  @override
  String get automationPageSubtitle =>
      'Paramètres de transactions récurrentes et rappels';

  @override
  String get appearanceSettings => 'Paramètres d\'apparence';

  @override
  String get appearanceSettingsDesc => 'Paramètres de thème, police et langue';

  @override
  String get appearanceSettingsPageTitle => 'Paramètres d\'apparence';

  @override
  String get appearanceSettingsPageSubtitle =>
      'Personnaliser l\'apparence et l\'affichage';

  @override
  String get about => 'À propos';

  @override
  String get aboutDesc => 'Informations de version, aide et commentaires';

  @override
  String get mineRateApp => 'Évaluer l\'application';

  @override
  String get mineRateAppSubtitle => 'Notez-nous sur l\'App Store';

  @override
  String get aboutPageTitle => 'À propos';

  @override
  String get aboutPageSubtitle => 'Informations sur l\'application et aide';

  @override
  String get aboutPageLoadingVersion => 'Chargement de la version...';

  @override
  String get aboutGitHubRepo => 'Dépôt GitHub';

  @override
  String get aboutContactEmail => 'E-mail de contact';

  @override
  String get aboutWeChatGroup => 'Groupe WeChat';

  @override
  String get aboutWeChatGroupDesc => 'Appuyez pour voir le code QR';

  @override
  String get aboutXiaohongshu => 'Xiaohongshu';

  @override
  String get aboutDouyin => 'Douyin';

  @override
  String get aboutTelegramGroup => 'Groupe Telegram';

  @override
  String get aboutCopied => 'Copié dans le presse-papiers';

  @override
  String get aboutSupportDevelopment => 'Support Development';

  @override
  String get aboutSupportDevelopmentSubtitle => 'Buy me a coffee';

  @override
  String get cloudService => 'Service cloud';

  @override
  String get cloudServiceDesc => 'Configurer le fournisseur de stockage cloud';

  @override
  String get syncManagement => 'Gestion de la synchronisation';

  @override
  String get syncManagementDesc => 'Synchronisation et sauvegarde des données';

  @override
  String get moreSettings => 'Plus de paramètres';

  @override
  String get moreSettingsDesc => 'Options avancées de synchronisation cloud';

  @override
  String get configImportExportTitle => 'Config Import/Export';

  @override
  String get configImportExportSubtitle =>
      'Backup and restore app configurations';

  @override
  String get configImportExportInfoTitle => 'Feature Description';

  @override
  String get configImportExportInfoMessage =>
      'This feature is used to export and import app configurations, including cloud service settings, AI settings, etc. The config file uses YAML format for easy viewing and editing.\n\n⚠️ Config files contain sensitive information (such as API keys, passwords, etc.), please keep them safe.';

  @override
  String get configExportTitle => 'Export Config';

  @override
  String get configExportSubtitle => 'Export current config to YAML file';

  @override
  String get configExportShareSubject => 'BeeCount Config File';

  @override
  String get configExportSuccess => 'Config exported successfully';

  @override
  String get configExportFailed => 'Config export failed';

  @override
  String get configImportTitle => 'Import Config';

  @override
  String get configImportSubtitle => 'Restore config from YAML file';

  @override
  String get configImportNoFilePath => 'No file selected';

  @override
  String get configImportConfirmTitle => 'Confirm Import';

  @override
  String get configImportConfirmMessage =>
      'Importing config will overwrite current settings, continue?';

  @override
  String get configImportSuccess => 'Config imported successfully';

  @override
  String get configImportFailed => 'Config import failed';

  @override
  String get configImportRestartTitle => 'Restart Required';

  @override
  String get configImportRestartMessage =>
      'Config has been imported. Some settings will take effect after restarting the app.';

  @override
  String get configImportExportIncludesTitle => 'Included Configurations';

  @override
  String configExportSavedTo(String path) {
    return 'Saved to: $path';
  }

  @override
  String get configExportOpenFile => 'Open Folder';

  @override
  String get configExportOpenFileFailed => 'Unable to open folder';

  @override
  String get configExportViewContent => 'View Content';

  @override
  String get configExportCopyContent => 'Copy Content';

  @override
  String get configExportContentCopied => 'Copied to clipboard';

  @override
  String get configExportReadFileFailed => 'Failed to read file';

  @override
  String get configIncludeSupabase => 'Supabase cloud service config';

  @override
  String get configIncludeWebdav => 'WebDAV cloud service config';

  @override
  String get configIncludeAI => 'AI smart recognition config';

  @override
  String get ledgersConflictTitle => 'Sync Conflict';

  @override
  String get ledgersConflictMessage =>
      'Local and cloud ledger data are inconsistent, please choose an action:';

  @override
  String ledgersConflictLocalInfo(int count) {
    return 'Local: $count transactions';
  }

  @override
  String ledgersConflictRemoteInfo(int count) {
    return 'Cloud: $count transactions';
  }

  @override
  String ledgersConflictLocalUpdated(String time) {
    return 'Local updated: $time';
  }

  @override
  String ledgersConflictRemoteUpdated(String time) {
    return 'Cloud updated: $time';
  }

  @override
  String ledgersConflictLocalFingerprint(String fp) {
    return 'Local fingerprint: $fp';
  }

  @override
  String ledgersConflictRemoteFingerprint(String fp) {
    return 'Cloud fingerprint: $fp';
  }

  @override
  String get ledgersConflictUpload => 'Upload to Cloud';

  @override
  String get ledgersConflictDownload => 'Download to Local';

  @override
  String get ledgersConflictUploading => 'Uploading...';

  @override
  String get ledgersConflictDownloading => 'Downloading...';

  @override
  String get ledgersConflictUploadSuccess => 'Upload successful';

  @override
  String ledgersConflictDownloadSuccess(int inserted) {
    return 'Download successful, merged $inserted transactions';
  }

  @override
  String get storageManagementTitle => 'Gestion du stockage';

  @override
  String get storageManagementSubtitle =>
      'Effacer le cache pour libérer de l\'espace';

  @override
  String get storageAIModels => 'Modèles IA';

  @override
  String get storageAPKFiles => 'Paquets d\'installation';

  @override
  String get storageNoData => 'Aucune donnée';

  @override
  String get storageFiles => 'fichiers';

  @override
  String get storageHint =>
      'Appuyez sur les éléments pour effacer les fichiers cache correspondants';

  @override
  String get storageClearConfirmTitle => 'Confirmer l\'effacement';

  @override
  String storageClearAIModelsMessage(String size) {
    return 'Voulez-vous vraiment effacer tous les modèles IA ? Taille : $size';
  }

  @override
  String storageClearAPKMessage(String size) {
    return 'Voulez-vous vraiment effacer tous les paquets d\'installation ? Taille : $size';
  }

  @override
  String get storageClearSuccess => 'Effacé avec succès';

  @override
  String get accountNoTransactions => 'No transactions';

  @override
  String get accountTransactionHistory => 'Transaction History';

  @override
  String get accountTotalBalance => 'Total Balance';

  @override
  String get accountTotalExpense => 'Total Expense';

  @override
  String get accountTotalIncome => 'Total Income';

  @override
  String get accountDetailTitle => 'Account Details';

  @override
  String get commonUncategorized => 'Uncategorized';
}
