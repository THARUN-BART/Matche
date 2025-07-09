import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoading({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double height;
  final EdgeInsets? margin;

  const SkeletonCard({
    super.key,
    this.height = 80,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar skeleton
            SkeletonLoading(
              width: 50,
              height: 50,
              borderRadius: 25,
            ),
            const SizedBox(width: 16),
            // Content skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoading(
                    width: double.infinity,
                    height: 16,
                  ),
                  const SizedBox(height: 8),
                  SkeletonLoading(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Button skeleton
            SkeletonLoading(
              width: 80,
              height: 36,
              borderRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return SkeletonCard(height: itemHeight);
      },
    );
  }
}

class SkeletonProfile extends StatelessWidget {
  const SkeletonProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile picture skeleton
          SkeletonLoading(
            width: 100,
            height: 100,
            borderRadius: 50,
          ),
          const SizedBox(height: 16),
          // Name skeleton
          SkeletonLoading(
            width: 150,
            height: 24,
          ),
          const SizedBox(height: 8),
          // Bio skeleton
          SkeletonLoading(
            width: double.infinity,
            height: 16,
          ),
          const SizedBox(height: 16),
          // Stats skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  SkeletonLoading(width: 30, height: 20),
                  const SizedBox(height: 4),
                  SkeletonLoading(width: 60, height: 12),
                ],
              ),
              Column(
                children: [
                  SkeletonLoading(width: 30, height: 20),
                  const SizedBox(height: 4),
                  SkeletonLoading(width: 60, height: 12),
                ],
              ),
              Column(
                children: [
                  SkeletonLoading(width: 30, height: 20),
                  const SizedBox(height: 4),
                  SkeletonLoading(width: 60, height: 12),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SkeletonMatchCard extends StatelessWidget {
  const SkeletonMatchCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Avatar skeleton
              SkeletonLoading(
                width: 60,
                height: 60,
                borderRadius: 30,
              ),
              const SizedBox(height: 12),
              // Name skeleton
              SkeletonLoading(
                width: 80,
                height: 16,
              ),
              const SizedBox(height: 8),
              // Bio skeleton
              SkeletonLoading(
                width: 120,
                height: 12,
              ),
              const SizedBox(height: 12),
              // Button skeleton
              SkeletonLoading(
                width: double.infinity,
                height: 32,
                borderRadius: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonMatchList extends StatelessWidget {
  final int itemCount;

  const SkeletonMatchList({
    super.key,
    this.itemCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return const SkeletonMatchCard();
        },
      ),
    );
  }
} 