import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data/courses_providers.dart';
import 'data/models/content_item.dart';
import 'widgets/folder_tile.dart';
import 'youtube_player_screen.dart';

abstract class _C {
  static const primary  = Color(0xFFF97315);
  static const indigo   = Color(0xFF5B4BF5);
  static const red      = Color(0xFFEF4444);
  static const green    = Color(0xFF10B981);
  static const textSub  = Color(0xFF64748B);
  static const surface  = Color(0xFFFFFFFF);
  static const bg       = Color(0xFFFFFBF8);
  static const border   = Color(0xFFE5E7EB);
  static const liveRed  = Color(0xFFFEE2E2);
}

// ── Screen 4 — Folder View (Level 2) ──────────────────────────────────────
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
      loading: () => _Shell(
        title: folderName,
        child: const Center(
            child: CircularProgressIndicator(color: _C.primary)),
      ),
      error: (e, _) =>
          _Shell(title: folderName, child: Center(child: Text('Error: $e'))),
      data: (subs) {
        if (subs.isNotEmpty) {
          // Layout A — has sub-folders: show grid
          return _Shell(
            title: folderName,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: subs.length,
              itemBuilder: (_, i) => FolderTile(
                folder: subs[i],
                onTap: () => context.push(
                  '/my-courses/$courseId/folder/$folderId/sub/${subs[i].id}',
                  extra: subs[i].name,
                ),
              ),
            ),
          );
        }
        // Layout B — no sub-folders: flat content list
        return _Shell(
          title: folderName,
          child: ContentList(courseId: courseId, folderId: folderId),
        );
      },
    );
  }
}

// ── Screen 5 — Sub-folder View (Level 3) ──────────────────────────────────
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
  Widget build(BuildContext context, WidgetRef ref) => _Shell(
        title: subFolderName,
        child: ContentList(courseId: courseId, folderId: subFolderId),
      );
}

// ── Shared scaffold shell ──────────────────────────────────────────────────
class _Shell extends StatelessWidget {
  final String title;
  final Widget child;
  const _Shell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: _C.surface,
          elevation: 0,
          foregroundColor: const Color(0xFF111827),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827)),
          ),
        ),
        body: child,
      );
}

// ── Screen 6 — Content List ────────────────────────────────────────────────
class ContentList extends ConsumerWidget {
  final String courseId;
  final String folderId;
  const ContentList(
      {super.key, required this.courseId, required this.folderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(contentItemsProvider(folderId));
    final isEnrolled =
        ref.watch(isEnrolledProvider(courseId)).valueOrNull ?? false;

    return itemsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _C.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text('No content here yet.',
                style: TextStyle(color: _C.textSub)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _ContentCard(
            item: items[i],
            isEnrolled: isEnrolled,
          ),
        );
      },
    );
  }
}

// ── Content card dispatcher ────────────────────────────────────────────────
class _ContentCard extends StatelessWidget {
  final ContentItem item;
  final bool isEnrolled;
  const _ContentCard({required this.item, required this.isEnrolled});

  bool get _accessible => isEnrolled || item.isFreePreview;

  @override
  Widget build(BuildContext context) {
    return switch (item.type) {
      'live_class'       => _LiveClassCard(item: item, accessible: _accessible),
      'pdf'              => _PdfCard(item: item, accessible: _accessible),
      'recorded_lecture' => _VideoCard(item: item, accessible: _accessible),
      'video'            => _VideoCard(item: item, accessible: _accessible),
      'test'             => _TestCard(item: item, accessible: _accessible),
      _                  => _GenericCard(item: item),
    };
  }
}

// ── Live class card ────────────────────────────────────────────────────────
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
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLive ? _C.liveRed : _C.border,
          width: isLive ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isLive)
                _Chip('LIVE', _C.red)
              else
                _Chip('Live Class', _C.primary),
              const Spacer(),
              if (item.isFreePreview) _Chip('Preview', _C.green),
              if (!accessible && !item.isFreePreview)
                const Icon(Icons.lock_outline, size: 16, color: _C.textSub),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          if (item.scheduledAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 13, color: _C.textSub),
                const SizedBox(width: 4),
                Text(_fmtDateTime(item.scheduledAt!),
                    style: const TextStyle(
                        fontSize: 12, color: _C.textSub)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: isLive && accessible && item.zoomLink != null
                ? _ActionButton(
                    label: 'Join Now',
                    color: _C.green,
                    onTap: () =>
                        launchUrl(Uri.parse(item.zoomLink!)),
                  )
                : isUpcoming
                    ? _ActionButton(
                        label: 'Upcoming',
                        color: _C.textSub,
                        onTap: null,
                      )
                    : item.isPastLive &&
                            (item.fileUrl != null || item.videoUrl != null)
                        ? _ActionButton(
                            label: 'Watch Recording',
                            color: _C.primary,
                            onTap: () => _openVideo(context),
                          )
                        : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _openVideo(BuildContext context) {
    final url = item.videoUrl ?? item.fileUrl;
    if (url == null) return;
    final isYoutube = item.videoSource == 'youtube' ||
        url.contains('youtube.com') ||
        url.contains('youtu.be');
    if (isYoutube) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => YoutubePlayerScreen(videoUrl: url, title: item.title),
      ));
    } else {
      launchUrl(Uri.parse(url));
    }
  }

  String _fmtDateTime(DateTime dt) {
    final d = '${dt.day}/${dt.month}/${dt.year}';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$d  $h:$m';
  }
}

