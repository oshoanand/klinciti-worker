import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../providers/payment_provider.dart';

/// Opens the B2B IP / OOO invoice modal bottom sheet
Future<B2BInvoiceResult?> showB2BInvoiceBottomSheet(
  BuildContext context, {
  required String jobId,
  required double budgetRub,
}) {
  return showModalBottomSheet<B2BInvoiceResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _B2BInvoiceBottomSheet(jobId: jobId, budgetRub: budgetRub),
  );
}

class _B2BInvoiceBottomSheet extends ConsumerStatefulWidget {
  final String jobId;
  final double budgetRub;

  const _B2BInvoiceBottomSheet({required this.jobId, required this.budgetRub});

  @override
  ConsumerState<_B2BInvoiceBottomSheet> createState() =>
      _B2BInvoiceBottomSheetState();
}

class _B2BInvoiceBottomSheetState
    extends ConsumerState<_B2BInvoiceBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _innCtrl = TextEditingController();
  final _kppCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String _legalType = 'OOO'; // 'OOO' | 'IP'
  B2BInvoiceResult? _createdInvoice;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _innCtrl.dispose();
    _kppCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      final result = await ref
          .read(paymentMutationProvider.notifier)
          .createB2BInvoice(
            jobId: widget.jobId,
            payerLegalType: _legalType,
            payerName: _nameCtrl.text,
            payerInn: _innCtrl.text,
            payerKpp: _legalType == 'OOO' ? _kppCtrl.text : null,
            payerEmail: _emailCtrl.text,
          );

      if (!mounted) return;
      setState(() => _createdInvoice = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка выставления счёта: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openInvoicePdf(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  InputDecoration _decoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(paymentMutationProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        bottomInset + MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: _createdInvoice != null
            ? _buildSuccessView(_createdInvoice!)
            : _buildFormView(isSubmitting),
      ),
    );
  }

  Widget _buildFormView(bool isSubmitting) {
    final isOOO = _legalType == 'OOO';

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Счёт для ИП / ООО',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.budgetRub.toStringAsFixed(0)} ₽',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Сформируем официальный счёт через Т-Банк Бизнес с выделением агентского вознаграждения.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Legal Entity Toggle (OOO vs IP)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildSegment('OOO', 'ООО (Юр. лицо)'),
                _buildSegment('IP', 'ИП'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _nameCtrl,
            enabled: !isSubmitting,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration(
              isOOO
                  ? 'Наименование организации *'
                  : 'ФИО индивидуального предпринимателя *',
              isOOO ? 'ООО «Ромашка»' : 'ИП Иванов Иван Иванович',
            ),
            validator: (v) {
              if (v == null || v.trim().length < 3) {
                return 'Укажите полное наименование';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _innCtrl,
            enabled: !isSubmitting,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(isOOO ? 10 : 12),
            ],
            decoration: _decoration(
              isOOO ? 'ИНН (10 цифр) *' : 'ИНН (12 цифр) *',
              isOOO ? '7707083893' : '770708389301',
            ),
            validator: (v) {
              final digits = (v ?? '').trim();
              final requiredLen = isOOO ? 10 : 12;
              if (digits.length != requiredLen) {
                return 'ИНН для ${isOOO ? 'ООО' : 'ИП'} должен содержать $requiredLen цифр';
              }
              return null;
            },
          ),

          if (isOOO) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _kppCtrl,
              enabled: !isSubmitting,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: _decoration('КПП (9 цифр) *', '770701001'),
              validator: (v) {
                if (!isOOO) return null;
                if ((v ?? '').trim().length != 9) {
                  return 'КПП должен содержать 9 цифр';
                }
                return null;
              },
            ),
          ],

          const SizedBox(height: 12),

          TextFormField(
            controller: _emailCtrl,
            enabled: !isSubmitting,
            keyboardType: TextInputType.emailAddress,
            decoration: _decoration(
              'Email для отправки счёта (необязательно)',
              'accounting@company.ru',
            ),
            validator: (v) {
              final email = (v ?? '').trim();
              if (email.isEmpty) return null;
              if (!email.contains('@') || !email.contains('.')) {
                return 'Введите корректный email';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isSubmitting
                  ? const SizedBox.shrink()
                  : const Icon(LucideIcons.file_text, size: 18),
              label: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Выставить счёт',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(String value, String label) {
    final selected = _legalType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_legalType == value) return;
          setState(() {
            _legalType = value;
            _innCtrl.clear();
            _kppCtrl.clear();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0F172A) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(B2BInvoiceResult invoice) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.circle_check,
            color: Colors.green,
            size: 38,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Счёт № ${invoice.invoiceNumber} сформирован',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Сумма к оплате: ${invoice.totalRub.toStringAsFixed(0)} ₽ • Оплатить до ${invoice.dueDate}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),
        if (invoice.pdfUrl.isNotEmpty)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _openInvoicePdf(invoice.pdfUrl),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(LucideIcons.download, size: 18),
              label: const Text(
                'Открыть счёт (PDF)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: TextButton(
            onPressed: () => Navigator.pop(context, invoice),
            child: const Text(
              'Готово',
              style: TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
