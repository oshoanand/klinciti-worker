typedef JsonMap = Map<String, dynamic>;

class AssignedCategoryItem {
  final String id;
  final String name;
  final String? parentId;
  final String? icon;

  const AssignedCategoryItem({
    required this.id,
    required this.name,
    this.parentId,
    this.icon,
  });

  factory AssignedCategoryItem.fromJson(JsonMap json) {
    return AssignedCategoryItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      parentId: json['parent_id']?.toString() ?? json['parentId']?.toString(),
      icon: json['icon']?.toString(),
    );
  }
}

class WorkerProfileModel {
  final String id;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final String? email;
  final String? mobile;
  final String? emailVerified;
  final String? mobileVerified;
  final String? image;
  final String? backgroundImage;

  // Legal & Banking Fields (Russian compliance)
  final String legalType; // 'SELF_EMPLOYED' | 'IP' | 'OOO'
  final String? inn;
  final String? companyName;
  final String? bankName;
  final String? bankBik;
  final String? checkingAccount;
  final String? correspondentAccount;
  final String? taxId; // Legacy fallback
  final String? payoutDetails; // Legacy fallback

  // Professional & Vehicle Fields
  final String? city;
  final String? address;
  final String? gender;
  final String? experience;
  final String? description;
  final bool hasVehicle;
  final String? vehicleModel;
  final String? vehicleNumber;
  final List<AssignedCategoryItem> categories;
  final List<String> categoryIds;

  const WorkerProfileModel({
    required this.id,
    this.name,
    this.firstName,
    this.lastName,
    this.middleName,
    this.email,
    this.mobile,
    this.emailVerified,
    this.mobileVerified,
    this.image,
    this.backgroundImage,
    this.legalType = 'SELF_EMPLOYED',
    this.inn,
    this.companyName,
    this.bankName,
    this.bankBik,
    this.checkingAccount,
    this.correspondentAccount,
    this.taxId,
    this.payoutDetails,
    this.city,
    this.address,
    this.gender,
    this.experience,
    this.description,
    this.hasVehicle = false,
    this.vehicleModel,
    this.vehicleNumber,
    this.categories = const [],
    this.categoryIds = const [],
  });

  factory WorkerProfileModel.fromJson(JsonMap rawJson) {
    // Unwrap `{ data: { ... } }` if backend wraps the response
    final JsonMap json = (rawJson['data'] is Map)
        ? JsonMap.from(rawJson['data'] as Map)
        : rawJson;

    final rawCats = (json['categories'] as List<dynamic>?) ?? const [];
    final parsedCats = rawCats
        .whereType()
        .map((c) => AssignedCategoryItem.fromJson(JsonMap.from(c)))
        .toList();

    final rawCatIdsList = json['categoryIds'] ?? json['category_ids'];
    final List<String> rawCatIds = rawCatIdsList is List
        ? rawCatIdsList.map((e) => e.toString()).toList()
        : parsedCats.map((c) => c.id).toList();

    // Safely parse experience whether String, num, or List
    String? parsedExperience;
    final rawExp = json['experience'];
    if (rawExp is List) {
      parsedExperience = rawExp.isNotEmpty
          ? rawExp.first.toString().trim()
          : null;
    } else if (rawExp != null) {
      parsedExperience = rawExp.toString().trim();
    }

    final rawLegalType =
        (json['legal_type'] ?? json['legalType'] ?? 'SELF_EMPLOYED')
            .toString()
            .toUpperCase();

    return WorkerProfileModel(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? '',
      name: json['name']?.toString(),
      firstName:
          json['first_name']?.toString() ?? json['firstName']?.toString(),
      lastName: json['last_name']?.toString() ?? json['lastName']?.toString(),
      middleName:
          json['middle_name']?.toString() ?? json['middleName']?.toString(),
      email: json['email']?.toString(),
      mobile: json['mobile']?.toString(),
      emailVerified:
          json['email_verified']?.toString() ??
          json['emailVerified']?.toString(),
      mobileVerified:
          json['mobile_verified']?.toString() ??
          json['mobileVerified']?.toString(),
      image: (json['image'] ?? json['photo'] ?? json['avatarUrl'])?.toString(),
      backgroundImage:
          json['background_image']?.toString() ??
          json['backgroundImage']?.toString(),

      // Legal & Banking
      legalType: (rawLegalType == 'IP' || rawLegalType == 'OOO')
          ? rawLegalType
          : 'SELF_EMPLOYED',
      inn: (json['inn'] ?? json['tax_id'] ?? json['taxId'])?.toString(),
      companyName: (json['company_name'] ?? json['companyName'])?.toString(),
      bankName: (json['bank_name'] ?? json['bankName'])?.toString(),
      bankBik: (json['bank_bik'] ?? json['bankBik'])?.toString(),
      checkingAccount: (json['checking_account'] ?? json['checkingAccount'])
          ?.toString(),
      correspondentAccount:
          (json['correspondent_account'] ?? json['correspondentAccount'])
              ?.toString(),
      taxId: (json['tax_id'] ?? json['taxId'])?.toString(),
      payoutDetails: (json['payout_details'] ?? json['payoutDetails'])
          ?.toString(),

      // Professional & Vehicle
      city: json['city']?.toString(),
      address: json['address']?.toString(),
      gender: json['gender']?.toString(),
      experience: parsedExperience,
      description: json['description']?.toString(),
      hasVehicle: json['has_vehicle'] == true || json['hasVehicle'] == true,
      vehicleModel:
          json['vehicle_model']?.toString() ?? json['vehicleModel']?.toString(),
      vehicleNumber:
          json['vehicle_number']?.toString() ??
          json['vehicleNumber']?.toString(),
      categories: parsedCats,
      categoryIds: rawCatIds,
    );
  }
}
