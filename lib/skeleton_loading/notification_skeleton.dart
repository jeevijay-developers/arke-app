import 'package:flutter/material.dart';

class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: const [
        _SkeletonGroup(),
        SizedBox(height: 16),
        _SkeletonGroup(),
      ],
    );
  }
}

class _SkeletonGroup extends StatelessWidget {
  const _SkeletonGroup();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _SkeletonDateLabel(),
        SizedBox(height: 10),
        _SkeletonNotifCard(),
        SizedBox(height: 10),
        _SkeletonNotifCard(),
      ],
    );
  }
}

class _SkeletonDateLabel extends StatelessWidget {
  const _SkeletonDateLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _SkeletonBox(width: 4, height: 16, radius: 4),
        SizedBox(width: 8),
        _SkeletonLine(width: 80, height: 12),
        SizedBox(width: 8),
        Expanded(child: _SkeletonLine(height: 1)),
      ],
    );
  }
}

class _SkeletonNotifCard extends StatelessWidget {
  const _SkeletonNotifCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SkeletonColors.base,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SkeletonBox(width: 46, height: 46, radius: 14),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _SkeletonLine(height: 12)),
                    SizedBox(width: 8),
                    _SkeletonLine(width: 40, height: 10),
                  ],
                ),
                SizedBox(height: 8),
                _SkeletonLine(height: 10),
                SizedBox(height: 6),
                _SkeletonLine(width: 160, height: 10),
                SizedBox(height: 10),
                Row(
                  children: [
                    _SkeletonBox(width: 64, height: 18, radius: 999),
                    SizedBox(width: 8),
                    _SkeletonBox(width: 44, height: 14, radius: 6),
                    Spacer(),
                    _SkeletonBox(width: 8, height: 8, radius: 999),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double height;
  final double? width;
  const _SkeletonLine({required this.height, this.width});

  @override
  Widget build(BuildContext context) {
    return _SkeletonBox(
      width: width ?? double.infinity,
      height: height,
      radius: 6,
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _SkeletonColors.highlight,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonColors {
  static const base = Color(0xFFF2ECE8);
  static const highlight = Color(0xFFE9E1DC);
}
