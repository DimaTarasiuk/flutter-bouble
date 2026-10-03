import 'package:flutter/material.dart';
import 'tokens.dart';

/// Централізована типографіка. Замість інлайнових TextStyle по екранах —
/// звідси. Міняєш тут — міняється всюди.
class AppText {
  static const TextStyle h1 = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: kTextMain);
  static const TextStyle h2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextMain);
  static const TextStyle h3 = TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextMain);

  static const TextStyle body = TextStyle(fontSize: 15, color: kTextMain);
  static const TextStyle bodyBold = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain);
  static const TextStyle bodySmall = TextStyle(fontSize: 13, color: kTextMain);

  static const TextStyle label = TextStyle(fontSize: 12, color: kTextMuted);
  static const TextStyle muted = TextStyle(fontSize: 13, color: kTextMuted);
  static const TextStyle mutedSmall = TextStyle(fontSize: 11.5, color: kTextMuted);

  static const TextStyle button = TextStyle(fontSize: 17, fontWeight: FontWeight.w800);
  static const TextStyle link = TextStyle(fontSize: 14, color: kTextMuted);

  static const TextStyle error = TextStyle(fontSize: 13.5, color: kDangerRed);
  static const TextStyle success = TextStyle(fontSize: 13.5, color: kAccentBlue);

  static const TextStyle badge = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white);
  static const TextStyle timestamp = TextStyle(fontSize: 10.5, color: kTextMuted);

  static const TextStyle sectionTitle =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextMain);
}
