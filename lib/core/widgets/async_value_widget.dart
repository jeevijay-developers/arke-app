import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../error/app_exception.dart';
import '../network/connectivity_service.dart';

/// Drop-in replacement for `asyncValue.when(...)`.
///
/// Usage:
/// ```dart
/// AsyncValueWidget(
///   value: ref.watch(someProvider),
///   data: (items) => MyList(items),
/// )
/// ```
///
/// Optional:
///   empty      — widget shown when data list is empty (pass isEmpty check via [isEmpty])
///   onRetry    — callback for the Retry button (defaults to null = no button)
///   loadingWidget — custom shimmer / skeleton
class AsyncValueWidget<T> extends ConsumerWidget {
  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.emptyMessage = 'Nothing here yet.',
    this.emptyIcon = Icons.inbox_outlined,
    this.loadingWidget,
    this.errorPadding = const EdgeInsets.all(32),
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  /// Return true when the loaded data should show the empty state.
  final bool Function(T data)? isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? loadingWidget;
  final EdgeInsets errorPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      loading: () => loadingWidget ?? const _DefaultLoader(),
      error: (err, _) => _ErrorView(
        error: err,
        padding: errorPadding,
        onRetry: onRetry,
        ref: ref,
      ),
      data: (d) {
        if (isEmpty != null && isEmpty!(d)) {
          return _EmptyView(
            message: emptyMessage,
            icon: emptyIcon,
            onRetry: onRetry,
          );
        }
        return data(d);
      },
    );
  }
}

// ── Default loader ─────────────────────────────────────────────────────────────

class _DefaultLoader extends StatelessWidget {
  const _DefaultLoader();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(strokeWidth: 2.5),
    ),
  );
}

// ── Error view ─────────────────────────────────────────────────────────────────

class _ErrorView extends ConsumerWidget {
  const _ErrorView({
    required this.error,
    required this.padding,
    required this.ref,
    this.onRetry,
  });

  final Object error;
  final EdgeInsets padding;
  final VoidCallback? onRetry;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final isOnline = ref.watch(isOnlineProvider);
    final appEx = AppException.from(error);

    // If offline, override with a clearer offline message
    final message = !isOnline
        ? 'No internet connection.\nPlease check your network and try again.'
        : appEx.userMessage;

    final icon = !isOnline ? Icons.wifi_off_rounded : _iconFor(appEx);

    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 34,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.55,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Try Again'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(AppException ex) => switch (ex) {
    NetworkException() => Icons.wifi_off_rounded,
    TimeoutException() => Icons.timer_off_rounded,
    ServerException() => Icons.cloud_off_rounded,
    UnauthorizedException() => Icons.lock_outline_rounded,
    NotFoundException() => Icons.search_off_rounded,
    RateLimitException() => Icons.hourglass_top_rounded,
    _ => Icons.error_outline_rounded,
  };
}

// ── Empty view ─────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message, required this.icon, this.onRetry});

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 34,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
