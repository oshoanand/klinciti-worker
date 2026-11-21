typedef JsonMap = Map<String, dynamic>;

class LinkedCardModel {
  final String id;
  final String roleContext; // 'CUSTOMER' | 'WORKER'
  final String provider; // 'TINKOFF_EACQ' | 'TINKOFF_E2C'
  final String cardMask; // e.g. '430000******0777'
  final String? cardType; // 'MIR' | 'VISA' | 'MASTERCARD'
  final String? expDate; // e.g. '1228'
  final bool isDefault;
  final bool isActive;

  const LinkedCardModel({
    required this.id,
    required this.roleContext,
    required this.provider,
    required this.cardMask,
    this.cardType,
    this.expDate,
    this.isDefault = false,
    this.isActive = true,
  });

  /// Formats '1228' into '12/28' for clean display
  String get formattedExpDate {
    final raw = expDate?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (raw.length == 4) {
      return '${raw.substring(0, 2)}/${raw.substring(2)}';
    }
    return expDate ?? '';
  }

  /// Extracts last 4 digits for compact display
  String get lastFour {
    final digits = cardMask.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) {
      return digits.substring(digits.length - 4);
    }
    return cardMask;
  }

  factory LinkedCardModel.fromJson(JsonMap json) {
    return LinkedCardModel(
      id: (json['id'] ?? '').toString(),
      roleContext: (json['role_context'] ?? json['roleContext'] ?? 'CUSTOMER')
          .toString()
          .toUpperCase(),
      provider: (json['provider'] ?? 'TINKOFF_EACQ').toString(),
      cardMask: (json['card_mask'] ?? json['cardMask'] ?? '').toString(),
      cardType: (json['card_type'] ?? json['cardType'])?.toString(),
      expDate: (json['exp_date'] ?? json['expDate'])?.toString(),
      isDefault: json['is_default'] == true || json['isDefault'] == true,
      isActive: json['is_active'] != false && json['isActive'] != false,
    );
  }
}

class CardLinkInitResult {
  final String paymentUrl;
  final String requestKey;
  final String customerKey;

  const CardLinkInitResult({
    required this.paymentUrl,
    required this.requestKey,
    required this.customerKey,
  });

  factory CardLinkInitResult.fromJson(JsonMap raw) {
    final json = raw['data'] is Map ? JsonMap.from(raw['data'] as Map) : raw;
    return CardLinkInitResult(
      paymentUrl: (json['paymentUrl'] ?? '').toString(),
      requestKey: (json['requestKey'] ?? '').toString(),
      customerKey: (json['customerKey'] ?? '').toString(),
    );
  }
}

class B2BInvoiceResult {
  final String paymentId;
  final String invoiceNumber;
  final String invoiceId;
  final String pdfUrl;
  final String dueDate;
  final double totalRub;
  final double commissionRub;

  const B2BInvoiceResult({
    required this.paymentId,
    required this.invoiceNumber,
    required this.invoiceId,
    required this.pdfUrl,
    required this.dueDate,
    required this.totalRub,
    required this.commissionRub,
  });

  factory B2BInvoiceResult.fromJson(JsonMap raw) {
    final json = raw['data'] is Map ? JsonMap.from(raw['data'] as Map) : raw;
    return B2BInvoiceResult(
      paymentId: (json['paymentId'] ?? '').toString(),
      invoiceNumber: (json['invoiceNumber'] ?? '').toString(),
      invoiceId: (json['invoiceId'] ?? '').toString(),
      pdfUrl: (json['pdfUrl'] ?? '').toString(),
      dueDate: (json['dueDate'] ?? '').toString(),
      totalRub: double.tryParse((json['totalRub'] ?? '0').toString()) ?? 0.0,
      commissionRub:
          double.tryParse((json['commissionRub'] ?? '0').toString()) ?? 0.0,
    );
  }
}

class WorkerTransactionModel {
  final String id;
  final String paymentId;
  final String? jobId;
  final String? jobDescription;
  final String type; // 'PAYOUT' | 'COMMISSION' | 'REFUND'
  final String direction; // 'INCOMING' | 'OUTGOING'
  final double amount;
  final String currency;
  final String status;
  final String? paymentMethod;
  final String? errorMessage;
  final DateTime? createdAt;

  const WorkerTransactionModel({
    required this.id,
    required this.paymentId,
    this.jobId,
    this.jobDescription,
    required this.type,
    required this.direction,
    required this.amount,
    this.currency = 'RUB',
    required this.status,
    this.paymentMethod,
    this.errorMessage,
    this.createdAt,
  });

  bool get isIncoming => direction == 'INCOMING';

  String get title {
    switch (type.toUpperCase()) {
      case 'PAYOUT':
        return 'Выплата за заказ';
      case 'COMMISSION':
        return 'Комиссия сервиса Klinciti';
      case 'REFUND':
        return 'Возврат средств клиенту';
      default:
        return 'Операция по счету';
    }
  }

  factory WorkerTransactionModel.fromJson(JsonMap json) {
    final typeStr = (json['type'] ?? '').toString().toUpperCase();
    final dirStr =
        (json['direction'] ?? (typeStr == 'PAYOUT' ? 'INCOMING' : 'OUTGOING'))
            .toString()
            .toUpperCase();

    return WorkerTransactionModel(
      id: (json['id'] ?? '').toString(),
      paymentId: (json['payment_id'] ?? json['paymentId'] ?? '').toString(),
      jobId: (json['job_id'] ?? json['jobId'])?.toString(),
      jobDescription: (json['job_description'] ?? json['jobDescription'])
          ?.toString(),
      type: typeStr,
      direction: dirStr,
      amount: double.tryParse((json['amount'] ?? '0').toString()) ?? 0.0,
      currency: (json['currency'] ?? 'RUB').toString(),
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      paymentMethod: (json['payment_method'] ?? json['paymentMethod'])
          ?.toString(),
      errorMessage: (json['error_message'] ?? json['errorMessage'])?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class PaginatedTransactionsState {
  final List<WorkerTransactionModel> items;
  final int page;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;

  const PaginatedTransactionsState({
    this.items = const [],
    this.page = 1,
    this.total = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  PaginatedTransactionsState copyWith({
    List<WorkerTransactionModel>? items,
    int? page,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PaginatedTransactionsState(
      items: items ?? this.items,
      page: page ?? this.page,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}
