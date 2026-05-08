import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

/// A persistent bottom bar displaying SA emergency mental health numbers.
/// Always visible in the chatbot screen so users can call at any moment.
class EmergencyBar extends StatefulWidget {
  const EmergencyBar({super.key});

  @override
  State<EmergencyBar> createState() => _EmergencyBarState();
}

class _EmergencyBarState extends State<EmergencyBar> {
  bool _expanded = false;

  static const List<_Contact> _contacts = [
    _Contact(
      name: AppConstants.emergencyNameSadag,
      number: AppConstants.emergencyNumSadag,
      dialNumber: '0800212223',
      color: Color(0xFFE53935),
    ),
    _Contact(
      name: AppConstants.emergencyNameLifeline,
      number: AppConstants.emergencyNumLifeline,
      dialNumber: '0861322322',
      color: Color(0xFF7C5CBF),
    ),
    _Contact(
      name: AppConstants.emergencyNameChildline,
      number: AppConstants.emergencyNumChildline,
      dialNumber: '116',
      color: Color(0xFF4ECDC4),
    ),
    _Contact(
      name: AppConstants.emergencyNameSuicide,
      number: AppConstants.emergencyNumSuicide,
      dialNumber: '0800456789',
      color: Color(0xFFFF7043),
    ),
  ];

  Future<void> _call(String dialNumber) async {
    final uri = Uri(scheme: 'tel', path: dialNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the dialler on this device.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _copyNumber(String number) {
    Clipboard.setData(ClipboardData(text: number));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$number copied to clipboard'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ──────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Emergency support numbers',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _expanded ? 'Hide' : 'Show',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded contact list ────────────
          if (_expanded) ...[
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _contacts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return _ContactTile(
                  contact: contact,
                  onCall: () => _call(contact.dialNumber),
                  onCopy: () => _copyNumber(contact.number),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'If you are in immediate danger, call 10111 (SAPS) or 10177 (ambulance).',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final _Contact contact;
  final VoidCallback onCall;
  final VoidCallback onCopy;

  const _ContactTile({
    required this.contact,
    required this.onCall,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: contact.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: contact.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: contact.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_outlined,
              color: contact.color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                Text(
                  contact.number,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: contact.color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Copy button
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Copy number',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 4),
          // Call button
          ElevatedButton.icon(
            onPressed: onCall,
            icon: const Icon(Icons.phone, size: 14),
            label: const Text('Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: contact.color,
              foregroundColor: Colors.white,
              minimumSize: const Size(72, 34),
              textStyle: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Contact {
  final String name;
  final String number;
  final String dialNumber;
  final Color color;

  const _Contact({
    required this.name,
    required this.number,
    required this.dialNumber,
    required this.color,
  });
}
