import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../jobs/providers/job_provider.dart';
import '../data/payment_model.dart';
import '../data/payment_repository.dart';

export '../data/payment_model.dart';

/// Fetches and syncs the authenticated user's linked T-Bank cards
final linkedCardsProvider = FutureProvider.autoDispose<List<LinkedCardModel>>((
  ref,
) {
  return ref.watch(paymentRepositoryProvider).fetchLinkedCards();
});

/// Tracks in-flight card or B2B invoice mutations
final paymentMutationProvider =
    StateNotifierProvider.autoDispose<PaymentMutationNotifier, bool>((ref) {
      return PaymentMutationNotifier(ref);
    });

class PaymentMutationNotifier extends StateNotifier<bool> {
  final Ref _ref;

  PaymentMutationNotifier(this._ref) : super(false);

  Future<CardLinkInitResult> initiateCardLinking() async {
    state = true;
    try {
      return await _ref.read(paymentRepositoryProvider).initiateCardLinking();
    } finally {
      if (mounted) state = false;
    }
  }

  Future<void> setDefaultCard(String cardId) async {
    state = true;
    try {
      await _ref.read(paymentRepositoryProvider).setDefaultCard(cardId);
      _ref.invalidate(linkedCardsProvider);
    } finally {
      if (mounted) state = false;
    }
  }

  Future<void> unlinkCard(String cardId) async {
    state = true;
    try {
      await _ref.read(paymentRepositoryProvider).unlinkCard(cardId);
      _ref.invalidate(linkedCardsProvider);
    } finally {
      if (mounted) state = false;
    }
  }

  Future<B2BInvoiceResult> createB2BInvoice({
    required String jobId,
    required String payerLegalType,
    required String payerName,
    required String payerInn,
    String? payerKpp,
    String? payerEmail,
  }) async {
    state = true;
    try {
      final result = await _ref
          .read(paymentRepositoryProvider)
          .createB2BInvoice(
            jobId: jobId,
            payerLegalType: payerLegalType,
            payerName: payerName,
            payerInn: payerInn,
            payerKpp: payerKpp,
            payerEmail: payerEmail,
          );

      // Refresh job detail so payment_method updates immediately
      _ref.invalidate(jobDetailProvider(jobId));
      return result;
    } finally {
      if (mounted) state = false;
    }
  }
}

/// Paginated worker transaction history (10 items per page, supports direction filter)
final workerTransactionsProvider = AsyncNotifierProvider.family
    .autoDispose<
      WorkerTransactionsNotifier,
      PaginatedTransactionsState,
      String
    >(() {
      return WorkerTransactionsNotifier();
    });

class WorkerTransactionsNotifier
    extends AutoDisposeFamilyAsyncNotifier<PaginatedTransactionsState, String> {
  static const int _pageSize = 10;

  @override
  Future<PaginatedTransactionsState> build(String arg) {
    return ref
        .read(paymentRepositoryProvider)
        .fetchWorkerTransactions(page: 1, limit: _pageSize, direction: arg);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(paymentRepositoryProvider)
          .fetchWorkerTransactions(page: 1, limit: _pageSize, direction: arg),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final nextPage = current.page + 1;
      final nextResult = await ref
          .read(paymentRepositoryProvider)
          .fetchWorkerTransactions(
            page: nextPage,
            limit: _pageSize,
            direction: arg,
          );

      final existingIds = current.items.map((t) => t.id).toSet();
      final uniqueNew = nextResult.items
          .where((t) => !existingIds.contains(t.id))
          .toList();

      state = AsyncValue.data(
        current.copyWith(
          items: [...current.items, ...uniqueNew],
          page: nextPage,
          total: nextResult.total,
          hasMore: nextResult.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}
