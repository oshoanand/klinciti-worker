import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/router/route_names.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/registration_provider.dart';

class Step3Screen extends ConsumerStatefulWidget {
  const Step3Screen({super.key});

  @override
  ConsumerState<Step3Screen> createState() => _Step3ScreenState();
}

class _Step3ScreenState extends ConsumerState<Step3Screen> {
  final _formKey = GlobalKey<FormState>();
  final _dobDisplayController = TextEditingController();
  final _passportController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  DateTime? _selectedDob;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Uploaded MinIO public URLs
  final Map<String, String?> _uploadedUrls = {
    'id_front': null,
    'id_back': null,
    'selfie': null,
    'drivers_license': null,
  };

  // Local files for instant UI preview
  final Map<String, File?> _localFiles = {
    'id_front': null,
    'id_back': null,
    'selfie': null,
    'drivers_license': null,
  };

  // Per-document loading state
  final Map<String, bool> _uploadingState = {
    'id_front': false,
    'id_back': false,
    'selfie': false,
    'drivers_license': false,
  };

  @override
  void dispose() {
    _dobDisplayController.dispose();
    _passportController.dispose();
    super.dispose();
  }

  // ==========================================
  // DATE OF BIRTH PICKER (18+ Validation)
  // ==========================================
  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    // ✅ FIXED: Restored subtraction operator `-`
    final maxDate = DateTime(now.year - 18, now.month, now.day);
    final initialDate =
        _selectedDob ?? DateTime(now.year - 25, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(maxDate) ? maxDate : initialDate,
      firstDate: DateTime(1940, 1, 1),
      lastDate: maxDate,
      helpText: 'Выберите дату рождения (18+)',
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        final day = picked.day.toString().padLeft(2, '0');
        final month = picked.month.toString().padLeft(2, '0');
        _dobDisplayController.text = '$day.$month.${picked.year}';
      });
    }
  }

  // ==========================================
  // BOTTOM SHEET: CAMERA OR GALLERY
  // ==========================================
  Future<void> _showImageSourceSheet(String docType, String title) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.blue,
                  ),
                  title: const Text('Сделать фото (Камера)'),
                  subtitle: Text(
                    docType == 'selfie'
                        ? 'Откроется фронтальная камера'
                        : 'Сфотографируйте оригинал документа',
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.blue,
                  ),
                  title: const Text('Выбрать из галереи'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
                if (_uploadedUrls[docType] != null &&
                    (docType == 'id_back' || docType == 'drivers_license'))
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Удалить фото',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      setState(() {
                        _uploadedUrls[docType] = null;
                        _localFiles[docType] = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (source != null) {
      await _pickAndUploadDocument(docType, source);
    }
  }

  // ==========================================
  // PICK & UPLOAD TO MINIO
  // ==========================================
  Future<void> _pickAndUploadDocument(
    String docType,
    ImageSource source,
  ) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        preferredCameraDevice: docType == 'selfie'
            ? CameraDevice.front
            : CameraDevice.rear,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);

      setState(() {
        _localFiles[docType] = file;
        _uploadingState[docType] = true;
        _errorMessage = null;
      });

      final publicUrl = await ref
          .read(registrationProvider)
          .uploadDocument(file, docType);

      if (!mounted) return;

      setState(() {
        _uploadedUrls[docType] = publicUrl;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _localFiles[docType] = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _localFiles[docType] = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить фото: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingState[docType] = false);
      }
    }
  }

  // ==========================================
  // FULLSCREEN PREVIEW DIALOG
  // ==========================================
  void _showImagePreview(String title, File? localFile, String? networkUrl) {
    if (localFile == null && networkUrl == null) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title, style: const TextStyle(fontSize: 16)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: localFile != null
                    ? Image.file(localFile, fit: BoxFit.contain)
                    : Image.network(networkUrl!, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SUBMIT STEP 3 TO FASTIFY BACKEND
  // ==========================================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDob == null) {
      setState(() => _errorMessage = 'Пожалуйста, укажите дату рождения');
      return;
    }

    if (_uploadedUrls['id_front'] == null) {
      setState(
        () => _errorMessage = 'Загрузите фото главной страницы паспорта',
      );
      return;
    }

    if (_uploadedUrls['selfie'] == null) {
      setState(() => _errorMessage = 'Загрузите селфи с паспортом');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Format YYYY-MM-DD for backend `new Date(data.dateOfBirth)`
      final isoDob =
          '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}';

      final cleanPassport = _passportController.text.replaceAll(' ', '').trim();

      final payload = <String, dynamic>{
        'dateOfBirth': isoDob,
        'passportNumber': cleanPassport,
        'idDocumentFrontUrl': _uploadedUrls['id_front'],
        if (_uploadedUrls['id_back'] != null)
          'idDocumentBackUrl': _uploadedUrls['id_back'],
        'selfieWithIdUrl': _uploadedUrls['selfie'],
        if (_uploadedUrls['drivers_license'] != null)
          'driversLicenseUrl': _uploadedUrls['drivers_license'],
      };

      await ref.read(registrationProvider).submitStep3(payload);

      // Update local user state so onboardingStep is in sync
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        ref.read(currentUserProvider.notifier).state = {
          ...currentUser,
          'onboardingStep': 4,
        };
      }

      if (mounted) {
        context.go(AppRoutes.workerStep4);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Ошибка сохранения данных: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ==========================================
  // DOCUMENT CARD WIDGET
  // ==========================================
  Widget _buildDocumentCard({
    required String docType,
    required String title,
    required String subtitle,
    required IconData defaultIcon,
    required bool isRequired,
  }) {
    final bool isUploading = _uploadingState[docType] ?? false;
    final String? uploadedUrl = _uploadedUrls[docType];
    final File? localFile = _localFiles[docType];
    final bool isUploaded = uploadedUrl != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUploaded ? Colors.green.shade600 : Colors.grey.shade300,
          width: isUploaded ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isUploading ? null : () => _showImageSourceSheet(docType, title),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail / Spinner / Icon
              GestureDetector(
                onTap: isUploaded
                    ? () => _showImagePreview(title, localFile, uploadedUrl)
                    : null,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isUploaded
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isUploading
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : (localFile != null
                            ? Image.file(localFile, fit: BoxFit.cover)
                            : (isUploaded
                                  ? Image.network(
                                      uploadedUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 32,
                                      ),
                                    )
                                  : Icon(
                                      defaultIcon,
                                      color: Colors.blueGrey,
                                      size: 28,
                                    ))),
                ),
              ),
              const SizedBox(width: 14),

              // Title & Status Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isRequired)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isUploaded
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isUploaded ? 'Готово' : 'Обязательно',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isUploaded
                                    ? Colors.green.shade700
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isUploading
                          ? 'Сжатие и загрузка в облако...'
                          : (isUploaded
                                ? 'Нажмите, чтобы переснять или заменить'
                                : subtitle),
                      style: TextStyle(
                        fontSize: 13,
                        color: isUploaded
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Action Icon
              Icon(
                isUploaded ? Icons.edit_outlined : Icons.add_a_photo_outlined,
                color: isUploaded ? Colors.green.shade700 : Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool anyUploading = _uploadingState.values.any((v) => v);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Документы (Шаг 3/4)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          tooltip: 'Назад к шагу 2',
          onPressed: () => context.go(AppRoutes.workerStep2),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Паспортные данные',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Данные надежно защищены и используются только для модерации анкеты.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              // Date of Birth Field
              TextFormField(
                controller: _dobDisplayController,
                readOnly: true,
                onTap: _pickDateOfBirth,
                decoration: InputDecoration(
                  labelText: 'Дата рождения *',
                  hintText: 'ДД.ММ.ГГГГ',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Укажите дату рождения' : null,
              ),
              const SizedBox(height: 16),

              // Passport Number Field
              TextFormField(
                controller: _passportController,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9A-Za-zА-Яа-я\s-]'),
                  ),
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: InputDecoration(
                  labelText: 'Серия и номер паспорта *',
                  hintText: 'Например: 4510 123456',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Введите серию и номер паспорта';
                  }
                  if (v.replaceAll(' ', '').length < 6) {
                    return 'Слишком короткий номер документа';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 28),
              const Text(
                'Фотографии документов',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Сделайте четкие снимки при хорошем освещении без бликов и обрезанных краев.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              _buildDocumentCard(
                docType: 'id_front',
                title: 'Паспорт (разворот с фото)',
                subtitle: 'Главная страница документа',
                defaultIcon: Icons.credit_card_outlined,
                isRequired: true,
              ),
              _buildDocumentCard(
                docType: 'id_back',
                title: 'Паспорт (прописка / оборот)',
                subtitle: 'Страница с регистрацией (если есть)',
                defaultIcon: Icons.assignment_outlined,
                isRequired: false,
              ),
              _buildDocumentCard(
                docType: 'selfie',
                title: 'Селфи с паспортом',
                subtitle: 'Держите открытый паспорт рядом с лицом',
                defaultIcon: Icons.face_retouching_natural_outlined,
                isRequired: true,
              ),
              _buildDocumentCard(
                docType: 'drivers_license',
                title: 'Водительское удостоверение',
                subtitle: 'Для курьеров на авто и грузоперевозок',
                defaultIcon: Icons.directions_car_filled_outlined,
                isRequired: false,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || anyUploading) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          anyUploading
                              ? 'Дождитесь загрузки фото...'
                              : 'Продолжить (Шаг 4/4)',
                          style: const TextStyle(
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
