class JobStatsModel {
  final int pending;
  final int accepted; // Incoming requests assigned to the worker
  final int ongoing;
  final int disputed;
  final int completed;
  final int cancelled;
  final int refused;
  final int paymentPending;
  final int paid;

  const JobStatsModel({
    this.pending = 0,
    this.accepted = 0,
    this.ongoing = 0,
    this.disputed = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.refused = 0,
    this.paymentPending = 0,
    this.paid = 0,
  });

  factory JobStatsModel.fromJson(Map<String, dynamic> json) {
    int parseIntSafe(dynamic val) => (val as num?)?.toInt() ?? 0;

    return JobStatsModel(
      pending: parseIntSafe(json['PENDING']),
      accepted: parseIntSafe(json['ACCEPTED']),
      ongoing: parseIntSafe(json['ONGOING']),
      disputed: parseIntSafe(json['DISPUTED']),
      completed: parseIntSafe(json['COMPLETED']),
      cancelled: parseIntSafe(json['CANCELLED']),
      refused: parseIntSafe(json['REFUSED']),
      paymentPending: parseIntSafe(json['PAYMENT_PENDING']),
      paid: parseIntSafe(json['PAID']),
    );
  }
}

class PaginatedJobsResponse {
  final List<JobModel> jobs;
  final int total;
  final int page;
  final int limit;
  final String status;

  const PaginatedJobsResponse({
    required this.jobs,
    required this.total,
    required this.page,
    required this.limit,
    required this.status,
  });

  bool get hasMore => (page * limit) < total;

  factory PaginatedJobsResponse.fromJson(Map<String, dynamic> json) {
    final rawList = (json['data'] as List<dynamic>?) ?? [];
    final meta = (json['meta'] as Map<String, dynamic>?) ?? {};

    return PaginatedJobsResponse(
      jobs: rawList
          .map(
            (item) => JobModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      total: (meta['total'] as num?)?.toInt() ?? rawList.length,
      page: (meta['page'] as num?)?.toInt() ?? 1,
      limit: (meta['limit'] as num?)?.toInt() ?? 20,
      status: meta['status']?.toString() ?? 'ACCEPTED',
    );
  }
}

class JobModel {
  final String id;
  final String description;
  final double budget;
  final String city;
  final String pickupAddress;
  final String
  status; // ACCEPTED, ONGOING, COMPLETED, DISPUTED, CANCELLED, REFUSED
  final String paymentStatus; // PENDING, PAID
  final String? paymentMethod;
  final String? timing;
  final DateTime? createdAt;
  final List<String> photos;
  final List<String> completionPhotos;
  final String? workerComment;
  final String? completionComment;
  final String? customerId;
  final String? customerName;
  final String? customerMobile;
  final String? customerImage;
  final String? workerName;
  final String categoryName;
  final String? subcategoryName;

  const JobModel({
    required this.id,
    required this.description,
    required this.budget,
    required this.city,
    required this.pickupAddress,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod,
    this.timing,
    this.createdAt,
    this.photos = const [],
    this.completionPhotos = const [],
    this.workerComment,
    this.completionComment,
    this.customerId,
    this.customerName,
    this.customerMobile,
    this.customerImage,
    this.workerName,
    required this.categoryName,
    this.subcategoryName,
  });

  String get displayTitle =>
      subcategoryName != null && subcategoryName!.trim().isNotEmpty
      ? '$categoryName • $subcategoryName'
      : categoryName;

  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static double _parseBudget(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0.0;
    return 0.0;
  }

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      budget: _parseBudget(json['budget']),
      city: json['city']?.toString() ?? '',
      pickupAddress: json['pickup_address']?.toString() ?? 'Адрес не указан',
      status: json['status']?.toString() ?? 'ACCEPTED',
      paymentStatus: json['payment_status']?.toString() ?? 'PENDING',
      paymentMethod: json['payment_method']?.toString(),
      timing: json['timing']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      photos: _parseStringList(json['photos']),
      completionPhotos: _parseStringList(json['completion_photos']),
      workerComment: json['worker_comment']?.toString(),
      completionComment: json['completion_comment']?.toString(),
      customerId: json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString() ?? 'Клиент',
      customerMobile: json['customer_mobile']?.toString(),
      customerImage: json['customer_image']?.toString(),
      workerName: json['worker_name']?.toString(),
      categoryName: json['category_name']?.toString() ?? 'Заказ',
      subcategoryName: json['subcategory_name']?.toString(),
    );
  }
}
