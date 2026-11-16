class UserModel {
  final String id;
  final String role;
  final String? name;
  final String? email;
  final String? mobile;
  final String? image;
  final bool needsVerification;
  final String? moderationStatus;

  UserModel({
    required this.id,
    required this.role,
    this.name,
    this.email,
    this.mobile,
    this.image,
    this.needsVerification = false,
    this.moderationStatus,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      role: json['role'] ?? 'WORKER',
      name: json['name'],
      email: json['email'],
      mobile: json['mobile'],
      image: json['image'],
      needsVerification: json['needsVerification'] ?? false,
      moderationStatus: json['moderationStatus'],
    );
  }
}
