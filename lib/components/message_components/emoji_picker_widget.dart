import 'package:flutter/material.dart';

class EmojiPickerWidget extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onBackspacePressed;

  const EmojiPickerWidget({
    super.key,
    required this.controller,
    required this.onBackspacePressed,
  });

  // Simple list of common emojis
  static const List<String> commonEmojis = [
    '😀',
    '😂',
    '🥰',
    '😊',
    '😍',
    '🤩',
    '😎',
    '🥳',
    '😜',
    '🤑',
    '🤗',
    '🙂',
    '🤔',
    '😐',
    '😑',
    '🙄',
    '😏',
    '😒',
    '😌',
    '😔',
    '😴',
    '🥺',
    '😭',
    '😡',
    '🤯',
    '😱',
    '👍',
    '👎',
    '❤️',
    '🔥',
    '🎉',
    '✨',
    '🌟',
    '💯',
    '👏',
    '🙌',
    '🤝',
    '💪',
    '👀',
    '💀',
    '👻',
    '🤖',
    '💩',
    '🙏',
    '✌️',
    '🤞',
    '🤟',
    '🤘',
    '👌',
    '🤙',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      color: const Color(0xFF0C1D2C),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1F2C3C),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Emoji',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(Icons.backspace_outlined, color: Colors.white, size: 24),
              ],
            ),
          ),
          // Emoji grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: commonEmojis.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    final newText = controller.text + commonEmojis[index];
                    controller.text = newText;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: newText.length),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        commonEmojis[index],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
