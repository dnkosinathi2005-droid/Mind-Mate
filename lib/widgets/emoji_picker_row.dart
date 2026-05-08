import 'package:flutter/material.dart';
import '../core/theme.dart';

class EmojiPickerRow extends StatelessWidget {
  final String selectedEmoji;
  final ValueChanged<String> onSelected;

  static const List<String> _emojis = [
    '📝', '😢','😔','😐','😊','🥳', 
  ];

  const EmojiPickerRow({
    super.key,
    required this.selectedEmoji,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _emojis.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final emoji = _emojis[index];
          final isSelected = emoji == selectedEmoji;
          return GestureDetector(
            onTap: () => onSelected(emoji),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.15)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: Text(
                emoji,
                style: TextStyle(
                  fontSize: isSelected ? 24 : 20,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
