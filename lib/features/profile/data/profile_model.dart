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

  factory AssignedCategoryItem.fromJson(Map<String, dynamic> json) {
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
  final String? city;
  final String? address;
  final String? gender;
  final String? experience;
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
    this.city,
    this.address,
    this.gender,
    this.experience,
    this.hasVehicle = false,
    this.vehicleModel,
    this.vehicleNumber,
    this.categories = const [],
    this.categoryIds = const [],
  });

  factory WorkerProfileModel.fromJson(Map<String, dynamic> json) {
    final rawCats = (json['categories'] as List<dynamic>?) ?? [];
    final parsedCats = rawCats
        .map(
          (c) => AssignedCategoryItem.fromJson(
            Map<String, dynamic>.from(c as Map),
          ),
        )
        .toList();

    final rawCatIds =
        (json['categoryIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        parsedCats.map((c) => c.id).toList();

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
      image: json['image']?.toString(),
      backgroundImage:
          json['background_image']?.toString() ??
          json['backgroundImage']?.toString(),
      city: json['city']?.toString(),
      address: json['address']?.toString(),
      gender: json['gender']?.toString(),
      experience: json['experience']?.toString(),
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

// Backwards-compatible alias
typedef CustomerProfileModel = WorkerProfileModel;
