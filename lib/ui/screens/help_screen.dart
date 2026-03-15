import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _HelpSection(
              title: '게임 목표',
              body: '코어 빌딩을 지키며 모든 웨이브를 막아내면 승리합니다.',
            ),
            _HelpSection(
              title: '타워 배치',
              body: '길이 아닌 빈 칸을 터치해 타워를 건설합니다. '
                  '타워 선택 후 건설이 됩니다.',
            ),
            _HelpSection(
              title: '전투 강화',
              body: '전투 중 타워를 강화하거나 매각할 수 있습니다. '
                  '모듈로 공격력/공격속도/사거리를 임시 강화할 수 있습니다.',
            ),
            _HelpSection(
              title: '영구 성장',
              body: '로비의 타워 관리/건물 관리에서 영구 레벨과 코어 성장을 진행합니다.',
            ),
            _HelpSection(
              title: '난이도',
              body: '로비에서 난이도를 선택하면 적 체력/속도/보상이 변합니다.',
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String title;
  final String body;

  const _HelpSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF83B5FF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFFF3F7FF),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFD9E7FF),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
