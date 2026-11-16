import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../categories/providers/category_provider.dart';

class JobFormValues {
  String categoryId;
  List<String> subcategoryIds;
  String description;
  String address;
  String? budget;
  String timing;

  JobFormValues({
    this.categoryId = '',
    this.subcategoryIds = const [],
    this.description = '',
    this.address = '',
    this.budget,
    this.timing = 'today',
  });
}

class JobFormWidget extends ConsumerStatefulWidget {
  final String title;
  final String? initialCategory;
  final JobFormValues? initialValues;
  final List<String> initialPhotos;
  final bool isSubmitting;
  final Future<void> Function(
    JobFormValues data,
    List<String> existingPhotos,
    List<File> newPhotos,
  )
  onSubmit;

  const JobFormWidget({
    super.key,
    required this.title,
    this.initialCategory,
    this.initialValues,
    this.initialPhotos = const [],
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  ConsumerState<JobFormWidget> createState() => _JobFormWidgetState();
}

class _JobFormWidgetState extends ConsumerState<JobFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late JobFormValues _formData;
  late List<String> _existingPhotos;
  final List<File> _newPhotos = [];

  final List<Map<String, String>> _timingOptions = [
    {'id': 'asap', 'label': 'Срочно'},
    {'id': 'today', 'label': 'В течение дня'},
    {'id': 'week', 'label': 'До конца недели'},
    {'id': 'flexible', 'label': 'Сроки не горят'},
  ];

  @override
  void initState() {
    super.initState();
    // Copy the subcategoryIds so we don't mutate the original list reference
    _formData =
        widget.initialValues ??
        JobFormValues(categoryId: widget.initialCategory ?? '');
    _formData.subcategoryIds = List.from(_formData.subcategoryIds);
    _existingPhotos = List.from(widget.initialPhotos);
  }

  Future<void> _showImageSourceActionSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(
                  LucideIcons.camera,
                  color: Color(0xFF0F172A),
                ),
                title: const Text('Сделать фото'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  LucideIcons.image,
                  color: Color(0xFF0F172A),
                ),
                title: const Text('Выбрать из галереи'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _newPhotos.add(File(pickedFile.path));
        });
      }
    } else {
      final pickedFiles = await _picker.pickMultiImage(imageQuality: 70);
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newPhotos.addAll(pickedFiles.map((x) => File(x.path)));
        });
      }
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Strict Validation for Categories
      if (_formData.categoryId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: Категория не выбрана'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_formData.subcategoryIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Выберите хотя бы одну подкатегорию услуги'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      widget.onSubmit(_formData, _existingPhotos, _newPhotos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(publicCategoriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // =======================================================
              // CARD 1: CATEGORY & SUBCATEGORY SELECTION
              // =======================================================
              _buildCard(
                children: [
                  const _SectionTitle(
                    icon: LucideIcons.layers,
                    title: 'Услуги',
                  ),

                  categoriesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, st) => const Text(
                      'Ошибка загрузки категорий',
                      style: TextStyle(color: Colors.red),
                    ),
                    data: (categories) {
                      if (categories.isEmpty) {
                        return const Text(
                          'Категории не найдены.',
                          style: TextStyle(color: Colors.red),
                        );
                      }

                      // 1. SAFELY determine the dropdown value
                      final bool isCategoryValid = categories.any(
                        (c) => c.id == _formData.categoryId,
                      );
                      final String? dropdownValue = isCategoryValid
                          ? _formData.categoryId
                          : null;

                      // 2. Find the selected parent object (if any) to render its subcategories
                      final parentCategory = isCategoryValid
                          ? categories.firstWhere(
                              (c) => c.id == _formData.categoryId,
                            )
                          : null;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Основная категория',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // THE DROPDOWN (ONLY SHOWS PARENTS)
                          DropdownButtonFormField<String>(
                            value: dropdownValue,
                            hint: const Text('Выберите основную услугу'),
                            isExpanded: true,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat.id,
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                            validator: (val) => val == null || val.isEmpty
                                ? 'Выберите категорию'
                                : null,
                            onChanged: (newVal) {
                              if (newVal != null &&
                                  newVal != _formData.categoryId) {
                                setState(() {
                                  _formData.categoryId = newVal;
                                  _formData.subcategoryIds.clear(); // CRITICAL: Reset subs when parent changes
                                });
                              }
                            },
                          ),

                          // THE SUBCATEGORIES (ONLY VISIBLE IF PARENT IS SELECTED)
                          if (parentCategory != null) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Уточните услугу (можно выбрать несколько)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (parentCategory.subcategories.isEmpty)
                              const Text(
                                'Нет доступных подкатегорий',
                                style: TextStyle(color: Colors.grey),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: parentCategory.subcategories.map((
                                  subcat,
                                ) {
                                  final isSelected = _formData.subcategoryIds
                                      .contains(subcat.id);
                                  return FilterChip(
                                    label: Text(subcat.name),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _formData.subcategoryIds.add(
                                            subcat.id,
                                          );
                                        } else {
                                          _formData.subcategoryIds.remove(
                                            subcat.id,
                                          );
                                        }
                                      });
                                    },
                                    selectedColor: const Color(0xFF0F172A),
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  const _SectionTitle(
                    icon: LucideIcons.pencil,
                    title: 'Описание',
                  ),
                  TextFormField(
                    initialValue: _formData.description,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Опишите задачу подробнее...',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) => v == null || v.length < 10
                        ? 'Минимум 10 символов'
                        : null,
                    onSaved: (v) => _formData.description = v ?? '',
                  ),
                ],
              ),

              // =======================================================
              // CARD 2: PHOTOS
              // =======================================================
              _buildCard(
                children: [
                  const _SectionTitle(
                    icon: LucideIcons.camera,
                    title: 'Фотографии',
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ..._existingPhotos.asMap().entries.map(
                        (e) => _PhotoThumb(
                          imageUrl: e.value,
                          onRemove: () =>
                              setState(() => _existingPhotos.removeAt(e.key)),
                        ),
                      ),
                      ..._newPhotos.asMap().entries.map(
                        (e) => _PhotoThumb(
                          file: e.value,
                          onRemove: () =>
                              setState(() => _newPhotos.removeAt(e.key)),
                        ),
                      ),
                      GestureDetector(
                        onTap: _showImageSourceActionSheet,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.image_plus, color: Colors.grey),
                              SizedBox(height: 4),
                              Text(
                                'Добавить',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // =======================================================
              // CARD 3: LOCATION & TIMING
              // =======================================================
              _buildCard(
                children: [
                  const _SectionTitle(
                    icon: LucideIcons.map_pin,
                    title: 'Адрес',
                  ),
                  TextFormField(
                    initialValue: _formData.address,
                    decoration: InputDecoration(
                      hintText: 'Укажите адрес выполнения',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) => v == null || v.length < 5
                        ? 'Укажите полный адрес'
                        : null,
                    onSaved: (v) => _formData.address = v ?? '',
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    icon: LucideIcons.clock,
                    title: 'Срочность',
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _timingOptions.map((opt) {
                      final isSelected = _formData.timing == opt['id'];
                      return ChoiceChip(
                        label: Text(opt['label']!),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _formData.timing = opt['id']!);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),

              // =======================================================
              // CARD 4: BUDGET
              // =======================================================
              _buildCard(
                children: [
                  const _SectionTitle(
                    icon: LucideIcons.wallet,
                    title: 'Бюджет',
                  ),
                  TextFormField(
                    initialValue: _formData.budget,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          '₽',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      hintText: 'Договорная цена, если пусто',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSaved: (v) => _formData.budget = v,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: widget.isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: widget.isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Сохранить',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0F172A)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String? imageUrl;
  final File? file;
  final VoidCallback onRemove;

  const _PhotoThumb({this.imageUrl, this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 80,
            height: 80,
            child: imageUrl != null
                ? CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
                : Image.file(file!, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.x, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
