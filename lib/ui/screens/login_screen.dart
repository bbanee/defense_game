import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:tower_defense/data/repositories/account_progress_repository.dart';
import 'package:tower_defense/data/repositories/live_ops_repository.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tower_defense/shared/audio_service.dart';
import 'package:tower_defense/ui/screens/nickname_screen.dart';
import 'package:tower_defense/ui/screens/lobby_screen.dart';
import 'package:tower_defense/ui/widgets/panel_button.dart';

typedef LoginGameScreenBuilder = Widget Function({
  required String difficultyId,
  required String stageId,
  required AccountProgress progress,
  required bool showDamage,
  required VoidCallback onExit,
});

class LoginScreen extends StatefulWidget {
  final LoginGameScreenBuilder gameScreenBuilder;

  const LoginScreen({super.key, required this.gameScreenBuilder});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AccountProgressRepository _progressRepo = AccountProgressRepository();
  final LiveOpsRepository _liveOpsRepo = LiveOpsRepository();
  bool _openingLobby = false;
  bool _googleInitialized = false;
  bool _maintenanceEnabled = false;
  String _maintenanceMessage = '';
  String? _announcementTitle;
  String? _announcementBody;

  @override
  void initState() {
    super.initState();
    unawaited(AppAudioService.instance.playBgm(AudioBgmTrack.login));
    unawaited(_bootstrapAuthState());
  }

  @override
  void dispose() {
    unawaited(AppAudioService.instance.stopAllSfx());
    super.dispose();
  }

  Future<void> _bootstrapAuthState() async {
    await _loadLiveOps();
    if (!mounted) return;
    if (FirebaseAuth.instance.currentUser != null) {
      final progress = await _progressRepo.load();
      if (!mounted) return;
      if (progress.nickname.trim().isNotEmpty) {
        await _goToNextStep();
      }
    }
  }

  Future<void> _loadLiveOps() async {
    final config = await _liveOpsRepo.loadConfig();
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    if (!mounted) return;
    setState(() {
      _maintenanceEnabled =
          config.maintenanceEnabled || currentBuild < config.minBuildNumber;
      _maintenanceMessage = config.maintenanceEnabled
          ? config.maintenanceMessage
          : '새 버전으로 업데이트 후 접속해 주세요.';
      _announcementTitle = config.announcementTitle.trim().isEmpty
          ? null
          : config.announcementTitle.trim();
      _announcementBody = config.announcementBody.trim().isEmpty
          ? null
          : config.announcementBody.trim();
    });
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  Future<void> _enterLobby(String mode) async {
    if (_maintenanceEnabled) {
      await _showErrorDialog(
        title: '점검 중',
        body: _maintenanceMessage.isEmpty ? '현재 점검 중입니다.' : _maintenanceMessage,
      );
      return;
    }
    if (_openingLobby) return;
    setState(() => _openingLobby = true);
    try {
      if (mode == 'guest') {
        await FirebaseAuth.instance.signInAnonymously();
      } else {
        await _ensureGoogleInitialized();
        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;
        if (googleAuth.idToken == null) {
          throw FirebaseAuthException(
            code: 'google-auth-missing-token',
            message: 'Google 인증 토큰을 가져오지 못했습니다.',
          );
        }
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      if (!mounted) return;
      await _goToNextStep();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      await _showErrorDialog(
        title: '로그인 실패',
        body: e.message ?? '로그인 처리 중 오류가 발생했습니다.',
      );
      setState(() => _openingLobby = false);
    } catch (_) {
      if (!mounted) return;
      await _showErrorDialog(
        title: '로그인 실패',
        body: '로그인 처리 중 오류가 발생했습니다.',
      );
      setState(() => _openingLobby = false);
    }
  }

  Future<void> _goToNextStep() async {
    if (!mounted) return;
    final progress = await _progressRepo.load();
    if (!mounted) return;
    if (progress.nickname.trim().isNotEmpty) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            gameScreenBuilder: widget.gameScreenBuilder,
            initialProgress: progress,
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => NicknameScreen(
          gameScreenBuilder: widget.gameScreenBuilder,
        ),
      ),
    );
  }

  Future<void> _showErrorDialog({
    required String title,
    required String body,
  }) async {
    unawaited(AppAudioService.instance.playError());
    unawaited(AppAudioService.instance.playPopupOpen());
    await showDialog<void>(
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
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFF8FD3FF), size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF3F7FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD9E7FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF8CB8FF);
    const buttonFill = Color(0xCC16304D);
    const panelFill = Color(0xC0101B2B);
    const textColor = Color(0xFFF3F7FF);

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/UI/main.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Color(0xFF07111F)),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Container(
                width: 360,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                decoration: BoxDecoration(
                  color: panelFill,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF65D1FF),
                          width: 1.6,
                        ),
                        gradient: const RadialGradient(
                          colors: [
                            Color(0xFF17304B),
                            Color(0xFF0C1524),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF8FD3FF),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SF\n타워 디펜스',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '방어망에 접속할 방식을 선택하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFD9E7FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_announcementTitle != null &&
                        _announcementBody != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xB3122136),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0x6676B4FF),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _announcementTitle!,
                              style: const TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _announcementBody!,
                              style: const TextStyle(
                                color: Color(0xFFD9E7FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xB3122136),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0x6676B4FF),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: _GoogleLoginButton(
                              onPressed: _openingLobby
                                  ? null
                                  : () => _enterLobby('google'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: AppPanelButton(
                              label: _openingLobby ? '연결 중...' : 'Guest Login',
                              icon: Icons.person_outline_rounded,
                              borderColor: borderColor,
                              foregroundColor: textColor,
                              backgroundColor: buttonFill,
                              onPressed: _openingLobby
                                  ? null
                                  : () => _enterLobby('guest'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xAA2B1D24),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0x66FF9BA5),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFFFB4BE),
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '게스트 로그인은 계정 연동이 불가능하며, 기기 변경 또는 앱 삭제 시 데이터가 사라질 수 있습니다.',
                                    style: TextStyle(
                                      color: Color(0xFFFFD7DC),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '로그인 방식은 추후 계정 연동 및 기록 보존에 사용됩니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFA7BEDB),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleLoginButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _GoogleLoginButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed == null
          ? null
          : () {
              unawaited(AppAudioService.instance.playUiClick());
              onPressed?.call();
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 4.2,
          child: Image.asset(
            'assets/images/UI/google_g_logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
