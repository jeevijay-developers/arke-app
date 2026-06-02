import 'package:flutter/material.dart';

class DoubtSkeleton extends StatelessWidget {
  const DoubtSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const _SkeletonDoubtCard(),
    );
  }
}

class _SkeletonDoubtCard extends StatelessWidget {
  const _SkeletonDoubtCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SkeletonColors.base,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              _SkeletonBox(width: 70, height: 18, radius: 999),
              SizedBox(width: 6),
              _SkeletonBox(width: 70, height: 18, radius: 999),
              Spacer(),
              _SkeletonBox(width: 64, height: 18, radius: 999),
              SizedBox(width: 8),
              _SkeletonLine(width: 44, height: 10),
            ],
          ),
          SizedBox(height: 12),
          _SkeletonLine(height: 12),
          SizedBox(height: 6),
          _SkeletonLine(height: 12),
          SizedBox(height: 6),
          _SkeletonLine(width: 200, height: 12),
          SizedBox(height: 12),
          _SkeletonBox(width: 120, height: 26, radius: 10),
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