// ── PDF card ───────────────────────────────────────────────────────────────
class _PdfCard extends StatelessWidget {
  final ContentItem item;
  final bool accessible;
  const _PdfCard({required this.item, required this.accessible});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Red PDF icon block
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _C.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: _C.red, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
                if (item.isFreePreview)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: _Chip('Preview', _C.green),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          accessible
              ? GestureDetector(
                  onTap: () {
                    if (item.fileUrl != null) {
                      launchUrl(Uri.parse(item.fileUrl!));
                    }
                  },
                  child: const Icon(Icons.download_rounded,
                      color: _C.indigo, size: 22),
                )
              : const Icon(Icons.lock_outline,
                  color: _C.textSub, size: 20),
        ],
      ),
    );
  }
}

// ── Video / Recorded lecture card ──────────────────────────────────────────
class _VideoCard extends StatelessWidget {
  final ContentItem item;
  final bool accessible;
  const _VideoCard({required this.item, required this.accessible});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: accessible ? () => _play(context) : null,
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail — entire area tappable, play button centered
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _YoutubeThumbnail(
                    url: item.videoUrl ?? item.fileUrl,
                    videoSource: item.videoSource,
                  ),
                  if (item.isFreePreview)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _Chip('Preview', _C.green),
                    ),
                  if (accessible)
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _C.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _C.primary.withValues(alpha: 0.45),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    )
                  else
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white60,
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
            // Title only — no Play button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
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
    final isYoutube = item.videoSource == 'youtube' ||
        url.contains('youtube.com') ||
        url.contains('youtu.be');
    if (isYoutube) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => YoutubePlayerScreen(
          videoUrl: url,
          title: item.title,
        ),
      ));
    } else {
      launchUrl(Uri.parse(url));
    }
  }
}

// ── Test card ──────────────────────────────────────────────────────────────
class _TestCard extends StatelessWidget {
  final ContentItem item;
  final bool accessible;
  const _TestCard({required this.item, required this.accessible});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_outlined,
                color: _C.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827))),
          ),
          const SizedBox(width: 8),
          accessible && item.testId != null
              ? _ActionButton(
                  label: 'Attempt',
                  color: _C.indigo,
                  onTap: () => context.push('/test/${item.testId}'),
                )
              : const Icon(Icons.lock_outline,
                  color: _C.textSub, size: 20),
        ],
      ),
    );
  }
}

// ── Generic fallback card ──────────────────────────────────────────────────
class _GenericCard extends StatelessWidget {
  final ContentItem item;
  const _GenericCard({required this.item});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        padding: const EdgeInsets.all(14),
        child: Text(item.title,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
      );
}

// ── YouTube thumbnail ──────────────────────────────────────────────────────
class _YoutubeThumbnail extends StatelessWidget {
  final String? url;
  final String? videoSource;
  const _YoutubeThumbnail({this.url, this.videoSource});

  String? get _thumbUrl {
    if (url == null) return null;
    final isYoutube = videoSource == 'youtube' ||
        url!.contains('youtube.com') ||
        url!.contains('youtu.be');
    if (!isYoutube) return null;
    // Extract video ID from any YouTube URL format
    final uri = Uri.tryParse(url!);
    String? videoId;
    if (uri != null) {
      if (url!.contains('youtu.be')) {
        videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      } else {
        videoId = uri.queryParameters['v'];
      }
    }
    if (videoId == null) return null;
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumbUrl;
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: thumb != null
          ? Image.network(
              thumb,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => _darkBox,
            )
          : _darkBox,
    );
  }

  Widget get _darkBox => Container(
        height: 150,
        color: const Color(0xFF1E293B),
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: onTap != null
                ? color
                : color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  color: onTap != null ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
      );
}
