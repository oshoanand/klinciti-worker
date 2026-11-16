import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/uploader_service.dart';
import '../../../shared/layouts/profile_drawer.dart';
import '../../auth/providers/auth_provider.dart';
import '../../registration/data/category_model.dart';
import '../../registration/providers/registration_provider.dart';

typedef JsonMap = Map<String, dynamic>;
typedef StringSet = Set<String>;

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _experienceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleNumberController = TextEditingController();

  bool _isLoadingProfile = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _hasVehicle = false;

  String? _gender; // 'MALE' | 'FEMALE' | null
  String? _avatarUrl;
  File? _localAvatarFile;

  final StringSet _selectedCategoryIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadWorkerProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _experienceController.dispose();
    _descriptionController.dispose();
    _vehicleModelController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. FETCH INITIAL WORKER PROFILE
  // ==========================================
  Future<void> _loadWorkerProfile() async {
    setState(() => _isLoadingProfile = true);

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.dio.get('/workers/profile');
      if (!mounted) return;

      final data = response.data is Map
          ? JsonMap.from(response.data as Map)
          : JsonMap();

      // Fallback to cached user data if any field is missing
      final cachedUser = ref.read(currentUserProvider) ?? JsonMap();

      String firstName =
          (data['first_name'] ??
                  data['firstName'] ??
                  cachedUser['first_name'] ??
                  '')
              .toString()
              .trim();
      String middleName =
          (data['middle_name'] ??
                  data['middleName'] ??
                  cachedUser['middle_name'] ??
                  '')
              .toString()
              .trim();
      String lastName =
          (data['last_name'] ??
                  data['lastName'] ??
                  cachedUser['last_name'] ??
                  '')
              .toString()
              .trim();

      // If first_name / last_name were not split yet, split `name`
      if (firstName.isEmpty && lastName.isEmpty) {
        final fullName = (data['name'] ?? cachedUser['name'] ?? '')
            .toString()
            .trim();
        if (fullName.isNotEmpty) {
          final parts = fullName.split(RegExp(r'\s+'));
          if (parts.isNotEmpty) firstName = parts[0];
          if (parts.length == 2) lastName = parts[1];
          if (parts.length >= 3) {
            middleName = parts[1];
            lastName = parts.sublist(2).join(' ');
          }
        }
      }

      _firstNameController.text = firstName;
      _middleNameController.text = middleName;
      _lastNameController.text = lastName;

      _cityController.text = (data['city'] ?? '').toString().trim();
      _addressController.text = (data['address'] ?? '').toString().trim();

      // Safely normalize `experience` whether String, num, or legacy List
      final rawExp = data['experience'];
      if (rawExp is List) {
        _experienceController.text = rawExp.isNotEmpty
            ? rawExp.first.toString().trim()
            : '';
      } else if (rawExp != null) {
        _experienceController.text = rawExp.toString().trim();
      } else {
        _experienceController.text = '';
      }

      // Load optional `description`
      _descriptionController.text = (data['description'] ?? '')
          .toString()
          .trim();

      _hasVehicle = data['has_vehicle'] == true || data['hasVehicle'] == true;
      _vehicleModelController.text =
          (data['vehicle_model'] ?? data['vehicleModel'] ?? '')
              .toString()
              .trim();
      _vehicleNumberController.text =
          (data['vehicle_number'] ?? data['vehicleNumber'] ?? '')
              .toString()
              .trim();

      final rawGender = data['gender']?.toString().toUpperCase();
      if (rawGender == 'MALE' || rawGender == 'FEMALE') {
        _gender = rawGender;
      }

      _avatarUrl = (data['image'] ?? data['photo'] ?? cachedUser['image'])
          ?.toString();

      final rawCats = data['categoryIds'] ?? data['category_ids'];
      if (rawCats is List) {
        _selectedCategoryIds
          ..clear()
          ..addAll(rawCats.map((e) => e.toString()));
      }
    } catch (e) {
      if (mounted) {
        final msg = ApiException.fromDioException(e).message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить профиль: $msg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  // ==========================================
  // 2. AVATAR UPLOAD TO MINIO
  // ==========================================
  Future<void> _pickAndUploadAvatar() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Фото профиля',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  LucideIcons.camera,
                  color: Color(0xFF0F172A),
                ),
                title: const Text('Сделать фото'),
                onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  LucideIcons.image,
                  color: Color(0xFF0F172A),
                ),
                title: const Text('Выбрать из галереи'),
                onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked == null) return;

      final file = File(picked.path);

      setState(() {
        _localAvatarFile = file;
        _isUploadingAvatar = true;
      });
      ref.read(isAvatarUploadingProvider.notifier).state = true;

      final uploader = ref.read(uploaderServiceProvider);
      final uploadedUrl = await uploader.uploadFileDirectly(
        file: file,
        endpoint: '/workers/profile/upload-url',
        payloadData: {'folder': 'avatars'},
        compress: true,
        imageContext: 'avatar',
        isGetRequest: false,
      );

      if (!mounted) return;

      setState(() => _avatarUrl = uploadedUrl);

      // Immediately update avatar in currentUserProvider so Drawer reflects it
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        ref.read(currentUserProvider.notifier).state = {
          ...currentUser,
          'image': uploadedUrl,
        };
      }
    } catch (e) {
      if (mounted) {
        final msg = ApiException.fromDioException(e).message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки фото: $msg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ref.read(isAvatarUploadingProvider.notifier).state = false;
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  // ==========================================
  // 3. CATEGORY SELECTION LOGIC
  // ==========================================
  void _toggleMainCategory(CategoryModel mainCat, bool? isChecked) {
    setState(() {
      if (isChecked == true) {
        _selectedCategoryIds.add(mainCat.id);
        for (final sub in mainCat.subcategories) {
          _selectedCategoryIds.add(sub.id);
        }
      } else {
        _selectedCategoryIds.remove(mainCat.id);
        for (final sub in mainCat.subcategories) {
          _selectedCategoryIds.remove(sub.id);
        }
      }
    });
  }

  void _toggleSubCategory(
    CategoryModel mainCat,
    CategoryModel subCat,
    bool? isChecked,
  ) {
    setState(() {
      if (isChecked == true) {
        _selectedCategoryIds.add(subCat.id);
        _selectedCategoryIds.add(mainCat.id);
      } else {
        _selectedCategoryIds.remove(subCat.id);
        final anySubSelected = mainCat.subcategories.any(
          (s) => _selectedCategoryIds.contains(s.id),
        );
        if (!anySubSelected) {
          _selectedCategoryIds.remove(mainCat.id);
        }
      }
    });
  }

  // ==========================================
  // 4. SAVE PROFILE TO PUT /workers/profile
  // ==========================================
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите хотя бы одну категорию услуг'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final firstName = _firstNameController.text.trim();
      final middleName = _middleNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final city = _cityController.text.trim();
      final address = _addressController.text.trim();
      final experience = _experienceController.text.trim();
      final description = _descriptionController.text.trim();

      final payload = <String, dynamic>{
        'firstName': firstName,
        'middleName': middleName.isEmpty ? null : middleName,
        'lastName': lastName,
        'city': city,
        'address': address,
        'experience': experience, // Sent as clean String
        'description': description.isEmpty ? null : description, // Optional bio
        'hasVehicle': _hasVehicle,
        'vehicleModel': _hasVehicle
            ? _vehicleModelController.text.trim()
            : null,
        'vehicleNumber': _hasVehicle
            ? _vehicleNumberController.text.trim().toUpperCase()
            : null,
        if (_gender != null) 'gender': _gender,
        if (_avatarUrl != null && _avatarUrl!.isNotEmpty) 'image': _avatarUrl,
        'categoryIds': _selectedCategoryIds.toList(),
      };

      final api = ref.read(apiClientProvider);
      await api.dio.patch('/workers/profile', data: payload);

      // Sync updated fields into currentUserProvider
      final currentUser = ref.read(currentUserProvider) ?? JsonMap();
      final fullName = [
        firstName,
        middleName,
        lastName,
      ].where((part) => part.isNotEmpty).join(' ');

      ref.read(currentUserProvider.notifier).state = {
        ...currentUser,
        'name': fullName,
        'first_name': firstName,
        'middle_name': middleName,
        'last_name': lastName,
        'city': city,
        'address': address,
        'experience': experience,
        'description': description.isEmpty ? null : description,
        if (_avatarUrl != null) 'image': _avatarUrl,
      };

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Профиль успешно сохранен'),
          backgroundColor: Colors.green,
        ),
      );

      if (context.canPop()) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final msg = ApiException.fromDioException(e).message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
      ),
    );
  }

  Widget _buildCategoryTree(List<CategoryModel> categories) {
    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Категории временно недоступны'),
      );
    }

    return Column(
      children: categories.map((mainCat) {
        final hasSubs = mainCat.subcategories.isNotEmpty;
        final selectedSubCount = mainCat.subcategories
            .where((s) => _selectedCategoryIds.contains(s.id))
            .length;

        final isMainSelected = _selectedCategoryIds.contains(mainCat.id);
        final allSubsSelected =
            hasSubs && selectedSubCount == mainCat.subcategories.length;
        final someSubsSelected =
            hasSubs && selectedSubCount > 0 && !allSubsSelected;

        if (!hasSubs) {
          return Card(
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isMainSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFE2E8F0),
                width: isMainSelected ? 1.5 : 1.0,
              ),
            ),
            child: CheckboxListTile(
              activeColor: const Color(0xFF0F172A),
              value: isMainSelected,
              title: Text(
                mainCat.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onChanged: (val) => _toggleMainCategory(mainCat, val),
            ),
          );
        }

        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: (isMainSelected || selectedSubCount > 0)
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFE2E8F0),
              width: (isMainSelected || selectedSubCount > 0) ? 1.5 : 1.0,
            ),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Checkbox(
              activeColor: const Color(0xFF0F172A),
              tristate: true,
              value: allSubsSelected
                  ? true
                  : (someSubsSelected ? null : isMainSelected),
              onChanged: (val) {
                final shouldSelectAll = !allSubsSelected;
                _toggleMainCategory(mainCat, shouldSelectAll);
              },
            ),
            title: Text(
              mainCat.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              selectedSubCount > 0
                  ? 'Выбрано подкатегорий: $selectedSubCount из ${mainCat.subcategories.length}'
                  : 'Нажмите, чтобы выбрать специализации',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selectedSubCount > 0
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: selectedSubCount > 0
                    ? const Color(0xFF2563EB)
                    : Colors.grey.shade600,
              ),
            ),
            children: mainCat.subcategories.map((subCat) {
              final isSubSelected = _selectedCategoryIds.contains(subCat.id);
              return CheckboxListTile(
                activeColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.only(left: 32, right: 16),
                dense: true,
                title: Text(subCat.name),
                value: isSubSelected,
                onChanged: (val) => _toggleSubCategory(mainCat, subCat, val),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesTreeProvider);
    final hasNetworkAvatar =
        _avatarUrl != null && _avatarUrl!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrow_left, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Редактировать профиль',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // ==========================================
                    // AVATAR PICKER HEADER
                    // ==========================================
                    Center(
                      child: GestureDetector(
                        onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                image: _localAvatarFile != null
                                    ? DecorationImage(
                                        image: FileImage(_localAvatarFile!),
                                        fit: BoxFit.cover,
                                      )
                                    : (hasNetworkAvatar
                                          ? DecorationImage(
                                              image: CachedNetworkImageProvider(
                                                _avatarUrl!,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null),
                              ),
                              child:
                                  (_localAvatarFile == null &&
                                      !hasNetworkAvatar)
                                  ? const Icon(
                                      LucideIcons.user,
                                      size: 40,
                                      color: Color(0xFF64748B),
                                    )
                                  : null,
                            ),
                            if (_isUploadingAvatar)
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black38,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(24),
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  LucideIcons.camera,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ==========================================
                    // PERSONAL INFO
                    // ==========================================
                    const Text(
                      'Личные данные',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        label: 'Имя *',
                        icon: LucideIcons.user,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Укажите имя' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        label: 'Фамилия *',
                        icon: LucideIcons.user,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Укажите фамилию'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _middleNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        label: 'Отчество (необязательно)',
                        icon: LucideIcons.user,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Gender Selector
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: _inputDecoration(
                        label: 'Пол (необязательно)',
                        icon: LucideIcons.users,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'MALE', child: Text('Мужской')),
                        DropdownMenuItem(
                          value: 'FEMALE',
                          child: Text('Женский'),
                        ),
                      ],
                      onChanged: (val) => setState(() => _gender = val),
                    ),

                    const SizedBox(height: 28),
                    const Text(
                      'Профессиональные данные',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        label: 'Город *',
                        hint: 'Например: Москва',
                        icon: LucideIcons.building_complex,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Укажите город'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        label: 'Адрес проживания *',
                        hint: 'Улица, дом',
                        icon: LucideIcons.map_pin,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Укажите адрес'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration(
                        label: 'Опыт работы (полных лет) *',
                        hint: 'Например: 3',
                        icon: LucideIcons.briefcase,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Укажите опыт работы';
                        }
                        final parsed = int.tryParse(v.trim());
                        if (parsed == null || parsed < 0) {
                          return 'Введите корректное число';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Optional Worker Description / Bio
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      minLines: 2,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        label: 'О себе и своем опыте (необязательно)',
                        hint: 'Расскажите о своих навыках, наличии профессионального инструмента и выполненных работах...',
                        icon: LucideIcons.file_text,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Vehicle Toggle & Inputs
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF0F172A),
                        title: const Text(
                          'Есть личный автомобиль',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: const Text(
                          'Позволяет брать заказы с выездом и доставкой',
                          style: TextStyle(fontSize: 12.5),
                        ),
                        value: _hasVehicle,
                        onChanged: (val) => setState(() => _hasVehicle = val),
                      ),
                    ),
                    if (_hasVehicle) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _vehicleModelController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration(
                          label: 'Марка и модель авто *',
                          hint: 'Например: Lada Largus',
                          icon: LucideIcons.car,
                        ),
                        validator: (v) {
                          if (_hasVehicle && (v == null || v.trim().isEmpty)) {
                            return 'Укажите марку и модель авто';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _vehicleNumberController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _inputDecoration(
                          label: 'Госномер авто *',
                          hint: 'Например: А123ВС 77',
                          icon: LucideIcons.hash,
                        ),
                        validator: (v) {
                          if (_hasVehicle && (v == null || v.trim().isEmpty)) {
                            return 'Укажите госномер автомобиля';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Категории услуг *',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_selectedCategoryIds.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Выбрано: ${_selectedCategoryIds.length}',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Отметьте специализации, по которым вы принимаете заказы',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    categoriesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Text(
                              'Не удалось загрузить категории: $err',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  ref.refresh(categoriesTreeProvider),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Повторить'),
                            ),
                          ],
                        ),
                      ),
                      data: _buildCategoryTree,
                    ),

                    const SizedBox(height: 28),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (_isSaving || _isUploadingAvatar)
                            ? null
                            : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Сохранить изменения',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
