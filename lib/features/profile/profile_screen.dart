import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/loading_overlay.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  UserModel? _userModel;
  File? _newAvatarFile;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await AuthService.instance.fetchUserDoc(uid);
    if (mounted) {
      setState(() {
        _userModel = user;
        _nameCtrl.text = user?.displayName ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      final updated = await AuthService.instance.updateProfile(
        uid: uid,
        displayName: _nameCtrl.text,
        avatarFile: _newAvatarFile,
      );
      if (mounted) {
        setState(() {
          _userModel = updated;
          _newAvatarFile = null;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out'),
        content: const Text(
          'Are you sure you want to sign out of MindMate?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AuthService.instance.signOut();

    // go_router guard redirects to login; use go() so back is not possible
    if (mounted) context.go(AppConstants.routeLogin);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSaving,
      message: 'Saving changes...',
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text('Profile'),
          actions: [
            if (!_isLoading)
              TextButton(
                onPressed: () {
                  if (_isEditing) {
                    // Cancel — restore original values
                    setState(() {
                      _nameCtrl.text = _userModel?.displayName ?? '';
                      _newAvatarFile = null;
                      _isEditing = false;
                    });
                  } else {
                    setState(() => _isEditing = true);
                  }
                },
                child: Text(
                  _isEditing ? 'Cancel' : 'Edit',
                  style: TextStyle(
                    color: _isEditing ? AppColors.error : AppColors.primary,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      // Avatar
                      _isEditing
                          ? AvatarPicker(
                              imageFile: _newAvatarFile,
                              imageUrl: _userModel?.avatarUrl,
                              onImageSelected: (file) =>
                                  setState(() => _newAvatarFile = file),
                              radius: 56,
                            )
                          : CircleAvatar(
                              radius: 56,
                              backgroundColor: AppColors.surfaceVariant,
                              backgroundImage: _userModel?.avatarUrl != null
                                  ? NetworkImage(_userModel!.avatarUrl!)
                                  : null,
                              child: _userModel?.avatarUrl == null
                                  ? Text(
                                      (_userModel?.displayName.isNotEmpty ==
                                              true)
                                          ? _userModel!.displayName[0]
                                              .toUpperCase()
                                          : '?',
                                      style: AppTextStyles.displayLarge.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : null,
                            ),

                      if (!_isEditing) ...[
                        const SizedBox(height: 16),
                        Text(
                          _userModel?.displayName ?? '',
                          style: AppTextStyles.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userModel?.email ?? '',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Edit form
                      if (_isEditing) ...[
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameCtrl,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Display name',
                                  prefixIcon:
                                      Icon(Icons.person_outline, size: 20),
                                ),
                                validator: Validators.displayName,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                              ),
                              const SizedBox(height: 14),
                              // Email is read-only (managed by Firebase Auth)
                              TextFormField(
                                initialValue: _userModel?.email,
                                enabled: false,
                                decoration: const InputDecoration(
                                  labelText: 'Email address',
                                  prefixIcon:
                                      Icon(Icons.email_outlined, size: 20),
                                  helperText:
                                      'Email cannot be changed here',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        PrimaryButton(
                          label: 'Save Changes',
                          onPressed: _saveChanges,
                          isLoading: _isSaving,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Info tiles (always visible)
                      if (!_isEditing) ...[
                        _InfoTile(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: _userModel?.email ?? '',
                        ),
                        _InfoTile(
                          icon: Icons.calendar_today_outlined,
                          label: 'Member since',
                          value: _formatDate(_userModel?.createdAt),
                        ),
                        const SizedBox(height: 32),

                        // Danger zone
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account',
                                style: AppTextStyles.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.push('/sync-status'),
                                icon: const Icon(
                                    Icons.sync_outlined,
                                    size: 18),
                                label: const Text('Sync status'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 44),
                                  foregroundColor: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SecondaryButton(
                                label: 'Sign Out',
                                icon: Icons.logout,
                                onPressed: _logout,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day} ${_month(date.month)} ${date.year}';
  }

  String _month(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m];
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              )),
            ],
          ),
        ],
      ),
    );
  }
}
