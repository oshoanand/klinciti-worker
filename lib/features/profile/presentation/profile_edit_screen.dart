import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exceptions.dart';
import '../../auth/providers/auth_provider.dart';
import '../../registration/data/category_model.dart';
import '../../registration/providers/registration_provider.dart';
import '../providers/profile_provider.dart';

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

  // Personal Fields
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _gender; // 'MALE' | 'FEMALE' | null
  String? _avatarUrl;
  File? _localAvatarFile;

  // Legal & Financial Fields (Russian Compliance)
  LegalType _legalType = LegalType.selfEmployed;
  final _innController = TextEditingController();
  final _companyController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankBikController = TextEditingController();
  final _checkingAccountController = TextEditingController();
  final _correspondentAccountController = TextEditingController();

  // Professional & Vehicle Fields
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _experienceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  bool _hasVehicle = false;

  final StringSet _selectedCategoryIds = <String>{};

  bool _isLoadingProfile = true;
  bool _isUploadingAvatar = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWorkerProfile();
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _innController.dispose();
    _companyController.dispose();
    _bankNameController.dispose();
    _bankBikController.dispose();
    _checkingAccountController.dispose();
    _correspondentAccountController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _experienceController.dispose();
    _descriptionController.dispose();
    _vehicleModelController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. FETCH INITIAL WORKER PROFILE VIA PROVIDER
  // ==========================================
  Future<void> _loadWorkerProfile() async {
    setState(() => _isLoadingProfile = true);

    try {
      final profile = await ref
          .read(profileMutationProvider.notifier)
          .fetchProfileForEdit();
      if (!mounted) return;

      final cachedUser = ref.read(currentUserProvider) ?? JsonMap();

      String firstName = (profile.firstName ?? cachedUser['first_name'] ?? '')
          .toString()
          .trim();
      String middleName =
          (profile.middleName ?? cachedUser['middle_name'] ?? '')
              .toString()
              .trim();
      String lastName = (profile.lastName ?? cachedUser['last_name'] ?? '')
          .toString()
          .trim();

      // Split full name if first/last names were not stored separately yet
      if (firstName.isEmpty && lastName.isEmpty) {
        final fullName = (profile.name ?? cachedUser['name'] ?? '')
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
      _avatarUrl = profile.image ?? cachedUser['image']?.toString();

      final rawGender = profile.gender?.toUpperCase();
      if (rawGender == 'MALE' || rawGender == 'FEMALE') {
        _gender = rawGender;
      }

      // Legal & Banking
      switch (profile.legalType.toUpperCase()) {
        case 'IP':
          _legalType = LegalType.ip;
          break;
        case 'OOO':
          _legalType = LegalType.ooo;
          break;
        default:
          _legalType = LegalType.selfEmployed;
      }

      _innController.text = (profile.inn ?? '').trim();
      _companyController.text = (profile.companyName ?? '').trim();
      _bankNameController.text = (profile.bankName ?? '').trim();
      _bankBikController.text = (profile.bankBik ?? '').trim();
      _checkingAccountController.text = (profile.checkingAccount ?? '').trim();
      _correspondentAccountController.text =
          (profile.correspondentAccount ?? '').trim();

      // Professional & Vehicle
      _cityController.text = (profile.city ?? '').trim();
      _addressController.text = (profile.address ?? '').trim();
      _experienceController.text = (profile.experience ?? '').trim();
      _descriptionController.text = (profile.description ?? '').trim();

      _hasVehicle = profile.hasVehicle;
      _vehicleModelController.text = (profile.vehicleModel ?? '').trim();
      _vehicleNumberController.text = (profile.vehicleNumber ?? '').trim();

      _selectedCategoryIds
        ..clear()
        ..addAll(profile.categoryIds);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить профиль: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки профиля: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  // ==========================================
  // 2. AVATAR UPLOAD VIA PROVIDER
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

      final uploadedUrl = await ref
          .read(profileMutationProvider.notifier)
          .uploadAndSetAvatar(file);

      if (!mounted) return;
      setState(() => _avatarUrl = uploadedUrl);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки фото: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки фото: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
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
  // 4. SAVE PROFILE VIA PROVIDER
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

    setState(() => _errorMessage = null);

    try {
      final firstName = _firstNameController.text.trim();
      final middleName = _middleNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final description = _descriptionController.text.trim();
      final bankName = _bankNameController.text.trim();
      final bankBik = _bankBikController.text.trim();
      final checkingAccount = _checkingAccountController.text.trim();
      final correspondentAccount = _correspondentAccountController.text.trim();

      final payload = <String, dynamic>{
        // Personal Info
        'firstName': firstName,
        'middleName': middleName.isEmpty ? null : middleName,
        'lastName': lastName,
        if (_gender != null) 'gender': _gender,
        if (_avatarUrl != null && _avatarUrl!.isNotEmpty) 'image': _avatarUrl,

        // Legal & Russian Banking Details
        'legalType': _legalType.toBackendString(),
        'inn': _innController.text.trim(),
        'companyName': _legalType != LegalType.selfEmployed
            ? _companyController.text.trim()
            : null,
        'bankName': bankName.isEmpty ? null : bankName,
        'bankBik': bankBik.isEmpty ? null : bankBik,
        'checkingAccount': checkingAccount.isEmpty ? null : checkingAccount,
        'correspondentAccount': correspondentAccount.isEmpty
            ? null
            : correspondentAccount,

        // Professional & Vehicle Info
        'city': _cityController.text.trim(),
        'address': _addressController.text.trim(),
        'experience': _experienceController.text.trim(),
        'description': description.isEmpty ? null : description,
        'hasVehicle': _hasVehicle,
        'vehicleModel': _hasVehicle
            ? _vehicleModelController.text.trim()
            : null,
        'vehicleNumber': _hasVehicle
            ? _vehicleNumberController.text.trim().toUpperCase()
            : null,
        'categoryIds': _selectedCategoryIds.toList(),
      };

      final result = await ref
          .read(profileMutationProvider.notifier)
          .updateProfile(payload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.green),
      );

      if (context.canPop()) {
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Ошибка сохранения: $e');
      }
    }
  }

  // ==========================================
  // UI HELPERS
  // ==========================================
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
              onChanged: (_) => _toggleMainCategory(mainCat, !allSubsSelected),
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

  // ==========================================
  // BUILD METHOD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesTreeProvider);
    final isMutating = ref.watch(profileMutationProvider);
    final hasNetworkAvatar =
        _avatarUrl != null && _avatarUrl!.trim().isNotEmpty;
    final isOOO = _legalType == LegalType.ooo;
    final innLength = isOOO ? 10 : 12;

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
                      controller: _middleNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        label: 'Отчество (необязательно)',
                        icon: LucideIcons.user,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
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

                    // ==========================================
                    // LEGAL & FINANCIAL INFO
                    // ==========================================
                    const Text(
                      'Юридический статус и реквизиты',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<LegalType>(
                      initialValue: _legalType,
                      decoration: _inputDecoration(
                        label: 'Правовой статус *',
                        icon: LucideIcons.briefcase,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: LegalType.selfEmployed,
                          child: Text('Самозанятый (НПД)'),
                        ),
                        DropdownMenuItem(
                          value: LegalType.ip,
                          child: Text('ИП (Индивидуальный предприниматель)'),
                        ),
                        DropdownMenuItem(
                          value: LegalType.ooo,
                          child: Text('ООО (Юридическое лицо)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null && val != _legalType) {
                          setState(() {
                            final oldWasOOO = _legalType == LegalType.ooo;
                            final newIsOOO = val == LegalType.ooo;
                            _legalType = val;
                            // Clear INN only if switching between 10-digit (OOO) and 12-digit (IP/Self-Employed)
                            if (oldWasOOO != newIsOOO) {
                              _innController.clear();
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _innController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: innLength,
                      decoration: _inputDecoration(
                        label: 'ИНН *',
                        hint: isOOO ? '10 цифр' : '12 цифр',
                        icon: LucideIcons.file_text,
                      ).copyWith(counterText: ''),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Введите ИНН';
                        }
                        if (val.trim().length != innLength) {
                          return 'ИНН должен содержать $innLength цифр';
                        }
                        return null;
                      },
                    ),
                    if (_legalType != LegalType.selfEmployed) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _companyController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration(
                          label: _legalType == LegalType.ip
                              ? 'Полное наименование ИП *'
                              : 'Название ООО *',
                          hint: _legalType == LegalType.ip
                              ? 'ИП Иванов Иван Иванович'
                              : 'ООО "Ромашка"',
                          icon: LucideIcons.building,
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Обязательное поле'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _bankNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        label: 'Название банка *',
                        hint: 'Например: ПАО Сбербанк',
                        icon: LucideIcons.landmark,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Укажите название банка'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _bankBikController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 9,
                      decoration: _inputDecoration(
                        label: 'БИК банка *',
                        hint: '9 цифр',
                        icon: LucideIcons.hash,
                      ).copyWith(counterText: ''),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Введите БИК банка';
                        }
                        if (val.trim().length != 9) {
                          return 'БИК должен содержать ровно 9 цифр';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _checkingAccountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 20,
                      decoration: _inputDecoration(
                        label: 'Расчетный счет (р/с) *',
                        hint: '20 цифр',
                        icon: LucideIcons.wallet,
                      ).copyWith(counterText: ''),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Введите расчетный счет';
                        }
                        if (val.trim().length != 20) {
                          return 'Расчетный счет должен содержать 20 цифр';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _correspondentAccountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 20,
                      decoration: _inputDecoration(
                        label: 'Корреспондентский счет (к/с) *',
                        hint: '20 цифр (начинается с 301)',
                        icon: LucideIcons.arrow_right_left,
                      ).copyWith(counterText: ''),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Введите корр. счет';
                        }
                        if (val.trim().length != 20) {
                          return 'Корр. счет должен содержать 20 цифр';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    // ==========================================
                    // PROFESSIONAL DATA
                    // ==========================================
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
                        icon: LucideIcons.calendar,
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
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      minLines: 2,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        label: 'О себе и своем опыте',
                        hint: 'Расскажите о своих навыках, наличии профессионального инструмента и выполненных работах...',
                        icon: LucideIcons.file_text,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ==========================================
                    // VEHICLE TOGGLE & INPUTS
                    // ==========================================
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
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF0F172A),
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

                    // ==========================================
                    // CATEGORIES
                    // ==========================================
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
                                  ref.invalidate(categoriesTreeProvider),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Повторить'),
                            ),
                          ],
                        ),
                      ),
                      data: _buildCategoryTree,
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (isMutating || _isUploadingAvatar)
                            ? null
                            : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isMutating
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
