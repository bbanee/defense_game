import 'package:flutter/material.dart';
import 'package:tower_defense/data/repositories/ranking_repository.dart';
import 'package:tower_defense/ui/widgets/panel_button.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF091321),
      appBar: AppBar(
        title: const Text('랭킹'),
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
        child: FutureBuilder<({List<RankingEntry> stage, List<RankingEntry> infinite})>(
          future: () async {
            final repo = RankingRepository();
            final stage = await repo.loadStage();
            final infinite = await repo.loadInfinite();
            return (stage: stage, infinite: infinite);
          }(),
          builder: (context, snapshot) {
            final stageList = snapshot.data?.stage ?? const [];
            final infiniteList = snapshot.data?.infinite ?? const [];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _rankingTabs(),
                const SizedBox(height: 12),
                Text(
                  _tabIndex == 0 ? '스테이지 랭킹' : '무한모드 랭킹',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF3F7FF),
                  ),
                ),
                const SizedBox(height: 8),
                if (_tabIndex == 0) ...[
                  if (stageList.isEmpty)
                    const Text('기록 없음', style: TextStyle(color: Color(0xFFD9E7FF)))
                  else
                    ...stageList.asMap().entries.map((e) {
                      final index = e.key + 1;
                      final item = e.value;
                      return _rankRow(
                        _RankEntry(
                          rank: index,
                          name: item.name,
                          value: item.score,
                          suffix: '웨이브',
                          detail: item.detail,
                        ),
                      );
                    }).toList(),
                ] else ...[
                  if (infiniteList.isEmpty)
                    const Text('기록 없음', style: TextStyle(color: Color(0xFFD9E7FF)))
                  else
                    ...infiniteList.asMap().entries.map((e) {
                      final index = e.key + 1;
                      final item = e.value;
                      return _rankRow(
                        _RankEntry(
                          rank: index,
                          name: item.name,
                          value: item.score,
                          suffix: '점',
                          detail: item.detail,
                        ),
                      );
                    }).toList(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _rankingTabs() {
    const labels = ['스테이지 랭킹', '무한모드 랭킹'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF83B5FF), width: 1.2),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tabIndex = i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _tabIndex == i ? const Color(0xCC1F3D63) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: _tabIndex == i
                        ? Border.all(color: const Color(0xFF9AC6FF), width: 1.0)
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _tabIndex == i
                          ? const Color(0xFFF4F8FF)
                          : const Color(0xFFB4C7E8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rankRow(_RankEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC142238),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF83B5FF), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('#${entry.rank}  ${entry.name}', style: const TextStyle(color: Color(0xFFF3F7FF))),
          Text(
            entry.detail == null || entry.detail!.isEmpty
                ? '${entry.value}${entry.suffix}'
                : '${entry.value}${entry.suffix} (${entry.detail})',
            style: const TextStyle(
              color: Color(0xFFD9E7FF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingPlaceholder extends StatelessWidget {
  final String title;
  final String body;

  const _RankingPlaceholder({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              color: Color(0xFFF3F7FF),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFD9E7FF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class DebugRankingSeedScreen extends StatelessWidget {
  const DebugRankingSeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF091321),
      appBar: AppBar(
        title: const Text('랭킹 디버그'),
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
            AppPanelButton(
              label: '샘플 랭킹 추가',
              borderColor: const Color(0xFF83B5FF),
              foregroundColor: const Color(0xFFF3F7FF),
              backgroundColor: const Color(0xCC17304B),
              onPressed: () async {
                final repo = RankingRepository();
                await repo.addStageScore('NEON_AEGIS', 182340);
                await repo.addStageScore('CYBER_FALCON', 171220);
                await repo.addStageScore('GRID_HUNTER', 160880);
                await repo.addInfiniteScore('ION_BLADE', 249300);
                await repo.addInfiniteScore('NOVA_CORE', 221050);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RankEntry {
  final int rank;
  final String name;
  final int value;
  final String suffix;
  final String? detail;

  const _RankEntry({
    required this.rank,
    required this.name,
    required this.value,
    required this.suffix,
    this.detail,
  });
}
