import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../update/app_update_service.dart';
import 'neu.dart';

/// Compact “Оновити” control — visible only when a newer APK is available.
class UpdateButton extends StatelessWidget {
  const UpdateButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final svc = AppUpdateService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        if (!svc.hasUpdate) return const SizedBox.shrink();
        final info = svc.available!;
        final label = svc.downloading
            ? (svc.progress != null
                ? '${(svc.progress! * 100).round()}%'
                : '…')
            : (compact ? 'Оновити' : 'Оновити ${info.version}');

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: svc.downloading ? null : () => svc.downloadAndInstall(),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 14,
                  vertical: compact ? 6 : 8,
                ),
                decoration: neuBox(d: 2, b: 5, radius: 12),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w800,
                    color: kAccentBlue,
                  ),
                ),
              ),
            ),
            if (svc.error != null) ...[
              const SizedBox(height: 4),
              Text(
                svc.error!,
                style: const TextStyle(fontSize: 10, color: kDangerRed),
              ),
            ],
          ],
        );
      },
    );
  }
}
