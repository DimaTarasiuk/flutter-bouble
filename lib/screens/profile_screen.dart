import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';
import '../theme/tokens.dart';
import '../widgets/neu.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser me;
  const ProfileScreen({super.key, required this.me});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiClient();
  late final TextEditingController _username;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _birthDate; // ДД.ММ.РРРР
  String? _gender;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.me.username);
    _firstName = TextEditingController(text: widget.me.firstName);
    _lastName = TextEditingController(text: widget.me.lastName);
    _birthDate = TextEditingController(text: _isoToDisplay(widget.me.birthDate));
    _gender = widget.me.gender.isEmpty ? null : widget.me.gender;
  }

  String _isoToDisplay(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final parts = iso.split('-');
    if (parts.length != 3) return '';
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  String? _displayToIso(String display) {
    final trimmed = display.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('.');
    if (parts.length != 3) return null;
    final d = parts[0].padLeft(2, '0');
    final m = parts[1].padLeft(2, '0');
    final y = parts[2];
    return '$y-$m-$d';
  }

  void _showAvatarTip() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('ми ще робимо цю фічу'), duration: Duration(milliseconds: 2200)),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      await _api.patchMe(
        username: _username.text.trim(),
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        birthDate: _displayToIso(_birthDate.text),
        gender: _gender,
      );
      setState(() => _success = 'Збережено');
    } on ApiException catch (e) {
      setState(() => _error = e.userMessage);
    } catch (_) {
      setState(() => _error = 'Не вдалося зберегти');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _genderChip(String value, String label) {
    final selected = _gender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = selected ? null : value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: selected
              ? neuBox(inset: true, d: 3, b: 6, radius: 18)
              : neuBox(d: 3, b: 6, radius: 18),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: selected ? kAccentBlue : kTextMuted),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: kTextMain),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text('Профіль',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextMain)),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _showAvatarTip,
                  child: Avatar(username: widget.me.username, size: 88, bg: kAccentBlue),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Логін', style: TextStyle(color: kTextMuted, fontSize: 12)),
              const SizedBox(height: 6),
              NeuTextField(controller: _username, hint: 'Логін'),
              const SizedBox(height: 16),
              const Text("Ім'я", style: TextStyle(color: kTextMuted, fontSize: 12)),
              const SizedBox(height: 6),
              NeuTextField(controller: _firstName, hint: "Ім'я"),
              const SizedBox(height: 16),
              const Text('Прізвище', style: TextStyle(color: kTextMuted, fontSize: 12)),
              const SizedBox(height: 6),
              NeuTextField(controller: _lastName, hint: 'Прізвище'),
              const SizedBox(height: 16),
              const Text('Дата народження', style: TextStyle(color: kTextMuted, fontSize: 12)),
              const SizedBox(height: 6),
              NeuTextField(controller: _birthDate, hint: 'ДД.ММ.РРРР', keyboardType: TextInputType.datetime),
              const SizedBox(height: 16),
              const Text('Стать', style: TextStyle(color: kTextMuted, fontSize: 12)),
              const SizedBox(height: 6),
              Row(children: [_genderChip('male', 'Чол'), _genderChip('female', 'Жін')]),
              const SizedBox(height: 10),
              const Text('Ці дані видно тільки Вам', style: TextStyle(color: kTextMuted, fontSize: 11.5)),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: kDangerRed), textAlign: TextAlign.center),
              ],
              if (_success != null) ...[
                const SizedBox(height: 14),
                Text(_success!, style: const TextStyle(color: kAccentBlue), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 22),
              NeuButton(label: 'Зберегти', onTap: _save, loading: _saving),
            ],
          ),
        ),
      ),
    );
  }
}
