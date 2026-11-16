import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  final void Function(String text) onSend;
  final VoidCallback onAttachmentPressed;
  final VoidCallback onTyping;
  final bool isUploading;

  const ChatInput({
    super.key,
    required this.onSend,
    required this.onAttachmentPressed,
    required this.onTyping,
    this.isUploading = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final notEmpty = _controller.text.trim().isNotEmpty;
    if (notEmpty != _hasText) {
      setState(() => _hasText = notEmpty);
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            widget.isUploading
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.attach_file_rounded),
                    color: Colors.grey.shade600,
                    tooltip: 'Прикрепить фото',
                    onPressed: widget.onAttachmentPressed,
                  ),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onChanged: (val) {
                  // Only emit typing socket event when there is actual text
                  if (val.trim().isNotEmpty) {
                    widget.onTyping();
                  }
                },
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: 'Сообщение...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: _hasText ? primaryColor : Colors.grey.shade300,
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: _hasText ? Colors.white : Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: _hasText ? _handleSend : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
