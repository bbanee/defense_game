import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tower_defense/data/repositories/account_progress_repository.dart';
import 'package:tower_defense/data/repositories/nickname_repository.dart';
import 'package:tower_defense/data/repositories/ranking_repository.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';
import 'package:tower_defense/data/repositories/settings_repository.dart';
import 'package:tower_defense/shared/audio_service.dart';
import 'package:tower_defense/ui/widgets/panel_button.dart';

class SettingsScreen extends StatefulWidget {
  final WidgetBuilder? debugRankingBuilder;
  final WidgetBuilder loginScreenBuilder;
  final AccountProgress progress;

  const SettingsScreen({
    super.key,
    this.debugRankingBuilder,
    required this.loginScreenBuilder,
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
  final RankingRepository rankingRepo = RankingRepository();
  final NicknameRepository nicknameRepo = NicknameRepository();
  late AccountProgress progress;
  bool _isExiting = false;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    unawaited(AppAudioService.instance.playBgm(AudioBgmTrack.lobby));
    progress = widget.progress;
    _load();
  }

  Future<void> _load() async {
    final data = await repo.load();
    AppAudioService.instance.applySettings(data);
    if (!mounted) return;
    setState(() {
      musicOn = data.musicOn;
      sfxOn = data.sfxOn;
      showDamage = data.showDamage;
    });
  }

  Future<void> _save() async {
    final data = SettingsData(
      musicOn: musicOn,
      sfxOn: sfxOn,
      showDamage: showDamage,
    );
    AppAudioService.instance.applySettings(data);
    await repo.save(data);
  }

  Future<void> _exitScreen() async {
    if (_isExiting) return;
    _isExiting = true;
    final snapshot = progress.copy();
    final navigator = Navigator.of(context);
    unawaited(AppAudioService.instance.stopAllSfx());
    if (navigator.canPop()) {
      navigator.pop(snapshot);
    }
    unawaited(_save());
    unawaited(progressRepo.save(snapshot));
  }

  @override
  void dispose() {
    unawaited(AppAudioService.instance.stopAllSfx());
    super.dispose();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF102033),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF83B5FF), width: 1.4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout_rounded,
                  color: Color(0xFF8FD3FF), size: 30),
              const SizedBox(height: 10),
              const Text(
                '로그아웃',
                style: TextStyle(
                  color: Color(0xFFF3F7FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '현재 계정 세션을 종료하고 로그인 화면으로 돌아갑니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD9E7FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppPanelButton(
                      label: '취소',
                      borderColor: const Color(0xFF83B5FF),
                      foregroundColor: const Color(0xFFF3F7FF),
                      backgroundColor: const Color(0x99122336),
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppPanelButton(
                      label: '로그아웃',
                      borderColor: const Color(0xFF83B5FF),
                      foregroundColor: const Color(0xFFF3F7FF),
                      backgroundColor: const Color(0xCC17304B),
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    unawaited(_save());
    unawaited(progressRepo.save(progress));
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: widget.loginScreenBuilder),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF102033),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFF8A80), width: 1.4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFFF8A80),
                size: 30,
              ),
              const SizedBox(height: 10),
              const Text(
                '계정 삭제',
                style: TextStyle(
                  color: Color(0xFFF3F7FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '현재 계정의 진행도, 설정, 랭킹 기록이 모두 삭제되며 되돌릴 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD9E7FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppPanelButton(
                      label: '취소',
                      borderColor: const Color(0xFF83B5FF),
                      foregroundColor: const Color(0xFFF3F7FF),
                      backgroundColor: const Color(0x99122336),
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppPanelButton(
                      label: '계정 삭제',
                      borderColor: const Color(0xFFFF8A80),
                      foregroundColor: const Color(0xFFFDEDEC),
                      backgroundColor: const Color(0xCC4A1F24),
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isDeletingAccount = true);

    final user = FirebaseAuth.instance.currentUser;
    String? failureMessage;
    try {
      await Future.wait([
        nicknameRepo.releaseCurrentUserNickname(progress.nickname),
        progressRepo.deleteCurrentUserData(),
        rankingRepo.deleteCurrentUserEntries(),
      ]);
      await user?.delete().timeout(const Duration(seconds: 4));
    } on FirebaseAuthException catch (e) {
      failureMessage = e.code == 'requires-recent-login'
          ? '보안을 위해 최근 로그인한 계정만 삭제할 수 있습니다. 다시 로그인한 뒤 시도해 주세요.'
          : '계정 삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.';
    } on TimeoutException {
      failureMessage = '계정 인증 삭제 확인이 지연되고 있습니다. 게임 데이터는 삭제되었으며 로그인 화면으로 이동합니다.';
    } catch (_) {
      failureMessage = '계정 삭제 처리 중 일부 작업이 완료되지 않았을 수 있습니다. 게임 데이터는 초기화되었으며 로그인 화면으로 이동합니다.';
    }

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    if (failureMessage != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF102033),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFC857), width: 1.4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFFC857),
                  size: 28,
                ),
                const SizedBox(height: 10),
                const Text(
                  '삭제 처리 안내',
                  style: TextStyle(
                    color: Color(0xFFF3F7FF),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  failureMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD9E7FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                AppPanelButton(
                  label: '확인',
                  borderColor: const Color(0xFF83B5FF),
                  foregroundColor: const Color(0xFFF3F7FF),
                  backgroundColor: const Color(0xCC17304B),
                  compact: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: widget.loginScreenBuilder),
      (route) => false,
    );
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
        body: Stack(
          children: [
            Container(
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
                      AppAudioService.instance.applySettings(
                        SettingsData(
                          musicOn: musicOn,
                          sfxOn: sfxOn,
                          showDamage: showDamage,
                        ),
                      );
                      if (musicOn) {
                        unawaited(
                            AppAudioService.instance.playBgm(AudioBgmTrack.lobby));
                      } else {
                        unawaited(AppAudioService.instance.stopBgm());
                      }
                      await _save();
                    },
                  ),
                  _settingsTile(
                    title: '효과음',
                    value: sfxOn,
                    onChanged: (v) async {
                      setState(() => sfxOn = v);
                      AppAudioService.instance.applySettings(
                        SettingsData(
                          musicOn: musicOn,
                          sfxOn: sfxOn,
                          showDamage: showDamage,
                        ),
                      );
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
                  AppPanelButton(
                    label: '로그아웃',
                    borderColor: const Color(0xFF83B5FF),
                    foregroundColor: const Color(0xFFF3F7FF),
                    backgroundColor: const Color(0xCC17304B),
                    onPressed: _logout,
                  ),
                  const SizedBox(height: 12),
                  AppPanelButton(
                    label: '계정 삭제',
                    borderColor: const Color(0xFFFF8A80),
                    foregroundColor: const Color(0xFFFDEDEC),
                    backgroundColor: const Color(0xCC4A1F24),
                    onPressed: _deleteAccount,
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
            if (_isDeletingAccount)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF8A80),
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          '계정 삭제 중...',
                          style: TextStyle(
                            color: Color(0xFFF3F7FF),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '잠시만 기다려 주세요.',
                          style: TextStyle(
                            color: Color(0xFFD9E7FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
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

}
