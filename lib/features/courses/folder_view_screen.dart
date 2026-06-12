import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'data/courses_providers.dart';
import 'data/models/content_item.dart';
import 'data/models/folder.dart';
import 'youtube_player_screen.dart';
import 's3_video_player_screen.dart';
import 'pdf_viewer_screen.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
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
  static const warning = Color(0xFFF59E0B);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFFEEF2FF);

  static const double s2 = 2;
  static const double s3 = 3;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s7 = 7;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────
bool _isYoutubeUrl(String url, String? videoSource) {
  if (url.contains('youtube.com') || url.contains('youtu.be')) return true;
  if (url.startsWith('http')) return false;
  return videoSource == 'youtube';
}

// ─────────────────────────────────────────────
// FOLDER VIEW SCREEN (Level 2)
// ─────────────────────────────────────────────
class FolderViewScreen extends ConsumerWidget {
  final String courseId;
  final String folderId;
  final String folderName;

  const FolderViewScreen({
    super.key,
    required this.courseId,
    required this.folderId,
    required this.folderName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subFoldersProvider(folderId));

    return subAsync.when(
      loading: () => _LmsShell(
        title: folderName,
        child: const Center(
          child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
        ),
      ),
      error: (e, _) => _LmsShell(
        title: folderName,
        child: _ErrorBody(message: 'Error: $e'),
      ),
      data: (subs) {
        if (subs.isNotEmpty) {
          return _LmsShell(
            title: folderName,
            child: _FolderWithContentView(
              courseId: courseId,
              folderId: folderId,
              subFolders: subs,
            ),
          );
        }
        return _LmsShell(
          title: folderName,
          child: ContentList(courseId: courseId, folderId: folderId),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// SUB-FOLDER VIEW SCREEN (Level 3)
// ─────────────────────────────────────────────
class SubFolderViewScreen extends ConsumerWidget {
  final String courseId;
  final String folderId;
  final String subFolderId;
  final String subFolderName;

  const SubFolderViewScreen({
    super.key,
    required this.courseId,
    required this.folderId,
    required this.subFolderId,
    required this.subFolderName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => _LmsShell(
    title: subFolderName,
    child: ContentList(courseId: courseId, folderId: subFolderId),
  );
}

// ─────────────────────────────────────────────
// SHARED LMS SHELL
// ─────────────────────────────────────────────
class _LmsShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _LmsShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: Column(
          children: [
            // ── Orange gradient header ──
            _FolderHeader(title: title),
            // ── Content ──
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FOLDER HEADER
// ─────────────────────────────────────────────
class _FolderHeader extends StatelessWidget {
  final String title;
  const _FolderHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8C38), DS.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(DS.radiusXl),
              bottomRight: Radius.circular(DS.radiusXl),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x47F97315),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DS.s8, DS.s8, DS.s16, DS.s20),
              child: Row(
                children: [
                  // Back
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.s12),

                  // Folder icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x2EFFFFFF),
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                      border: Border.all(
                        color: const Color(0x47FFFFFF),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(7),
                    child: SvgPicture.asset(
                      'assets/SVGs/folder-blank.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: DS.s12),

                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Course Content',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.70),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Decorative circles
        Positioned(
          top: -40,
          right: -30,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 20,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// FOLDER WITH CONTENT VIEW
// ─────────────────────────────────────────────
class _FolderWithContentView extends ConsumerWidget {
  final String courseId;
  final String folderId;
  final List<CourseFolder> subFolders;

  const _FolderWithContentView({
    required this.courseId,
    required this.folderId,
    required this.subFolders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(contentItemsProvider(folderId));
    final isEnrolled =
        ref.watch(isEnrolledProvider(courseId)).valueOrNull ?? false;

    return CustomScrollView(
      slivers: [
        // ── Folders section label ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(DS.s16, DS.s20, DS.s16, DS.s12),
          sliver: SliverToBoxAdapter(
            child: _SectionLabel(
              label: 'Folders',
              svgAsset: 'assets/SVGs/folder-blank.svg',
              count: subFolders.length,
            ),
          ),
        ),

        // ── Folder grid ──
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: DS.s16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _ModernFolderTile(
                folder: subFolders[i],
                index: i,
                onTap: () => context.push(
                  '/my-courses/$courseId/folder/$folderId/sub/${subFolders[i].id}',
                  extra: subFolders[i].name,
                ),
              ),
              childCount: subFolders.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: DS.s12,
              crossAxisSpacing: DS.s12,
              childAspectRatio: 1.55,
            ),
          ),
        ),

        // ── Direct content items (if any) ──
        itemsAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(DS.s24),
              child: Center(
                child: CircularProgressIndicator(
                  color: DS.primary,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
          error: (e, _) =>
              SliverToBoxAdapter(child: _ErrorBody(message: 'Error: $e')),
          data: (items) {
            if (items.isEmpty)
              return const SliverToBoxAdapter(child: SizedBox(height: DS.s24));
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                DS.s16,
                DS.s20,
                DS.s16,
                DS.s32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SectionLabel(
                    label: 'Content',
                    svgAsset: 'assets/SVGs/video.svg',
                    count: items.length,
                  ),
                  const SizedBox(height: DS.s12),
                  ...items.asMap().entries.map(
                    (e) => Padding(
                      padding: EdgeInsets.only(
                        bottom: e.key < items.length - 1 ? DS.s10 : 0,
                      ),
                      child: _ContentCard(
                        item: e.value,
                        isEnrolled: isEnrolled,
                      ),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// MODERN FOLDER TILE
// ─────────────────────────────────────────────
class _ModernFolderTile extends StatelessWidget {
  final CourseFolder folder;
  final int index;
  final VoidCallback onTap;

  const _ModernFolderTile({
    required this.folder,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(color: DS.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/SVGs/folder-blank.svg',
              width: 52,
              height: 52,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: DS.s8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DS.s8),
              child: Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: DS.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONTENT LIST
// ─────────────────────────────────────────────
class ContentList extends ConsumerWidget {
  final String courseId;
  final String folderId;

  const ContentList({
    super.key,
    required this.courseId,
    required this.folderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(contentItemsProvider(folderId));
    final isEnrolled =
        ref.watch(isEnrolledProvider(courseId)).valueOrNull ?? false;

    return itemsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
      ),
      error: (e, _) => _ErrorBody(message: 'Error: $e'),
      data: (items) {
        if (items.isEmpty) {
          return _EmptyContent();
        }

        // Group by type for section headers
        final videos = items
            .where((i) => i.type == 'video' || i.type == 'recorded_lecture')
            .toList();
        final pdfs = items.where((i) => i.type == 'pdf').toList();
        final lives = items.where((i) => i.type == 'live_class').toList();
        final tests = items.where((i) => i.type == 'test').toList();
        final others = items
            .where(
              (i) => ![
                'video',
                'recorded_lecture',
                'pdf',
                'live_class',
                'test',
              ].contains(i.type),
            )
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(DS.s16, DS.s20, DS.s16, DS.s32),
          children: [
            if (lives.isNotEmpty)
              ..._section(
                'Live Classes',
                'assets/SVGs/live-class.svg',
                DS.error,
                lives,
                isEnrolled,
              ),
            if (videos.isNotEmpty)
              ..._section(
                'Video Lectures',
                'assets/SVGs/video.svg',
                DS.primary,
                videos,
                isEnrolled,
              ),
            if (pdfs.isNotEmpty)
              ..._section(
                'PDF Notes',
                'assets/SVGs/pdf-document.svg',
                DS.error,
                pdfs,
                isEnrolled,
              ),
            if (tests.isNotEmpty)
              ..._section(
                'Tests',
                'assets/SVGs/exam.svg',
                DS.indigo,
                tests,
                isEnrolled,
              ),
            if (others.isNotEmpty)
              ..._section(
                'Resources',
                'assets/SVGs/folder-blank.svg',
                DS.warning,
                others,
                isEnrolled,
              ),
          ],
        );
      },
    );
  }

  List<Widget> _section(
    String label,
    String svgAsset,
    Color color,
    List<ContentItem> items,
    bool isEnrolled,
  ) {
    return [
      _SectionLabel(
        label: label,
        svgAsset: svgAsset,
        count: items.length,
        color: color,
      ),
      const SizedBox(height: DS.s12),
      ...items.asMap().entries.map(
        (e) => Padding(
          padding: EdgeInsets.only(
            bottom: e.key < items.length - 1 ? DS.s10 : DS.s20,
          ),
          child: _ContentCard(item: e.value, isEnrolled: isEnrolled),
        ),
      ),
    ];
  }
}

// ─────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final String? svgAsset;
  final int count;
  final Color color;

  const _SectionLabel({
    required this.label,
    this.svgAsset,
    this.count = 0,
    this.color = DS.primary,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(DS.radiusSm),
        ),
        padding: const EdgeInsets.all(5),
        child: SvgPicture.asset(
          svgAsset ?? 'assets/SVGs/folder-blank.svg',
          fit: BoxFit.contain,
        ),
      ),
      const SizedBox(width: DS.s8),
      Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: DS.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      const SizedBox(width: DS.s8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────
// CONTENT CARD DISPATCHER
// ─────────────────────────────────────────────
class _ContentCard extends StatelessWidget {
  final ContentItem item;
  final bool isEnrolled;

  const _ContentCard({required this.item, required this.isEnrolled});

  bool get _accessible => isEnrolled || item.isFreePreview;

  @override
  Widget build(BuildContext context) => switch (item.type) {
    'live_class' => _LiveClassCard(item: item, accessible: _accessible),
    'pdf' => _PdfCard(item: item, accessible: _accessible),
    'recorded_lecture' => _VideoCard(item: item, accessible: _accessible),
    'video' => _VideoCard(item: item, accessible: _accessible),
    'test' => _TestCard(item: item, accessible: _accessible),
    _ => _GenericCard(item: item),
  };
}

// ─────────────────────────────────────────────
// LIVE CLASS CARD
// ─────────────────────────────────────────────
class _LiveClassCard extends StatelessWidget {
  final ContentItem item;
  final bool accessible;

  const _LiveClassCard({required this.item, required this.accessible});

  @override
  Widget build(BuildContext context) {
    final isLive = item.isLiveNow;
    final isUpcoming = item.isUpcoming;

    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(
          color: isLive ? DS.error.withOpacity(0.35) : DS.border,
          width: isLive ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isLive
                ? DS.error.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top accent
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: isLive ? DS.error : DS.primary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DS.radiusMd),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DS.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    if (isLive)
                      _LiveBadge()
                    else
                      _TypeBadge(
                        label: 'Live Class',
                        color: DS.primary,
                        icon: Icons.sensors_rounded,
                      ),
                    const Spacer(),
                    if (item.isFreePreview)
                      _TypeBadge(
                        label: 'Free',
                        color: DS.success,
                        icon: Icons.star_rounded,
                      ),
                    if (!accessible && !item.isFreePreview)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: DS.surfaceVariant,
                          borderRadius: BorderRadius.circular(DS.radiusSm),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: DS.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: DS.s10),

                // Title
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: DS.textPrimary,
                    height: 1.3,
                  ),
                ),

                // Scheduled time
                if (item.scheduledAt != null) ...[
                  const SizedBox(height: DS.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s10,
                      vertical: DS.s6,
                    ),
                    decoration: BoxDecoration(
                      color: DS.surfaceVariant,
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                      border: Border.all(color: DS.border, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: DS.textSecondary,
                        ),
                        const SizedBox(width: DS.s6),
                        Text(
                          _fmtDateTime(item.scheduledAt!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: DS.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: DS.s12),
                Divider(color: DS.border, height: 1),
                const SizedBox(height: DS.s10),

                // Action row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isLive && accessible && item.zoomLink != null)
                      _GradientButton(
                        label: 'Join Now',
                        icon: Icons.video_call_rounded,
                        onTap: () => launchUrl(Uri.parse(item.zoomLink!)),
                      )
                    else if (isUpcoming)
                      _OutlineActionButton(
                        label: 'Upcoming',
                        icon: Icons.schedule_rounded,
                        enabled: false,
                      )
                    else if (item.isPastLive &&
                        (item.fileUrl != null || item.videoUrl != null))
                      _GradientButton(
                        label: 'Watch Recording',
                        icon: Icons.play_arrow_rounded,
                        onTap: () => _openVideo(context),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openVideo(BuildContext context) {
    final url = item.videoUrl ?? item.fileUrl;
    if (url == null) return;
    if (_isYoutubeUrl(url, item.videoSource)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => YoutubePlayerScreen(videoUrl: url, title: item.title),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => S3VideoPlayerScreen(videoUrl: url, title: item.title),
        ),
      );
    }
  }

  static String _fmtDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} · $h:$m';
  }
}

// ─────────────────────────────────────────────
// PDF CARD
// ─────────────────────────────────────────────
class _PdfCard extends StatelessWidget {
  final ContentItem item;
  final bool accessible;

  const _PdfCard({required this.item, required this.accessible});

  void _open(BuildContext context) {
    final url = item.fileUrl;
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(title: item.title, fileUrl: url),
      ),
    );
  }

  void _showLocked(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Enroll in this course to access PDFs'),
        backgroundColor: DS.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.radiusSm),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        accessible ? _open(context) : _showLocked(context);
      },
      child: Container(
        padding: const EdgeInsets.all(DS.s14),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(
            color: accessible ? DS.border : DS.border,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // PDF icon tile
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accessible ? DS.errorSurface : DS.surfaceVariant,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              padding: const EdgeInsets.all(8),
              child: SvgPicture.asset(
                'assets/SVGs/pdf-document.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: DS.s12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: accessible ? DS.textPrimary : DS.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (item.isFreePreview) ...[
                    const SizedBox(height: DS.s4),
                    _TypeBadge(
                      label: 'Free',
                      color: DS.success,
                      icon: Icons.star_rounded,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: DS.s8),

            // Action icon
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accessible ? DS.primaryLight : DS.surfaceVariant,
                borderRadius: BorderRadius.circular(DS.radiusSm),
              ),
              child: Icon(
                accessible
                    ? Icons.open_in_new_rounded
                    : Icons.lock_outline_rounded,
                color: accessible ? DS.primary : DS.textHint,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// VIDEO CARD
// ─────────────────────────────────────────────
class _VideoCard extends StatelessWidget {
  final ContentItem item;
  final bool accessible;

  const _VideoCard({required this.item, required this.accessible});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: accessible
          ? () {
              HapticFeedback.selectionClick();
              _play(context);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(DS.s14),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(color: DS.border, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Video icon tile
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accessible ? DS.primaryLight : DS.surfaceVariant,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              padding: const EdgeInsets.all(8),
              child: SvgPicture.asset(
                'assets/SVGs/video.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: DS.s12),

            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: accessible ? DS.textPrimary : DS.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (item.isFreePreview) ...[
                    const SizedBox(height: DS.s4),
                    _TypeBadge(
                      label: 'Free',
                      color: DS.success,
                      icon: Icons.star_rounded,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: DS.s8),

            // Play / lock action
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accessible ? DS.primaryLight : DS.surfaceVariant,
                borderRadius: BorderRadius.circular(DS.radiusSm),
              ),
              child: Icon(
                accessible
                    ? Icons.play_arrow_rounded
                    : Icons.lock_outline_rounded,
                color: accessible ? DS.primary : DS.textHint,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _play(BuildContext context) {
    final url = item.videoUrl ?? item.fileUrl;
    if (url == null) return;
    if (_isYoutubeUrl(url, item.videoSource)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => YoutubePlayerScreen(videoUrl: url, title: item.title),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => S3VideoPlayerScreen(videoUrl: url, title: item.title),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────
// TEST CARD
// ─────────────────────────────────────────────
class _TestCard extends StatelessWidget {
  final ContentItem item;
  final bool accessible;

  const _TestCard({required this.item, required this.accessible});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DS.s14),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Quiz icon tile
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accessible ? DS.indigoLight : DS.surfaceVariant,
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
            padding: const EdgeInsets.all(8),
            child: SvgPicture.asset(
              'assets/SVGs/exam.svg',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: DS.s12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: DS.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: DS.s4),
                if (item.isFreePreview)
                  _TypeBadge(
                    label: 'Free',
                    color: DS.success,
                    icon: Icons.star_rounded,
                  )
                else
                  const Text(
                    'Practice Test',
                    style: TextStyle(color: DS.textSecondary, fontSize: 11.5),
                  ),
              ],
            ),
          ),

          const SizedBox(width: DS.s8),

          // Attempt / lock
          accessible && item.testId != null
              ? _GradientButton(
                  label: 'Attempt',
                  icon: Icons.arrow_forward_rounded,
                  onTap: () => context.push('/test/${item.testId}'),
                )
              : Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: DS.surfaceVariant,
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: DS.textHint,
                    size: 16,
                  ),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GENERIC CARD
// ─────────────────────────────────────────────
class _GenericCard extends StatelessWidget {
  final ContentItem item;
  const _GenericCard({required this.item});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(DS.s14),
    decoration: BoxDecoration(
      color: DS.surface,
      borderRadius: BorderRadius.circular(DS.radiusMd),
      border: Border.all(color: DS.border, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: DS.primaryLight,
            borderRadius: BorderRadius.circular(DS.radiusSm),
          ),
          child: const Icon(
            Icons.insert_drive_file_outlined,
            color: DS.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: DS.s12),
        Expanded(
          child: Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: DS.textPrimary,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// LIVE BADGE (animated)
// ─────────────────────────────────────────────
class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.s10, vertical: DS.s4),
    decoration: BoxDecoration(
      color: DS.error,
      borderRadius: BorderRadius.circular(999),
      boxShadow: [
        BoxShadow(
          color: DS.error.withOpacity(0.35),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: DS.s6),
        const Text(
          'LIVE NOW',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// TYPE BADGE
// ─────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _TypeBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.25), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: DS.s4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// GRADIENT BUTTON
// ─────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s14, vertical: DS.s8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C38), DS.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DS.radiusSm),
        boxShadow: [
          BoxShadow(
            color: DS.primary.withOpacity(0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: DS.s6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// OUTLINE ACTION BUTTON
// ─────────────────────────────────────────────
class _OutlineActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;

  const _OutlineActionButton({
    required this.label,
    required this.icon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.s12, vertical: DS.s7),
    decoration: BoxDecoration(
      color: DS.surfaceVariant,
      borderRadius: BorderRadius.circular(DS.radiusSm),
      border: Border.all(color: DS.border, width: 1.2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: DS.textSecondary),
        const SizedBox(width: DS.s6),
        Text(
          label,
          style: const TextStyle(
            color: DS.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// EMPTY CONTENT
// ─────────────────────────────────────────────
class _EmptyContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(DS.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8C38), DS.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(DS.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: DS.primary.withOpacity(0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: DS.s16),
          const Text(
            'No content here yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: DS.s8),
          const Text(
            'Content will appear here once it\'s added to this folder.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: DS.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// ERROR BODY
// ─────────────────────────────────────────────
class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(DS.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: DS.errorSurface,
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: DS.error,
              size: 28,
            ),
          ),
          const SizedBox(height: DS.s12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: DS.textSecondary, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}
