import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';

import '../app/theme/app_widgets.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});
  final String title;
  final String? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      if (action != null) TextButton(onPressed: () {}, child: Text(action!)),
    ],
  );
}

class HostCard extends StatelessWidget {
  const HostCard({
    required this.plan,
    required this.onJoin,
    super.key,
    this.joined = false,
  });
  final PlanPreview plan;
  final VoidCallback onJoin;
  final bool joined;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            UserAvatar(
              name: plan.host,
              size: 46,
              online: true,
              color: plan.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.host,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${plan.distance} away',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.cxSoft,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.more_horiz_rounded, color: context.cxSoft),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          plan.title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          plan.description,
          style: TextStyle(color: context.cxSoft, height: 1.4),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 16,
              color: Color(0xFF0E8FA8),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                plan.time,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.people_outline_rounded,
              size: 16,
              color: Color(0xFFD9485F),
            ),
            const SizedBox(width: 6),
            Text(
              '${plan.members} joined',
              style: TextStyle(fontSize: 13, color: context.cxSoft),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          height: 46,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: joined
                ? const LinearGradient(
                    colors: [Color(0xFF2F7B69), Color(0xFF238F86)],
                  )
                : LinearGradient(colors: [plan.color, context.cxInk]),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onJoin,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    joined ? "You're In" : 'Join Plan',
                    key: ValueKey<bool>(joined),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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

class PlanPreview {
  const PlanPreview({
    required this.host,
    required this.title,
    required this.description,
    required this.distance,
    required this.members,
    required this.time,
    required this.color,
  });
  final String host;
  final String title;
  final String description;
  final String distance;
  final int members;
  final String time;
  final Color color;
}

const nearbyPlans = [
  PlanPreview(
    host: 'Maya Kapoor',
    title: 'Coffee & Camera Walk',
    description:
        'A slow walk, honest conversation, and a few good frames around Cubbon Park.',
    distance: '0.8 km',
    members: 3,
    time: 'Today - 6:30 PM',
    color: Color(0xFFD9485F),
  ),
  PlanPreview(
    host: 'Arjun Mehta',
    title: 'Vinyl After Work',
    description:
        'Bring one record you love. We will trade stories over a low-lit listening session.',
    distance: '1.4 km',
    members: 5,
    time: 'Today - 8:00 PM',
    color: Color(0xFF0E8FA8),
  ),
  PlanPreview(
    host: 'Nora Ali',
    title: 'Supper for Six',
    description:
        'A tiny table, shared plates, and no one checking their phone.',
    distance: '2.1 km',
    members: 4,
    time: 'Tomorrow - 7:30 PM',
    color: Color(0xFFD07A3A),
  ),
];
