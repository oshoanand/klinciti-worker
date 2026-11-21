import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/router/route_names.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/category_model.dart';
import '../providers/registration_provider.dart';

class Step2Screen extends ConsumerStatefulWidget {
  const Step2Screen({super.key});

  @override
  ConsumerState<Step2Screen> createState() => _Step2ScreenState();
}

class _Step2ScreenState extends ConsumerState<Step2Screen> {
  final _formKey = GlobalKey<FormState>();

  // Legal & Financial Fields
  LegalType _legalType = LegalType.selfEmployed;
  final _innController = TextEditingController();
  final _companyController = TextEditingController();

  // Professional Fields
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _experienceController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Vehicle Fields
  bool _hasVehicle = false;
  final _vehicleModelController = TextEditingController();
  final _vehicleNumberController = TextEditingController();

  bool _isSubmitting = false;

  // Stores both selected main category IDs and subcategory IDs
  final Set<String> _selectedCategoryIds = {};

  @override
  void initState() {
    super.initState();
    // Pre-fill from Riverpod state if returning from a future step
    final state = ref.read(registrationProvider);
    _legalType = state.legalType ?? LegalType.selfEmployed;
    if (state.inn != null) _innController.text = state.inn!;
    if (state.companyName != null) _companyController.text = state.companyName!;
    if (state.city != null) _cityController.text = state.city!;
    if (state.address != null) _addressController.text = state.address!;
    if (state.experience != null)
      _experienceController.text = state.experience!;
    if (state.description != null)
      _descriptionController.text = state.description!;
    _hasVehicle = state.hasVehicle ?? false;
    _selectedCategoryIds.addAll(state.selectedCategoryIds);
  }

  @override
  void dispose() {
    _innController.dispose();
    _companyController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _experienceController.dispose();
    _descriptionController.dispose();
    _vehicleModelController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  // ==========================================
  // HIERARCHICAL CATEGORY SELECTION LOGIC
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
  // SUBMIT HANDLER
  // ==========================================
  Future<void> _submit() async {
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

    // 1. Update the local Riverpod state so data is preserved for Step 3 & 4
    ref
        .read(registrationProvider.notifier)
        .updateStep2(
          legalType: _legalType,
          inn: _innController.text.trim(),
          companyName: _legalType == LegalType.selfEmployed
              ? null
              : _companyController.text.trim(),
          city: _cityController.text.trim(),
          address: _addressController.text.trim(),
          experience: _experienceController.text.trim(),
          description: _descriptionController.text.trim(),
          hasVehicle: _hasVehicle,
        );

    ref
        .read(registrationProvider.notifier)
        .updateCategories(_selectedCategoryIds.toList());

    setState(() => _isSubmitting = true);

    try {
      // 2. Submit Step 2 to backend
      await ref.read(registrationProvider.notifier).submitStep2ToServer();

      // 3. Update local auth user state so if app reloads, it opens at Step 3
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        ref.read(currentUserProvider.notifier).state = {
          ...currentUser,
          'onboardingStep': 3,
        };
      }

      if (mounted) {
        context.go(AppRoutes.workerStep3);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ==========================================
  // CATEGORY TREE BUILDER
  // ==========================================
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

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesTreeProvider);
    final isOOO = _legalType == LegalType.ooo;
    final innLength = isOOO ? 10 : 12;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Юридический профиль (Шаг 2/4)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Color(0xFF0F172A),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ==========================================
            // LEGAL STATUS SECTION
            // ==========================================
            const Text(
              'Форма занятости',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Выберите ваш налоговый статус согласно законодательству РФ. Это потребуется для B2B выплат.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<LegalType>(
              value: _legalType,
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
                if (val != null) {
                  setState(() {
                    _legalType = val;
                    _innController.clear(); // Clear INN on type change because length validation changes
                  });
                }
              },
            ),
            const SizedBox(height: 16),

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
                if (val == null || val.isEmpty) return 'Введите ИНН';
                if (val.length != innLength)
                  return 'ИНН должен содержать $innLength цифр';
                return null;
              },
            ),
            const SizedBox(height: 16),

            if (_legalType != LegalType.selfEmployed) ...[
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

            const SizedBox(height: 32),

            // ==========================================
            // PROFESSIONAL DETAILS SECTION
            // ==========================================
            const Text(
              'Основная информация',
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
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Укажите город' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration(
                label: 'Адрес проживания / Офиса *',
                hint: 'Улица, дом',
                icon: LucideIcons.map_pin,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Укажите адрес' : null,
            ),
            const SizedBox(height: 16),
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
                if (v == null || v.trim().isEmpty) return 'Укажите опыт работы';
                final parsed = int.tryParse(v.trim());
                if (parsed == null || parsed < 0) {
                  return 'Введите корректное число';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              minLines: 2,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration(
                label: 'О себе и своем опыте (обязательно)',
                hint: 'Расскажите о своих навыках, инструментах и выполненных работах...',
                icon: LucideIcons.clipboard_list,
              ),
              validator: (v) => v == null || v.trim().length < 10
                  ? 'Напишите подробнее (минимум 10 символов)'
                  : null,
            ),
            const SizedBox(height: 12),

            // Vehicle Switch & Conditional Inputs
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  hint: 'Например: Lada Largus / ГАЗель Next',
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
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
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
              'Отметьте категории и подкатегории, по которым вы готовы принимать заказы',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            categoriesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
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
                      onPressed: () => ref.refresh(categoriesTreeProvider),
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
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Продолжить',
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
    );
  }
}
