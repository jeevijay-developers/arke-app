import 'package:flutter/material.dart';

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        SizedBox(height: 20),
        _SkeletonSectionHeader(),
        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _SkeletonContinueCard(),
        ),
        SizedBox(height: 24),
        _SkeletonSectionHeader(),
        SizedBox(height: 12),
        SizedBox(height: 178, child: _SkeletonLiveRow()),
        SizedBox(height: 24),
        _SkeletonSectionHeader(),
        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _SkeletonCourseGrid(),
        ),
        SizedBox(height: 32),
      ],
    );
  }
}

class _SkeletonSectionHeader extends StatelessWidget {
  const _SkeletonSectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SkeletonBox(width: 30, height: 30, radius: 10),
          SizedBox(width: 10),
          Expanded(child: _SkeletonLine(height: 14)),
          SizedBox(width: 12),
          _SkeletonBox(width: 64, height: 22, radius: 999),
        ],
      ),
    );
  }
}

class _SkeletonContinueCard extends StatelessWidget {
  const _SkeletonContinueCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _SkeletonColors.base,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              _SkeletonBox(width: 120, height: 20, radius: 999),
              Spacer(),
              _SkeletonLine(width: 70, height: 12),
            ],
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(width: 88, height: 66, radius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonLine(height: 14),
                    SizedBox(height: 8),
                    _SkeletonLine(width: 120, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          _SkeletonBox(width: double.infinity, height: 6, radius: 999),
          SizedBox(height: 14),
          _SkeletonBox(width: double.infinity, height: 44, radius: 14),
        ],
      ),
    );
  }
}

class _SkeletonLiveRow extends StatelessWidget {
  const _SkeletonLiveRow();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) => const _SkeletonLiveCard(),
    );
  }
}

class _SkeletonLiveCard extends StatelessWidget {
  const _SkeletonLiveCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SkeletonColors.base,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              _SkeletonBox(width: 70, height: 18, radius: 999),
              Spacer(),
              _SkeletonBox(width: 60, height: 18, radius: 999),
            ],
          ),
          SizedBox(height: 10),
          _SkeletonLine(height: 14),
          SizedBox(height: 8),
          _SkeletonLine(width: 140, height: 12),
          Spacer(),
          _SkeletonBox(width: double.infinity, height: 1, radius: 1),
          SizedBox(height: 10),
          Row(
            children: [
              _SkeletonBox(width: 110, height: 12, radius: 6),
              Spacer(),
              _SkeletonBox(width: 80, height: 20, radius: 999),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonCourseGrid extends StatelessWidget {
  const _SkeletonCourseGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, __) => const _SkeletonCourseTile(),
    );
  }
}

class _SkeletonCourseTile extends StatelessWidget {
  const _SkeletonCourseTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _SkeletonColors.base,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _SkeletonBox(
            width: double.infinity,
            height: 110,
            radius: 20,
            onlyTop: true,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonLine(height: 12),
                  SizedBox(height: 8),
                  _SkeletonLine(width: 90, height: 10),
                  Spacer(),
                  Row(
                    children: [
                      _SkeletonBox(width: 44, height: 10, radius: 6),
                      Spacer(),
                      _SkeletonBox(width: 48, height: 12, radius: 6),
                    ],
                  ),
                ],
              ),
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
  final bool onlyTop;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
    this.onlyTop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _SkeletonColors.highlight,
        borderRadius: onlyTop
            ? BorderRadius.vertical(top: Radius.circular(radius))
            : BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonColors {
  static const base = Color(0xFFF2ECE8);
  static const highlight = Color(0xFFE9E1DC);
}
