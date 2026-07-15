import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/daily_breach.dart';
import '../game/game_controller.dart';
import '../ui/prompt_heist_theme.dart';
import '../ui/widgets.dart';
import 'daily_breach_screen.dart';

class DrillLabScreen extends StatefulWidget {
  const DrillLabScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<DrillLabScreen> createState() => _DrillLabScreenState();
}

class _DrillLabScreenState extends State<DrillLabScreen> {
  BreachDifficulty _difficulty = BreachDifficulty.chill;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _open(DailyBreachDefinition definition) async {
    if (_difficulty == BreachDifficulty.hard &&
        !widget.controller.isHardDrillUnlocked(definition)) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clear CHILL mode to unlock HARD.')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailyBreachScreen.drill(
          controller: widget.controller,
          definition: definition,
          difficulty: _difficulty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hard = _difficulty == BreachDifficulty.hard;
    final accent = hard ? AppColors.danger : AppColors.cyan;
    return Scaffold(
      appBar: AppBar(title: const Text('NOX DRILLS')),
      body: AnimatedGameBackground(
        accent: accent,
        child: SafeArea(
          top: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: GlassPanel(
                    borderColor: accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const NoxAvatar(size: 56),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FIVE-MINUTE HEISTS',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: accent),
                                  ),
                                  Text(
                                    'One weird rule. Several clever exits.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _LabStat(
                              label: 'XP',
                              value: '${widget.controller.drillXp}',
                            ),
                            _LabStat(
                              label: 'ROUTES',
                              value:
                                  '${widget.controller.masteredDrillRoutes}/${widget.controller.totalDrillRoutes}',
                            ),
                            _LabStat(
                              label: 'DRILLS',
                              value: '${DailyBreachCatalog.definitions.length}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<BreachDifficulty>(
                            segments: const [
                              ButtonSegment(
                                value: BreachDifficulty.chill,
                                icon: Icon(Icons.local_cafe_rounded),
                                label: Text('CHILL'),
                              ),
                              ButtonSegment(
                                value: BreachDifficulty.hard,
                                icon: Icon(Icons.local_fire_department_rounded),
                                label: Text('HARD'),
                              ),
                            ],
                            selected: {_difficulty},
                            showSelectedIcon: false,
                            onSelectionChanged: (selection) =>
                                setState(() => _difficulty = selection.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          hard ? 'HARD ROUTE' : 'CHILL ROUTE',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: accent),
                        ),
                      ),
                      Text(
                        hard
                            ? 'EXTRA PROOF · TIGHTER PAR'
                            : 'PLAY AT YOUR OWN PACE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                sliver: SliverList.separated(
                  itemCount: DailyBreachCatalog.definitions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final definition = DailyBreachCatalog.definitions[index];
                    return _DrillCard(
                      number: index + 1,
                      definition: definition,
                      difficulty: _difficulty,
                      progress: widget.controller.drillProgressFor(
                        definition,
                        _difficulty,
                      ),
                      locked:
                          hard &&
                          !widget.controller.isHardDrillUnlocked(definition),
                      onTap: () => _open(definition),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabStat extends StatelessWidget {
  const _LabStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    ),
  );
}

class _DrillCard extends StatelessWidget {
  const _DrillCard({
    required this.number,
    required this.definition,
    required this.difficulty,
    required this.progress,
    required this.locked,
    required this.onTap,
  });

  final int number;
  final DailyBreachDefinition definition;
  final BreachDifficulty difficulty;
  final DrillProgress? progress;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hard = difficulty == BreachDifficulty.hard;
    final accent = locked
        ? AppColors.textMuted
        : hard
        ? AppColors.danger
        : AppColors.cyan;
    final par = definition.parFor(difficulty);
    final best = progress?.bestStrokes;
    final stars = best == null
        ? 0
        : best <= par
        ? 3
        : best <= par + 2
        ? 2
        : 1;
    return Opacity(
      opacity: locked ? .55 : 1,
      child: GlassPanel(
        onTap: onTap,
        borderColor: progress == null ? null : accent,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                shape: BoxShape.circle,
                border: Border.all(color: accent),
              ),
              child: locked
                  ? const Icon(Icons.lock_rounded, size: 18)
                  : Text(
                      '$number',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: accent),
                    ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locked ? 'Clear CHILL to unlock.' : definition.briefing,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    locked
                        ? '${definition.solutionRoutes.length} hidden routes'
                        : '${progress?.routes.length ?? 0}/${definition.solutionRoutes.length} routes · Par $par${best == null ? '' : ' · Best $best'}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: accent),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (stars > 0)
              Text(
                List.filled(stars, '★').join(),
                style: TextStyle(color: accent, fontSize: 11),
              )
            else
              Icon(Icons.chevron_right_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}
