import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/tokens.dart';
import 'neu.dart';

class AnnouncementPopup extends StatelessWidget {
  final Announcement announcement;
  final int remaining;
  final VoidCallback onNext;

  const AnnouncementPopup({
    super.key,
    required this.announcement,
    required this.remaining,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.35),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: NeuCard(
              radius: 28,
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: neuBox(d: 4, b: 8, radius: 22),
                        child: const Icon(Icons.campaign_outlined, color: kAccentBlue),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Оголошення',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kTextMain),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    announcement.text,
                    style: const TextStyle(fontSize: 15, color: kTextMain, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '— ${announcement.createdBy}',
                    style: const TextStyle(fontSize: 12, color: kTextMuted),
                  ),
                  const SizedBox(height: 22),
                  if (remaining > 0)
                    Text('ще $remaining', style: const TextStyle(fontSize: 12, color: kTextMuted)),
                  const SizedBox(height: 10),
                  NeuButton(
                    label: remaining > 0 ? 'Далі →' : 'Ок',
                    onTap: onNext,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
