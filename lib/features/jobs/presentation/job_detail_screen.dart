import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/widgets/global_error_widget.dart';
import '../../chat/data/models/chat_session_model.dart';
import '../../chat/providers/chat_sessions_provider.dart';
import '../data/job_model.dart';
import '../providers/job_provider.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isOpeningChat = false;

  // ==========================================================
  // INITIATE OR RESUME CHAT WITH THE CUSTOMER
  // ==========================================================
  Future<void> _openCustomerChat(JobModel job) async {
    final customerId = job.customerId;
    if (customerId == null || customerId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Данные клиента недоступны для начала диалога'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);

    try {
      // 1. Resolve existing session from memory or call POST /chats/sessions/initiate
      final ChatSessionModel session = await ref
          .read(chatSessionsProvider.notifier)
          .resolveOrInitiateSession(
            partnerId: customerId,
            fallbackName: job.customerName ?? 'Клиент',
            fallbackAvatar: job.customerImage,
          );

      if (!mounted) return;

      // 2. Build route URI with partner & job metadata and pass ChatSessionModel in `extra`
      final targetUri = Uri(
        path: '${AppRoutes.chatDetail}/${session.id}',
        queryParameters: {
          'partnerId': session.partnerId.isNotEmpty
              ? session.partnerId
              : customerId,
          'partnerName': session.partnerName ?? job.customerName ?? 'Клиент',
          if (session.partnerAvatar != null &&
              session.partnerAvatar!.isNotEmpty)
            'partnerAvatar': session.partnerAvatar!,
          'jobId': job.id,
          'jobTitle': job.displayTitle,
        },
      );

      context.push(targetUri.toString(), extra: session);
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
            content: Text('Не удалось открыть чат с клиентом: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
    }
  }

  // ==========================================================
  // CALL CUSTOMER PHONE NUMBER
  // ==========================================================
  Future<void> _callCustomer(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть телефонный набор'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // FULLSCREEN PHOTO PREVIEW
  // ==========================================================
  void _openPhotoViewer(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    LucideIcons.image_off,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 1. ACCEPT JOB MODAL (PATCH /jobs/for-worker/:jobId/accept)
  // ==========================================================
  Future<void> _showAcceptModal(JobModel job) async {
    final budgetCtrl = TextEditingController(
      text: job.budget.toStringAsFixed(0),
    );
    final commentCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Принять заказ в работу',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: budgetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Согласованная стоимость (₽) *',
                    prefixIcon: Icon(LucideIcons.wallet),
                  ),
                  validator: (v) {
                    final parsed = double.tryParse(v?.trim() ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Укажите корректную сумму';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: commentCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий к заказу *',
                    hintText: 'Например: Выезжаю, буду через 40 минут',
                    prefixIcon: Icon(LucideIcons.message_square),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Добавьте краткий комментарий'
                      : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(sheetCtx, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Подтвердить и начать работу'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      final agreedBudget =
          double.tryParse(budgetCtrl.text.trim()) ?? job.budget;
      final success = await ref
          .read(jobActionControllerProvider.notifier)
          .acceptJob(
            jobId: widget.jobId,
            agreedBudget: agreedBudget,
            commentary: commentCtrl.text.trim(),
          );
      _handleActionResult(success, 'Заказ принят в работу');
    }
  }

  // ==========================================================
  // 2. COMPLETE JOB MODAL (PATCH /jobs/for-worker/:jobId/complete)
  // ==========================================================
  Future<void> _showCompleteModal() async {
    final commentCtrl = TextEditingController();
    final List<File> selectedPhotos = [];

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> pickPhoto(ImageSource source) async {
              final xFile = await _picker.pickImage(source: source);
              if (xFile != null) {
                setSheetState(() => selectedPhotos.add(File(xFile.path)));
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Завершение заказа',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Прикрепите фото выполненной работы и комментарий.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ...selectedPhotos.asMap().entries.map((entry) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                entry.value,
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: GestureDetector(
                                onTap: () => setSheetState(
                                  () => selectedPhotos.removeAt(entry.key),
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: () => pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Камера'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => pickPhoto(ImageSource.gallery),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('Галерея'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий (необязательно)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: selectedPhotos.isEmpty
                        ? null
                        : () => Navigator.pop(sheetCtx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Отправить фотоотчет и завершить'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      final success = await ref
          .read(jobActionControllerProvider.notifier)
          .completeJob(
            jobId: widget.jobId,
            localPhotos: selectedPhotos,
            commentary: commentCtrl.text.trim(),
          );
      _handleActionResult(success, 'Заказ успешно завершен');
    }
  }

  // ==========================================================
  // 3. REJECT & DISPUTE HANDLERS
  // ==========================================================
  Future<void> _confirmReject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отказаться от заказа?'),
        content: const Text(
          'Заказ будет снят с вашего профиля и передан другому исполнителю.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Отказаться',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await ref
          .read(jobActionControllerProvider.notifier)
          .rejectJob(widget.jobId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы отказались от заказа')),
        );
        context.pop();
      } else {
        _handleActionResult(false, '');
      }
    }
  }

  Future<void> _confirmDispute() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Открыть спор?'),
        content: const Text(
          'Заказ перейдет в статус спора, и администратор свяжется с вами и клиентом для решения вопроса.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Открыть спор',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await ref
          .read(jobActionControllerProvider.notifier)
          .disputeJob(widget.jobId);
      _handleActionResult(success, 'Спор открыт. Ожидайте администратора.');
    }
  }

  void _handleActionResult(bool success, String successMsg) {
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
      );
    } else {
      final err = ref.read(jobActionControllerProvider).error;
      final msg = err != null
          ? ApiException.fromDioException(err).message
          : 'Ошибка выполнения действия';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  // ==========================================================
  // UI BUILD
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final actionState = ref.watch(jobActionControllerProvider);
    final isSubmitting = actionState.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Детали задания',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => GlobalErrorWidget(
          message: ApiException.fromDioException(err).message,
          onRetry: () => ref.refresh(jobDetailProvider(widget.jobId)),
        ),
        data: (job) {
          final hasCustomerId =
              job.customerId != null && job.customerId!.trim().isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ==========================================
              // 1. MAIN ORDER SUMMARY CARD
              // ==========================================
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${job.status} • Оплата: ${job.paymentStatus}',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          '${job.budget.toStringAsFixed(0)} ₽',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      job.displayTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Описание заказа:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      job.description.isNotEmpty
                          ? job.description
                          : 'Описание отсутствует',
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.map_pin,
                          size: 18,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${job.city.isNotEmpty ? '${job.city}, ' : ''}${job.pickupAddress}',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    if (job.timing != null && job.timing!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.clock,
                            size: 18,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Время: ${job.timing}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (job.workerComment != null &&
                        job.workerComment!.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              LucideIcons.message_square,
                              size: 16,
                              color: Colors.blueGrey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ваш комментарий: ${job.workerComment}',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ==========================================
              // 2. CUSTOMER PHOTOS
              // ==========================================
              if (job.photos.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Фотографии от клиента',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: job.photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, idx) {
                      final url = job.photos[idx];
                      return GestureDetector(
                        onTap: () => _openPhotoViewer(url, 'Фото заказа'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // ==========================================
              // 3. COMPLETION REPORT PHOTOS (IF COMPLETED)
              // ==========================================
              if (job.completionPhotos.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Фотоотчет о выполнении',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: job.completionPhotos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, idx) {
                      final url = job.completionPhotos[idx];
                      return GestureDetector(
                        onTap: () => _openPhotoViewer(url, 'Фотоотчет'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ==========================================
              // 4. CUSTOMER CONTACT & CHAT INITIATION CARD
              // ==========================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFFF1F5F9),
                          backgroundImage:
                              job.customerImage != null &&
                                  job.customerImage!.isNotEmpty
                              ? NetworkImage(job.customerImage!)
                              : null,
                          child:
                              job.customerImage == null ||
                                  job.customerImage!.isEmpty
                              ? const Icon(
                                  LucideIcons.user,
                                  color: Color(0xFF0F172A),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Заказчик',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                job.customerName ?? 'Клиент',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (job.customerMobile != null &&
                                  job.customerMobile!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  job.customerMobile!,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (job.customerMobile != null &&
                            job.customerMobile!.isNotEmpty &&
                            (job.status == 'ACCEPTED' ||
                                job.status == 'ONGOING'))
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                LucideIcons.phone,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                              tooltip: 'Позвонить клиенту',
                              onPressed: () =>
                                  _callCustomer(job.customerMobile),
                            ),
                          ),
                        if (hasCustomerId)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: _isOpeningChat
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      LucideIcons.message_circle,
                                      color: Colors.blue.shade700,
                                      size: 20,
                                    ),
                              tooltip: 'Написать клиенту',
                              onPressed: _isOpeningChat
                                  ? null
                                  : () => _openCustomerChat(job),
                            ),
                          ),
                      ],
                    ),

                    // Full-width "Write to Customer" button for quick access
                    if (hasCustomerId) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _isOpeningChat
                            ? null
                            : () => _openCustomerChat(job),
                        icon: _isOpeningChat
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(LucideIcons.message_square, size: 18),
                        label: Text(
                          _isOpeningChat
                              ? 'Открытие чата...'
                              : 'Написать клиенту в чат',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ==========================================
              // 5. STATUS-AWARE JOB ACTION BUTTONS
              // ==========================================
              if (isSubmitting)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (job.status == 'ACCEPTED')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _confirmReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Отказаться'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showAcceptModal(job),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Принять в работу'),
                        ),
                      ),
                    ],
                  ),
                if (job.status == 'ONGOING') ...[
                  ElevatedButton.icon(
                    onPressed: _showCompleteModal,
                    icon: const Icon(LucideIcons.circle_check),
                    label: const Text('Завершить задание (Фотоотчет)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _confirmDispute,
                    icon: const Icon(LucideIcons.shield_alert, size: 18),
                    label: const Text('Открыть спор'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
                if (job.status == 'COMPLETED' && job.paymentStatus != 'PAID')
                  OutlinedButton.icon(
                    onPressed: _confirmDispute,
                    icon: const Icon(LucideIcons.shield_alert, size: 18),
                    label: const Text('Открыть спор по оплате'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
