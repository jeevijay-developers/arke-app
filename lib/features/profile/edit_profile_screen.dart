import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';
import '../../core/supabase/supabase_client.dart';
import '../auth/data/auth_repository.dart';
import '../auth/data/models/user_profile.dart';
import '../auth/data/repositories/user_repository.dart';
import '../enrollments/data/repositories/enrollments_repository.dart';
import '../profile/data/profile_providers.dart';

abstract class DS {
  static const primary = Color(0xFFF97315);
  static const primaryLight = Color(0xFFFFF0E6);
  static const primaryDark = Color(0xFFE05A00);

  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);
  static const border = Color(0xFFE5E7EB);

  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);
  static const successSurface = Color(0xFFECFDF5);

  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s48 = 48;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// EDIT PROFILE SCREEN
// ─────────────────────────────────────────────
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  // Text controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _countryCtrl;

  // Dropdown values
  String? _classLevel;
  String? _targetExam;
  String? _schoolId;
  String? _goal;

  // Avatar
  String? _avatarUrl;
  bool _uploadingAvatar = false;

  // Save state
  bool _saving = false;
  bool _saved = false;

  // True once the profile has been loaded into the form fields.
  // Prevents the async listener from overwriting edits the user is actively making.
  bool _profileLoaded = false;

  // Animation
  late AnimationController _ctrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authRepositoryProvider).currentUser();
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _stateCtrl = TextEditingController();
    _countryCtrl = TextEditingController();
    _goal = ref.read(prefsProvider).goal;
    _avatarUrl = user?.avatarUrl;

    // If profile is already in cache, populate immediately
    final cached = ref.read(userProfileProvider).valueOrNull;
    if (cached != null) _populateFromProfile(cached);

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _contentFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.25, 0.85, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  String get _initials {
    final t = _nameCtrl.text.trim();
    if (t.isEmpty) return 'U';
    final parts = t.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // Populate fields from profile — only on first load to avoid overwriting edits
  void _populateFromProfile(UserProfile profile) {
    if (_profileLoaded) return;
    _profileLoaded = true;

    _nameCtrl.text = profile.fullName ?? _nameCtrl.text;
    _phoneCtrl.text = profile.phone ?? '';
    _cityCtrl.text = profile.city ?? '';
    _stateCtrl.text = profile.state ?? '';
    _countryCtrl.text = profile.country ?? '';
    _classLevel = profile.classLevel;
    _targetExam = profile.targetExam;
    _schoolId = profile.schoolId;
    _goal = profile.goal ?? _goal;
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      _avatarUrl = profile.avatarUrl;
    }
    setState(() {});
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saved = false;
    });
    try {
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile != null) {
        final updated = profile.copyWith(
          fullName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          state: _stateCtrl.text.trim(),
          country: _countryCtrl.text.trim(),
          goal: _goal,
          classLevel: _classLevel,
          targetExam: _targetExam,
          schoolId: _schoolId,
        );
        await UserRepository().updateUserProfile(updated);
        // Sync name + avatar into Supabase auth metadata so user?.name is current
        final sb = Supabase.instance.client;
        await sb.auth.updateUser(UserAttributes(data: {
          'full_name': updated.fullName ?? '',
          if (updated.avatarUrl != null) 'avatar_url': updated.avatarUrl,
        }));
        // Sync exam + class to prefs so courses list re-filters immediately
        final prefs = ref.read(prefsProvider);
        if (updated.targetExam != null) await prefs.setUserExam(updated.targetExam!);
        if (updated.classLevel != null) await prefs.setUserClass(updated.classLevel!);
        // Auto-enroll in any new free courses matching the updated exam + class
        if (updated.targetExam != null && updated.targetExam!.isNotEmpty) {
          await EnrollmentsRepository().autoEnrollFreeCourses(
            exam: updated.targetExam!,
            userClass: updated.classLevel ?? '',
          );
        }
        // Update fields immediately from the saved values — no waiting for DB round-trip.
        // _profileLoaded stays true so the provider refresh doesn't overwrite the fields.
        setState(() {
          _nameCtrl.text = updated.fullName ?? _nameCtrl.text;
          _phoneCtrl.text = updated.phone ?? _phoneCtrl.text;
          _cityCtrl.text = updated.city ?? _cityCtrl.text;
          _stateCtrl.text = updated.state ?? _stateCtrl.text;
          _classLevel = updated.classLevel;
          _targetExam = updated.targetExam;
          _schoolId = updated.schoolId;
          if (updated.avatarUrl != null) _avatarUrl = updated.avatarUrl;
        });
        _profileLoaded = true;
        ref.invalidate(userProfileProvider);
        // Invalidate course providers so the list re-fetches with the new filter
        ref.invalidate(profileSetupInfoProvider);
      }
      if (_goal != null) ref.read(prefsProvider).setGoal(_goal!);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _saved = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final sb = supabaseOrNull;
    final user = ref.read(authRepositoryProvider).currentUser();
    if (sb == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to upload a photo.')),
      );
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (file == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await sb.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );

      final url = sb.storage.from('avatars').getPublicUrl(path);
      await sb.auth.updateUser(UserAttributes(data: {'avatar_url': url}));
      await sb.from('profiles').update({'avatar_url': url}).eq('user_id', user.id);

      if (!mounted) return;
      setState(() => _avatarUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Populate once when profile loads
    ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (prev, next) {
      final profile = next.valueOrNull;
      if (profile != null) _populateFromProfile(profile);
    });

    return Scaffold(
      backgroundColor: DS.primary,
      body: Stack(
        children: [
          const _HeaderDecorations(),

          Column(
            children: [
              FadeTransition(
                opacity: _headerFade,
                child: SafeArea(
                  bottom: false,
                  child: _ProfileHeader(
                    initials: _initials,
                    nameCtrl: _nameCtrl,
                    avatarUrl: _avatarUrl,
                    uploading: _uploadingAvatar,
                    onPickAvatar: _pickAndUploadAvatar,
                  ),
                ),
              ),

              Expanded(
                child: SlideTransition(
                  position: _contentSlide,
                  child: FadeTransition(
                    opacity: _contentFade,
                    child: _ContentCard(
                      nameCtrl: _nameCtrl,
                      phoneCtrl: _phoneCtrl,
                      cityCtrl: _cityCtrl,
                      stateCtrl: _stateCtrl,
                      classLevel: _classLevel,
                      targetExam: _targetExam,
                      schoolId: _schoolId,
                      saving: _saving,
                      saved: _saved,
                      onNameChanged: (_) => setState(() {}),
                      onClassLevelChanged: (v) => setState(() => _classLevel = v),
                      onTargetExamChanged: (v) => setState(() => _targetExam = v),
                      onSchoolChanged: (v) => setState(() => _schoolId = v),
                      onSave: _save,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: DS.s8, top: DS.s4),
              child: Material(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(DS.s8),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HEADER DECORATIONS
// ─────────────────────────────────────────────
class _HeaderDecorations extends StatelessWidget {
  const _HeaderDecorations();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -40,
          child: _Circle(size: 200, opacity: 0.10),
        ),
        Positioned(
          top: 30,
          left: -50,
          child: _Circle(size: 130, opacity: 0.07),
        ),
        Positioned(top: 15, right: 55, child: _Circle(size: 50, opacity: 0.12)),
        Positioned(
          top: 80,
          right: -18,
          child: Transform.rotate(
            angle: math.pi / 6,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  final double size, opacity;
  const _Circle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

// ─────────────────────────────────────────────
// PROFILE HEADER
// ─────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String initials;
  final TextEditingController nameCtrl;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onPickAvatar;

  const _ProfileHeader({
    required this.initials,
    required this.nameCtrl,
    required this.avatarUrl,
    required this.uploading,
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DS.s24, DS.s48, DS.s24, DS.s28),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2.5,
                  ),
                ),
                child: _AvatarImage(
                  initials: initials,
                  avatarUrl: avatarUrl,
                  uploading: uploading,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onPickAvatar,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 15,
                      color: DS.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DS.s12),
          Text(
            nameCtrl.text.isEmpty ? 'Your Name' : nameCtrl.text,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: DS.s4),
          Text(
            'Tap fields below to edit your profile',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  final String initials;
  final String? avatarUrl;
  final bool uploading;
  const _AvatarImage({
    required this.initials,
    required this.avatarUrl,
    required this.uploading,
  });

  @override
  Widget build(BuildContext context) {
    if (uploading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl!,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _InitialsText(initials: initials),
        ),
      );
    }
    return _InitialsText(initials: initials);
  }
}

class _InitialsText extends StatelessWidget {
  final String initials;
  const _InitialsText({required this.initials});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      initials,
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.5,
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// CONTENT CARD
// ─────────────────────────────────────────────
class _ContentCard extends ConsumerWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController stateCtrl;
  final String? classLevel;
  final String? targetExam;
  final String? schoolId;
  final bool saving;
  final bool saved;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String?> onClassLevelChanged;
  final ValueChanged<String?> onTargetExamChanged;
  final ValueChanged<String?> onSchoolChanged;
  final VoidCallback onSave;

  const _ContentCard({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.cityCtrl,
    required this.stateCtrl,
    required this.classLevel,
    required this.targetExam,
    required this.schoolId,
    required this.saving,
    required this.saved,
    required this.onNameChanged,
    required this.onClassLevelChanged,
    required this.onTargetExamChanged,
    required this.onSchoolChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolsAsync = ref.watch(schoolsProvider);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: DS.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(DS.radiusXl),
          topRight: Radius.circular(DS.radiusXl),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(DS.s24, DS.s28, DS.s24, DS.s32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card header
            Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: DS.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: DS.s12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: DS.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Keep your details up to date',
                      style: TextStyle(fontSize: 12.5, color: DS.textSecondary),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: DS.s24),

            // ── Section: Personal Info ──
            _SectionLabel(
              label: 'Personal Info',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: DS.s12),

            _AppField(
              controller: nameCtrl,
              label: 'Full Name',
              hint: 'Enter your full name',
              icon: Icons.person_outline_rounded,
              onChanged: onNameChanged,
            ),
            const SizedBox(height: DS.s12),

            _AppField(
              controller: phoneCtrl,
              label: 'Phone Number',
              hint: 'e.g. 9876543210',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: DS.s12),

            // Target Exam dropdown — values must match profile_setup_screen _kExams
            _DropdownField<String>(
              value: targetExam,
              hint: 'Select your target exam',
              label: 'Target Exam',
              icon: Icons.emoji_events_outlined,
              items: const ['JEE', 'NEET', 'Foundation'],
              labels: const ['JEE', 'NEET', 'Foundation'],
              onChanged: onTargetExamChanged,
            ),
            const SizedBox(height: DS.s12),

            // Class Level dropdown — values must match profile_setup_screen class lists
            _DropdownField<String>(
              value: classLevel,
              hint: 'Select your class',
              label: 'Class Level',
              icon: Icons.class_outlined,
              items: const ['8th', '9th', '10th', '11th', '12th', 'Dropper'],
              labels: const ['Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12', 'Dropper'],
              onChanged: onClassLevelChanged,
            ),
            const SizedBox(height: DS.s12),

            // City & State side by side
            Row(
              children: [
                Expanded(
                  child: _AppField(
                    controller: cityCtrl,
                    label: 'City',
                    hint: 'Your city',
                    icon: Icons.location_city_outlined,
                  ),
                ),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: _AppField(
                    controller: stateCtrl,
                    label: 'State',
                    hint: 'Your state',
                    icon: Icons.map_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DS.s12),

            // School dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                schoolsAsync.when(
                  loading: () => _SchoolLoadingField(),
                  error: (err, st) => const SizedBox.shrink(),
                  data: (schools) => _DropdownField<String>(
                    value: schoolId,
                    hint: 'Select your school',
                    label: 'School',
                    icon: Icons.school_outlined,
                    items: schools.map((s) => s.id).toList(),
                    labels: schools.map((s) => s.name).toList(),
                    onChanged: onSchoolChanged,
                  ),
                ),
                const SizedBox(height: DS.s4),
                Text(
                  'Linking your school lets you appear on your school\'s leaderboard',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: DS.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: DS.s32),

            // Success banner
            if (saved) ...[_SuccessBanner(), const SizedBox(height: DS.s16)],

            // Save button
            _PrimaryButton(
              label: saved ? 'Saved!' : 'Save Changes',
              loading: saving,
              saved: saved,
              onTap: saving ? null : onSave,
            ),
          ],
        ),
      ),
    );
  }
}

class _SchoolLoadingField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: DS.primary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE: Section Label
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(DS.s6),
          decoration: BoxDecoration(
            color: DS.primaryLight,
            borderRadius: BorderRadius.circular(DS.radiusSm),
          ),
          child: Icon(icon, size: 14, color: DS.primary),
        ),
        const SizedBox(width: DS.s8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: DS.textPrimary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(width: DS.s8),
        Expanded(child: Divider(color: DS.border, thickness: 1)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE: Text Field
// ─────────────────────────────────────────────
class _AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  const _AppField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 15,
        color: readOnly ? DS.textSecondary : DS.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: DS.textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: DS.textHint, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: DS.s4),
          child: Icon(icon, size: 20, color: DS.textSecondary),
        ),
        filled: true,
        fillColor: readOnly ? DS.surfaceVariant : DS.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: DS.s16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: BorderSide(
            color: readOnly ? DS.border : DS.primary,
            width: readOnly ? 1.2 : 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.error, width: 1.8),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE: Dropdown Field
// ─────────────────────────────────────────────
class _DropdownField<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final String label;
  final IconData icon;
  final List<T> items;
  final List<String> labels;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.label,
    required this.icon,
    required this.items,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: DS.textSecondary,
        size: 20,
      ),
      style: const TextStyle(
        fontSize: 14,
        color: DS.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      dropdownColor: DS.surface,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: DS.textSecondary, fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: DS.textHint, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: DS.s4),
          child: Icon(icon, size: 18, color: DS.textSecondary),
        ),
        filled: true,
        fillColor: DS.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: DS.s14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.primary, width: 1.8),
        ),
      ),
      items: List.generate(
        items.length,
        (i) => DropdownMenuItem<T>(
          value: items[i],
          child: Text(
            labels[i],
            style: const TextStyle(fontSize: 13.5, color: DS.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE: Primary Button
// ─────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool saved;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    this.saved = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color startColor = saved ? DS.success : const Color(0xFFFF8C38);
    final Color endColor = saved ? const Color(0xFF059669) : DS.primary;

    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onTap == null
              ? null
              : LinearGradient(
                  colors: [startColor, endColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(DS.radiusMd),
          boxShadow: onTap == null
              ? []
              : [
                  BoxShadow(
                    color: (saved ? DS.success : DS.primary).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: DS.border,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (saved) ...[
                      const Icon(Icons.check_circle_rounded, size: 20),
                      const SizedBox(width: DS.s8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Success Banner
// ─────────────────────────────────────────────
class _SuccessBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s12),
      decoration: BoxDecoration(
        color: DS.successSurface,
        borderRadius: BorderRadius.circular(DS.radiusSm),
        border: Border.all(color: DS.success.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: DS.success,
            size: 18,
          ),
          SizedBox(width: DS.s8),
          Text(
            'Profile updated successfully!',
            style: TextStyle(
              color: DS.success,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
