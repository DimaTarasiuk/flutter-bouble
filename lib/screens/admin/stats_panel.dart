import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../admin_api_client.dart';
import '../../api_client.dart';
import '../../models_admin.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/neu.dart';

class StatsPanel extends StatefulWidget {
  const StatsPanel({super.key});

  @override
  State<StatsPanel> createState() => _StatsPanelState();
}

class _StatsPanelState extends State<StatsPanel> {
  final _admin = AdminApiClient();
  AdminStats? _stats;
  List<RegistrationPoint> _regs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await _admin.stats();
      List<RegistrationPoint> regs = [];
      try {
        regs = await _admin.registrations(days: 14);
      } catch (_) {}
      if (mounted) setState(() {
        _stats = stats;
        _regs = regs;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: NeuCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(
          children: [
            Text(value, style: AppText.h2),
            const SizedBox(height: 4),
            Text(label, style: AppText.mutedSmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _periodRow(String label, int today, int d7, int d30) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: AppText.bodySmall)),
          Expanded(child: Text('$today', textAlign: TextAlign.center, style: AppText.bodyBold)),
          Expanded(child: Text('$d7', textAlign: TextAlign.center, style: AppText.bodyBold)),
          Expanded(child: Text('$d30', textAlign: TextAlign.center, style: AppText.bodyBold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: AppText.error));
    final s = _stats;
    if (s == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              _statCard('Онлайн', '${s.online}'),
              const SizedBox(width: 10),
              _statCard('DAU', '${s.dau}'),
              const SizedBox(width: 10),
              _statCard('Юзерів', '${s.totalUsers}'),
            ],
          ),
          const SizedBox(height: 18),
          NeuCard(
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Періоди', style: AppText.sectionTitle),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    Expanded(flex: 2, child: SizedBox.shrink()),
                    Expanded(child: Text('Сьогодні', textAlign: TextAlign.center, style: AppText.label)),
                    Expanded(child: Text('7д', textAlign: TextAlign.center, style: AppText.label)),
                    Expanded(child: Text('30д', textAlign: TextAlign.center, style: AppText.label)),
                  ],
                ),
                _periodRow('Реєстрації', s.regToday, s.reg7d, s.reg30d),
                _periodRow('Повідомлення', s.msgToday, s.msg7d, s.msg30d),
              ],
            ),
          ),
          const SizedBox(height: 18),
          NeuCard(
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Онлайн за 24 год', style: AppText.sectionTitle),
                const SizedBox(height: 10),
                SizedBox(
                  height: 140,
                  child: s.onlineChart.length < 2
                      ? const Center(
                          child: Text(
                            'Графік з\'явиться, коли назбираються дані\n(знімок кожні 5 хвилин)',
                            textAlign: TextAlign.center,
                            style: AppText.mutedSmall,
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (int i = 0; i < s.onlineChart.length; i++)
                                    FlSpot(i.toDouble(), s.onlineChart[i].value.toDouble()),
                                ],
                                isCurved: true,
                                color: kAccentBlue,
                                barWidth: 2.5,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(show: true, color: Color(0x226B8FB5)),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          NeuCard(
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Реєстрації за 14 днів', style: AppText.sectionTitle),
                const SizedBox(height: 10),
                SizedBox(
                  height: 140,
                  child: _regs.isEmpty
                      ? const Center(child: Text('Поки немає даних', style: AppText.mutedSmall))
                      : BarChart(
                          BarChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              for (int i = 0; i < _regs.length; i++)
                                BarChartGroupData(x: i, barRods: [
                                  BarChartRodData(
                                    toY: _regs[i].count.toDouble(),
                                    color: kAccentPink,
                                    width: 10,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ]),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          NeuCard(
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Топ юзерів за 7 днів', style: AppText.sectionTitle),
                const SizedBox(height: 10),
                if (s.topUsers7d.isEmpty)
                  const Text('Ще немає повідомлень', style: AppText.mutedSmall)
                else
                  ...s.topUsers7d.take(10).map((u) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(u.username, style: AppText.bodySmall)),
                            Text('${u.messageCount}', style: AppText.bodyBold),
                          ],
                        ),
                      )),
              ],
            ),
          ),
          if (s.recentRegistrations.isNotEmpty) ...[
            const SizedBox(height: 18),
            NeuCard(
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Останні реєстрації', style: AppText.sectionTitle),
                  const SizedBox(height: 10),
                  ...s.recentRegistrations.take(10).map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text((r['username'] ?? '') as String? ?? '',
                                    style: AppText.bodySmall)),
                            Text((r['created_at'] ?? '') as String? ?? '', style: AppText.mutedSmall),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
