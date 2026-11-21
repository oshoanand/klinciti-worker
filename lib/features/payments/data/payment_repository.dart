import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import 'payment_model.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiClientProvider));
});

class PaymentRepository {
  final ApiClient _api;

  PaymentRepository(this._api);

  /// Syncs with T-Bank (EACQ for Customer, E2C for Worker) and returns active cards
  /// GET /api/payments/cards
  Future<List<LinkedCardModel>> fetchLinkedCards() async {
    try {
      final response = await _api.dio.get('/payments/cards');
      final body = response.data is Map
          ? JsonMap.from(response.data as Map)
          : <String, dynamic>{};
      final rawList = (body['data'] as List<dynamic>?) ?? const [];

      return rawList
          .whereType()
          .map((e) => LinkedCardModel.fromJson(JsonMap.from(e)))
          .toList();
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Initiates T-Bank 3DSHOLD card linking and returns the verification URL
  /// POST /api/payments/cards/link
  Future<CardLinkInitResult> initiateCardLinking() async {
    try {
      final response = await _api.dio.post('/payments/cards/link');
      final body = response.data is Map
          ? JsonMap.from(response.data as Map)
          : <String, dynamic>{};

      final result = CardLinkInitResult.fromJson(body);
      if (result.paymentUrl.isEmpty) {
        throw ApiException('Не удалось получить ссылку для привязки карты');
      }
      return result;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.fromDioException(e);
    }
  }

  /// Sets a linked card as the default payment or payout card
  /// PATCH /api/payments/cards/:cardId/default
  Future<void> setDefaultCard(String cardId) async {
    try {
      await _api.dio.patch('/payments/cards/$cardId/default');
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Unlinks a card in both T-Bank and PostgreSQL
  /// DELETE /api/payments/cards/:cardId
  Future<void> unlinkCard(String cardId) async {
    try {
      await _api.dio.delete('/payments/cards/$cardId');
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Issues an official B2B invoice for IP / OOO customers via T-Bank Business API
  /// POST /api/payments/b2b/invoice
  Future<B2BInvoiceResult> createB2BInvoice({
    required String jobId,
    required String payerLegalType, // 'IP' | 'OOO'
    required String payerName,
    required String payerInn,
    String? payerKpp,
    String? payerEmail,
  }) async {
    try {
      final response = await _api.dio.post(
        '/payments/b2b/invoice',
        data: {
          'jobId': jobId,
          'payerLegalType': payerLegalType,
          'payerName': payerName.trim(),
          'payerInn': payerInn.trim(),
          if (payerKpp != null && payerKpp.trim().isNotEmpty)
            'payerKpp': payerKpp.trim(),
          if (payerEmail != null && payerEmail.trim().isNotEmpty)
            'payerEmail': payerEmail.trim(),
        },
      );

      final body = response.data is Map
          ? JsonMap.from(response.data as Map)
          : <String, dynamic>{};
      return B2BInvoiceResult.fromJson(body);
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Fetches paginated incoming & outgoing transactions for the worker (10 per page)
  /// GET /api/payments/worker/transactions
  Future<PaginatedTransactionsState> fetchWorkerTransactions({
    int page = 1,
    int limit = 10,
    String direction = 'ALL',
  }) async {
    try {
      final response = await _api.dio.get(
        '/payments/worker/transactions',
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          'direction': direction,
        },
      );

      final body = response.data is Map
          ? JsonMap.from(response.data as Map)
          : <String, dynamic>{};

      final rawList = (body['data'] as List<dynamic>?) ?? const [];
      final items = rawList
          .whereType()
          .map((e) => WorkerTransactionModel.fromJson(JsonMap.from(e)))
          .toList();

      final meta = body['meta'] is Map
          ? JsonMap.from(body['meta'] as Map)
          : <String, dynamic>{};

      final total =
          int.tryParse((meta['total'] ?? items.length).toString()) ?? 0;
      final hasMore = meta['hasMore'] == true || (page * limit) < total;

      return PaginatedTransactionsState(
        items: items,
        page: page,
        total: total,
        hasMore: hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
