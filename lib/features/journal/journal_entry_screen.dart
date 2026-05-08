import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/journal_entry.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/emoji_picker_row.dart';

class JournalEntryScreen extends StatefulWidget {
  /// Pass an existing entry via go_router `extra` to edit it.
  final JournalEntry? existingEntry;

  const JournalEntryScreen({super.key, this.existingEntry});

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  final _contentCtrl = TextEditingController();
  final _contentFocus = FocusNode();
  String _selectedEmoji = '📝';
  bool _isSaving = false;
  bool get _isEditing => widget.existingEntry != null;

  int get _charCount => _contentCtrl.text.length;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _contentCtrl.text = widget.existingEntry!.content;
      _selectedEmoji = widget.existingEntry!.emoji;
    }
    _contentCtrl.addListener(() => setState(() {}));
    // Auto-focus keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something before saving.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      if (_isEditing) {
        final updated = widget.existingEntry!.copyWith(
          content: content,
          emoji: _selectedEmoji,
          syncedAt: null, // mark dirty for re-sync
        );
        await LocalDbService.instance.updateJournal(updated);
      } else {
        final entry = JournalEntry(
          userId: uid,
          content: content,
          emoji: _selectedEmoji,
          createdAt: DateTime.now(),
        );
        await LocalDbService.instance.insertJournal(entry);
      }
      // Attempt immediate sync if online
      SyncService.instance.syncNow();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Entry updated' : 'Entry saved',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = _isEditing ? widget.existingEntry!.createdAt : DateTime.now();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () => _confirmDiscard(context),
        ),
        title: Text(_isEditing ? 'Edit entry' : 'New entry'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Text(
                    'Save',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: AppColors.surfaceVariant,
              child: Text(
                _fullDate(now),
                style: AppTextStyles.caption,
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji label
                    Text('How are you feeling?', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 10),
                    EmojiPickerRow(
                      selectedEmoji: _selectedEmoji,
                      onSelected: (e) => setState(() => _selectedEmoji = e),
                    ),
                    const SizedBox(height: 24),

                    // Selected emoji display
                    Row(
                      children: [
                        Text(
                          _selectedEmoji,
                          style: const TextStyle(fontSize: 36),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Tap an emoji above to express your mood',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Journal text field
                    Text(
                      'Write your thoughts',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _contentCtrl,
                      focusNode: _contentFocus,
                      maxLength: AppConstants.maxJournalChars,
                      maxLines: null,
                      minLines: 8,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        hintText:
                            'What\'s on your mind today? There are no rules here — write freely...',
                        hintStyle: AppTextStyles.bodyMedium,
                        counterStyle: AppTextStyles.caption,
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Char counter
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$_charCount / ${AppConstants.maxJournalChars}',
                        style: AppTextStyles.caption.copyWith(
                          color: _charCount > AppConstants.maxJournalChars * 0.9
                              ? AppColors.warning
                              : AppColors.textHint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save button (bottom of scroll)
                    PrimaryButton(
                      label: _isEditing ? 'Update Entry' : 'Save Entry',
                      onPressed: _isSaving ? null : _save,
                      isLoading: _isSaving,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final hasChanges = _contentCtrl.text.isNotEmpty ||
        _selectedEmoji != '📝';
    if (!hasChanges) {
      context.pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard entry?'),
        content: const Text('Your changes will be lost if you go back.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && context.mounted) context.pop();
  }

  String _fullDate(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month]} ${dt.year}  •  ${_time(dt)}';
  }

  String _time(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}
