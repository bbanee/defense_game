import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tower_defense/data/repositories/account_progress_repository.dart';
import 'package:tower_defense/data/repositories/nickname_repository.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';
import 'package:tower_defense/shared/audio_service.dart';
import 'package:tower_defense/ui/screens/lobby_screen.dart';
import 'package:tower_defense/ui/widgets/panel_button.dart';

typedef NicknameGameScreenBuilder = Widget Function({
  required String difficultyId,
  required String stageId,
  required AccountProgress progress,
  required bool showDamage,
  required VoidCallback onExit,
});

class NicknameScreen extends StatefulWidget {
  final NicknameGameScreenBuilder gameScreenBuilder;

  const NicknameScreen({super.key, required this.gameScreenBuilder});

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final AccountProgressRepository _progressRepo = AccountProgressRepository();
  final NicknameRepository _nicknameRepo = NicknameRepository();
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    unawaited(AppAudioService.instance.playBgm(AudioBgmTrack.login));
    _loadNickname();
  }

  @override
  void dispose() {
    unawaited(AppAudioService.instance.stopAllSfx());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadNickname() async {
    final progress = await _progressRepo.load();
    if (!mounted) return;
    final fallbackName =
        FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
    _controller.text =
        progress.nickname.isNotEmpty ? progress.nickname : fallbackName;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    setState(() {});
  }

  Future<void> _submit() async {
    final nickname = _controller.text.trim();
    if (nickname.isEmpty) {
      _showError('닉네임을 입력해 주세요.');
      return;
    }
    if (nickname.length < 2) {
      _showError('닉네임은 2자 이상 입력해 주세요.');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    final progress = await _progressRepo.load();
    final previousNickname = progress.nickname.trim();
    try {
      await _nicknameRepo.reserveNickname(
        nickname: nickname,
        previousNickname: previousNickname,
      );
    } on StateError {
      if (!mounted) return;
      _showError('이미 사용 중인 닉네임입니다.');
      setState(() => _submitting = false);
      return;
    }
    progress.nickname = nickname;
    await _progressRepo.save(progress);
    await FirebaseAuth.instance.currentUser?.updateDisplayName(nickname);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LobbyScreen(
          gameScreenBuilder: widget.gameScreenBuilder,
          initialProgress: progress,
        ),
      ),
    );
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    unawaited(AppAudioService.instance.playError());
    unawaited(AppAudioService.instance.playPopupOpen());
    showDialog<void>(
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
              const Icon(Icons.edit_note_rounded,
                  color: Color(0xFF8FD3FF), size: 30),
              const SizedBox(height: 10),
              const Text(
                '닉네임 확인',
                style: TextStyle(
                  color: Color(0xFFF3F7FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
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
                    Colors.black.withOpacity(0.28),
                    Colors.black.withOpacity(0.58),
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
                  color: const Color(0xC0101B2B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppPanelButton(
                        label: '뒤로가기',
                        icon: Icons.arrow_back_rounded,
                        borderColor: const Color(0xFF83B5FF),
                        foregroundColor: textColor,
                        backgroundColor: const Color(0x99122336),
                        compact: true,
                        onPressed: _goBack,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Icon(
                      Icons.badge_rounded,
                      color: Color(0xFF8FD3FF),
                      size: 44,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '닉네임 설정',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '랭킹과 기록에 표시될 닉네임을 입력하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFD9E7FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _controller,
                      maxLength: 12,
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        counterStyle: const TextStyle(color: Color(0xFFA7BEDB)),
                        hintText: '닉네임 입력',
                        hintStyle: const TextStyle(color: Color(0xFF8EA5C8)),
                        filled: true,
                        fillColor: const Color(0xCC142238),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0x6676B4FF)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0x6676B4FF)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFF83B5FF), width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: AppPanelButton(
                        label: _submitting ? '접속 중...' : '시작하기',
                        icon: Icons.arrow_forward_rounded,
                        borderColor: const Color(0xFF83B5FF),
                        foregroundColor: textColor,
                        backgroundColor: const Color(0xCC17304B),
                        onPressed: _submitting ? null : _submit,
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
