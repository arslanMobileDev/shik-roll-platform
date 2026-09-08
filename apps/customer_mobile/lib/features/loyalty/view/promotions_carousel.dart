import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../bloc/loyalty_cubit.dart';
import '../data/loyalty_models.dart';

/// Horizontal carousel of active promotion campaigns (ADR-1614) above the
/// menu catalog. Renders nothing while the feed is empty or not loaded —
/// promotions never block the catalog.
class PromotionsCarousel extends StatelessWidget {
  const PromotionsCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoyaltyCubit, LoyaltyState>(
      buildWhen: (previous, next) => previous.promotions != next.promotions,
      builder: (context, state) {
        if (state.promotions.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          key: const ValueKey('promotions-carousel'),
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            itemCount: state.promotions.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s12),
            itemBuilder: (context, index) =>
                _PromotionBanner(campaign: state.promotions[index]),
          ),
        );
      },
    );
  }
}

class _PromotionBanner extends StatelessWidget {
  const _PromotionBanner({required this.campaign});

  final PromotionCampaign campaign;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandAccent, AppColors.primary],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The banner art is decorative: on any failure (or an empty URL in
          // demo/test data) the gradient card with the copy remains.
          if (campaign.bannerUrl.isNotEmpty)
            Image.network(
              campaign.bannerUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black38)],
                  ),
                ),
                if (campaign.description != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    campaign.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 12,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black38)],
                    ),
                  ),
                ],
                const Spacer(),
                if (campaign.actionUrl != null)
                  const Row(
                    children: [
                      Text(
                        'Подробнее',
                        style: TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: AppSpacing.s4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.onPrimary,
                      ),
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
