import 'package:flutter/material.dart';

import 'social_components.dart';

class TemporaryPlanChatScreen extends StatelessWidget {
  const TemporaryPlanChatScreen({required this.plan, super.key});
  final PlanPreview plan;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(plan.title)),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _ChatBubble(text: 'Welcome to the plan chat!', mine: false),
              const SizedBox(height: 12),
              const _ChatBubble(text: 'Excited to meet everyone.', mine: true),
              const SizedBox(height: 12),
              _ChatBubble(text: 'See you at ${plan.time}.', mine: false),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Maya is typing...',
                  style: TextStyle(color: Color(0xFF9DE8D7)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Say hello to the group',
              suffixIcon: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.mine});
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFF7858D7) : const Color(0xFF1A2238),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: const TextStyle(height: 1.35)),
    ),
  );
}
