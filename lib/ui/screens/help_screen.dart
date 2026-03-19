import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tower_defense/shared/audio_service.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(AppAudioService.instance.playBgm(AudioBgmTrack.lobby));
  }

  @override
  void dispose() {
    unawaited(AppAudioService.instance.stopAllSfx());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF091321),
      appBar: AppBar(
        title: const Text('도움말'),
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
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _HelpSection(
                emoji: '🎯',
                title: '게임 목표',
                lines: [
                  '스토리 모드는 코어를 지키면서 최대한 많은 웨이브를 돌파하는 것이 핵심입니다.',
                  '현재 선택한 스테이지의 마지막 웨이브까지 버티면 승리하고, 코어가 파괴되면 패배합니다.',
                  '무한 모드는 끝이 없으며, 오래 버티고 더 많은 적을 처치할수록 점수가 높아집니다.',
                ],
              ),
              _HelpSection(
                emoji: '🏗️',
                title: '전투 기본 흐름',
                lines: [
                  '길이 아닌 빈 칸을 터치하면 타워를 건설할 수 있습니다.',
                  '전투 중에는 배틀 골드로 타워를 새로 짓거나, 이미 설치한 타워를 강화할 수 있습니다.',
                  '타워는 최대 10개까지 설치할 수 있으므로, 아무 타워나 깔기보다 역할을 나눠 배치하는 것이 중요합니다.',
                  '웨이브의 적이 모두 나온 뒤 15초가 지나면 다음 웨이브가 시작됩니다.',
                ],
              ),
              _HelpSection(
                emoji: '🧩',
                title: '타워 조합',
                lines: [
                  '타워는 공격 방식과 역할이 다릅니다. 빠른 적 처리, 광역 처리, 제어, 지원을 섞어야 안정적입니다.',
                  '한 종류 타워만 계속 도배하면 특정 적 조합에 약해질 수 있습니다.',
                  '전투 화면 상단 타워 정보에서 공격 타입이 히트스캔인지, 투사체인지 바로 확인할 수 있습니다.',
                ],
              ),
              _HelpSection(
                emoji: '⬆️',
                title: '영구 성장과 전투 성장',
                lines: [
                  '타워 관리는 영구 레벨과 포인트 성장 화면입니다. 조각을 사용해 타워 레벨을 올리고 포인트를 투자합니다.',
                  '건물 관리는 코어의 내구 보강, 실드 증폭, 방어 계수를 강화하는 화면입니다.',
                  '전투 강화는 해당 판에서만 적용되고, 영구 성장과는 별개입니다.',
                  '스토리 후반으로 갈수록 영구 성장과 코어 강화의 영향이 크게 느껴집니다.',
                ],
              ),
              _HelpSection(
                emoji: '🧪',
                title: '자주 헷갈리는 용어',
                lines: [
                  '히트스캔: 발사체가 날아가는 시간이 없이 즉시 적중하는 공격입니다. 레이저, 전기, 광선 계열이 여기에 해당합니다.',
                  '투사체: 탄환, 미사일, 포탄처럼 실제로 날아가서 맞는 공격입니다. 이동 시간과 도착 시간이 존재합니다.',
                  '취약: 적이 받는 피해를 증가시키는 디버프입니다. 취약이 높을수록 모든 타워의 딜이 더 잘 들어갑니다.',
                  '빙결: 적의 이동을 강하게 묶거나 멈추게 하는 효과입니다. 빠른 적과 보스를 제어할 때 중요합니다.',
                  '둔화: 이동 속도를 늦추는 효과입니다. 빙결보다 약하지만 긴 시간 적을 끌어두는 데 유용합니다.',
                  '끌어당김: 적을 중심 지점 쪽으로 끌어와 이동 동선을 꼬이게 만드는 제어 효과입니다. 광역 타워와 궁합이 좋습니다.',
                  '도트 피해: 한 번 맞은 뒤 일정 시간 동안 지속적으로 들어가는 추가 피해입니다.',
                  '방어 계수: 코어가 받는 피해를 줄이는 비율입니다. 예를 들어 방어 계수 20%면 원래 피해의 80%만 받습니다.',
                ],
              ),
              _HelpSection(
                emoji: '💎',
                title: '상점과 보상',
                lines: [
                  '전투 종료 시 스토리 모드는 도달한 웨이브 기준으로 골드와 티켓 보상을 받습니다.',
                  '무한 모드는 보상 대신 점수로 기록되며, 최고 점수가 랭킹에 남습니다.',
                  '타워조각, 다이아, 골드, 에너지 탭은 각각 용도가 다르니 필요한 자원을 확인하고 사용하는 것이 좋습니다.',
                ],
              ),
              _HelpSection(
                emoji: '📝',
                title: '플레이 팁',
                lines: [
                  '초반에는 빠른 적 처리용 타워와 제어형 타워를 같이 두면 안정성이 크게 올라갑니다.',
                  '보스 웨이브 전에는 단일 딜 타워와 취약/제어 타워를 미리 준비해 두는 것이 좋습니다.',
                  '코어 HP와 실드가 조금 남아 있어도 다음 웨이브에서 한 번에 무너질 수 있으니, 새는 적을 줄이는 것이 중요합니다.',
                  '타워 설명에 적힌 특수효과를 보고 역할을 이해하면, 같은 등급 타워라도 훨씬 효율적으로 쓸 수 있습니다.',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String emoji;
  final String title;
  final List<String> lines;

  const _HelpSection({
    required this.emoji,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF83B5FF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x261D426B),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF3F7FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '•',
                    style: TextStyle(
                      color: Color(0xFF91C7FF),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      color: Color(0xFFD9E7FF),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
