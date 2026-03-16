import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tower_defense/data/repositories/account_progress_repository.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';
import 'package:tower_defense/data/repositories/settings_repository.dart';
import 'package:tower_defense/ui/widgets/panel_button.dart';

class SettingsScreen extends StatefulWidget {
  final WidgetBuilder? debugRankingBuilder;
  final AccountProgress progress;

  const SettingsScreen({
    super.key,
    this.debugRankingBuilder,
    required this.progress,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool musicOn = true;
  bool sfxOn = true;
  bool showDamage = true;
  final SettingsRepository repo = SettingsRepository();
  final AccountProgressRepository progressRepo = AccountProgressRepository();
  late AccountProgress progress;

  @override
  void initState() {
    super.initState();
    progress = widget.progress;
    _load();
  }

  Future<void> _load() async {
    final data = await repo.load();
    if (!mounted) return;
    setState(() {
      musicOn = data.musicOn;
      sfxOn = data.sfxOn;
      showDamage = data.showDamage;
    });
  }

  Future<void> _save() async {
    await repo.save(SettingsData(
      musicOn: musicOn,
      sfxOn: sfxOn,
      showDamage: showDamage,
    ));
  }

  Future<void> _exitScreen() async {
    await _save();
    await progressRepo.save(progress);
    if (!mounted) return;
    Navigator.of(context).pop(progress);
  }

  Future<void> _resetAllLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('account_progress_json');
    await prefs.remove('settings_json');
    await prefs.remove('local_ranking_json');
    await prefs.remove('local_stage_ranking_json');
    await prefs.remove('local_infinite_ranking_json');
    final fresh = await progressRepo.load();
    if (!mounted) return;
    Navigator.of(context).pop(fresh);
  }

  Future<void> _grantAllTowerShards(int amount) async {
    for (final tower in progress.towers.values) {
      tower.shards += amount;
    }
    await progressRepo.save(progress);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _addGold(int amount) async {
    setState(() {
      progress.accountGold += amount;
    });
    await progressRepo.save(progress);
  }

  Future<void> _addTickets(int amount) async {
    setState(() {
      progress.shardDrawTickets += amount;
    });
    await progressRepo.save(progress);
  }

  Future<void> _addDiamonds(int amount) async {
    setState(() {
      progress.diamonds += amount;
    });
    await progressRepo.save(progress);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _exitScreen();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF091321),
        appBar: AppBar(
          title: const Text('설정'),
          backgroundColor: const Color(0xFF0E1A2D),
          foregroundColor: const Color(0xFFF3F7FF),
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF091321), Color(0xFF13233B)],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _settingsTile(
                title: '배경음악',
                value: musicOn,
                onChanged: (v) async {
                  setState(() => musicOn = v);
                  await _save();
                },
              ),
              _settingsTile(
                title: '효과음',
                value: sfxOn,
                onChanged: (v) async {
                  setState(() => sfxOn = v);
                  await _save();
                },
              ),
              _settingsTile(
                title: '데미지 표시',
                value: showDamage,
                onChanged: (v) async {
                  setState(() => showDamage = v);
                  await _save();
                },
              ),
              const SizedBox(height: 12),
              _debugActions(),
              const SizedBox(height: 12),
              AppPanelButton(
                label: '랭킹 샘플 생성(테스트)',
                borderColor: const Color(0xFF83B5FF),
                foregroundColor: const Color(0xFFF3F7FF),
                backgroundColor: const Color(0xCC17304B),
                onPressed: widget.debugRankingBuilder == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: widget.debugRankingBuilder!),
                        );
                      },
              ),
              const SizedBox(height: 12),
              AppPanelButton(
                label: '로비로 돌아가기',
                borderColor: const Color(0xFF83B5FF),
                foregroundColor: const Color(0xFFF3F7FF),
                backgroundColor: const Color(0x99122336),
                onPressed: _exitScreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF83B5FF), width: 1.2),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFFF3F7FF),
            fontWeight: FontWeight.w700,
          ),
        ),
        value: value,
        activeColor: const Color(0xFF5ED0FF),
        inactiveThumbColor: const Color(0xFFB4C7F3),
        inactiveTrackColor: const Color(0xFF304665),
        onChanged: onChanged,
      ),
    );
  }

  Widget _debugActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF83B5FF), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppPanelButton(
                  label: '초기화',
                  borderColor: const Color(0xFF83B5FF),
                  foregroundColor: const Color(0xFFF3F7FF),
                  backgroundColor: const Color(0x99122336),
                  compact: true,
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('데이터 초기화'),
                        content: const Text('로컬 계정/설정/랭킹 데이터를 모두 초기화합니다.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('초기화'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await _resetAllLocalData();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppPanelButton(
                  label: '조각+100',
                  borderColor: const Color(0xFF83B5FF),
                  foregroundColor: const Color(0xFFF3F7FF),
                  backgroundColor: const Color(0xCC17304B),
                  compact: true,
                  onPressed: () => _grantAllTowerShards(100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppPanelButton(
                  label: '골드+500',
                  borderColor: const Color(0xFF83B5FF),
                  foregroundColor: const Color(0xFFF3F7FF),
                  backgroundColor: const Color(0xCC17304B),
                  compact: true,
                  onPressed: () => _addGold(500),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppPanelButton(
                  label: '티켓+100',
                  borderColor: const Color(0xFF83B5FF),
                  foregroundColor: const Color(0xFFF3F7FF),
                  backgroundColor: const Color(0xCC17304B),
                  compact: true,
                  onPressed: () => _addTickets(100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppPanelButton(
            label: '다이아+1000',
            borderColor: const Color(0xFF83B5FF),
            foregroundColor: const Color(0xFFF3F7FF),
            backgroundColor: const Color(0xCC17304B),
            compact: true,
            onPressed: () => _addDiamonds(1000),
          ),
        ],
      ),
    );
  }
}
