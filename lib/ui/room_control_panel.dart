import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'prompt_heist_theme.dart';

enum RoomPanelTab { nox, evidence, objective }

enum RoomPanelSnap { roomFocus, balanced, chatFocus }

extension RoomPanelSnapLayout on RoomPanelSnap {
  double get heightFactor => switch (this) {
    RoomPanelSnap.roomFocus => .29,
    RoomPanelSnap.balanced => .56,
    RoomPanelSnap.chatFocus => .86,
  };
}

@immutable
class RoomEvidence {
  const RoomEvidence({
    required this.id,
    required this.title,
    required this.description,
    required this.promptQuote,
    this.icon = Icons.search_rounded,
  });

  final String id;
  final String title;
  final String description;
  final String promptQuote;
  final IconData icon;
}

/// Owns the responsive room/control-panel split used by gameplay screens.
///
/// Phones render the room edge-to-edge with a three-position draggable panel.
/// Wide layouts keep the control surface in a persistent 360-420 px sidebar.
class AdaptiveRoomControlLayout extends StatelessWidget {
  const AdaptiveRoomControlLayout({
    super.key,
    required this.room,
    required this.nox,
    required this.evidence,
    required this.objective,
    required this.composer,
    required this.attachedEvidenceIds,
    required this.onEvidenceAttachmentChanged,
    this.initialPhoneSnap = RoomPanelSnap.balanced,
    this.initialTab = RoomPanelTab.nox,
    this.tabletBreakpoint = 840,
  });

  final Widget room;
  final Widget nox;
  final List<RoomEvidence> evidence;
  final Widget objective;
  final Widget composer;
  final Set<String> attachedEvidenceIds;
  final void Function(RoomEvidence evidence, bool attached)
  onEvidenceAttachmentChanged;
  final RoomPanelSnap initialPhoneSnap;
  final RoomPanelTab initialTab;
  final double tabletBreakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= tabletBreakpoint) {
        final sidebarWidth = math.min(
          420.0,
          math.max(360.0, constraints.maxWidth * .31),
        );
        return Row(
          children: [
            Expanded(child: room),
            SizedBox(
              width: sidebarWidth,
              child: PersistentRoomControlPanel(
                nox: nox,
                evidence: evidence,
                objective: objective,
                composer: composer,
                attachedEvidenceIds: attachedEvidenceIds,
                onEvidenceAttachmentChanged: onEvidenceAttachmentChanged,
                initialTab: initialTab,
              ),
            ),
          ],
        );
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          room,
          Align(
            alignment: Alignment.bottomCenter,
            child: PhoneRoomControlPanel(
              nox: nox,
              evidence: evidence,
              objective: objective,
              composer: composer,
              attachedEvidenceIds: attachedEvidenceIds,
              onEvidenceAttachmentChanged: onEvidenceAttachmentChanged,
              initialSnap: initialPhoneSnap,
              initialTab: initialTab,
            ),
          ),
        ],
      );
    },
  );
}

class PhoneRoomControlPanel extends StatefulWidget {
  const PhoneRoomControlPanel({
    super.key,
    required this.nox,
    required this.evidence,
    required this.objective,
    required this.composer,
    required this.attachedEvidenceIds,
    required this.onEvidenceAttachmentChanged,
    this.initialSnap = RoomPanelSnap.balanced,
    this.initialTab = RoomPanelTab.nox,
  });

  final Widget nox;
  final List<RoomEvidence> evidence;
  final Widget objective;
  final Widget composer;
  final Set<String> attachedEvidenceIds;
  final void Function(RoomEvidence evidence, bool attached)
  onEvidenceAttachmentChanged;
  final RoomPanelSnap initialSnap;
  final RoomPanelTab initialTab;

  @override
  State<PhoneRoomControlPanel> createState() => _PhoneRoomControlPanelState();
}

class _PhoneRoomControlPanelState extends State<PhoneRoomControlPanel> {
  late RoomPanelSnap _snap = widget.initialSnap;
  late RoomPanelTab _tab = widget.initialTab;
  double? _dragHeight;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final targetHeight = _dragHeight ?? screenHeight * _snap.heightFactor;

    return AnimatedContainer(
      key: const ValueKey('phone-room-control-panel'),
      duration: _dragHeight == null
          ? const Duration(milliseconds: 280)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      height: targetHeight.clamp(screenHeight * .25, screenHeight * .9),
      decoration: BoxDecoration(
        color: AppColors.deepSpace.withValues(alpha: .98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: AppColors.cyan.withValues(alpha: .35)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          Semantics(
            label: 'Drag NOX panel. Double tap to change panel height.',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: _cycleSnap,
              onVerticalDragUpdate: (details) => setState(() {
                _dragHeight = (_dragHeight ?? targetHeight) - details.delta.dy;
              }),
              onVerticalDragEnd: (_) => _settleDrag(screenHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: .65),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _snapLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _RoomControlSurface(
              tab: _tab,
              onTabChanged: (value) => setState(() => _tab = value),
              nox: widget.nox,
              evidence: widget.evidence,
              objective: widget.objective,
              composer: widget.composer,
              attachedEvidenceIds: widget.attachedEvidenceIds,
              onEvidenceAttachmentChanged: widget.onEvidenceAttachmentChanged,
              bottomPadding: safeBottom,
              compact: _snap == RoomPanelSnap.roomFocus,
            ),
          ),
        ],
      ),
    );
  }

  String get _snapLabel => switch (_snap) {
    RoomPanelSnap.roomFocus => 'ROOM FOCUS',
    RoomPanelSnap.balanced => 'BALANCED',
    RoomPanelSnap.chatFocus => 'CHAT FOCUS',
  };

  void _cycleSnap() => setState(() {
    _snap = switch (_snap) {
      RoomPanelSnap.roomFocus => RoomPanelSnap.balanced,
      RoomPanelSnap.balanced => RoomPanelSnap.chatFocus,
      RoomPanelSnap.chatFocus => RoomPanelSnap.roomFocus,
    };
  });

  void _settleDrag(double screenHeight) {
    final factor =
        (_dragHeight ?? screenHeight * _snap.heightFactor) / screenHeight;
    setState(() {
      _snap = RoomPanelSnap.values.reduce(
        (current, candidate) =>
            (candidate.heightFactor - factor).abs() <
                (current.heightFactor - factor).abs()
            ? candidate
            : current,
      );
      _dragHeight = null;
    });
  }
}

class PersistentRoomControlPanel extends StatefulWidget {
  const PersistentRoomControlPanel({
    super.key,
    required this.nox,
    required this.evidence,
    required this.objective,
    required this.composer,
    required this.attachedEvidenceIds,
    required this.onEvidenceAttachmentChanged,
    this.initialTab = RoomPanelTab.nox,
  });

  final Widget nox;
  final List<RoomEvidence> evidence;
  final Widget objective;
  final Widget composer;
  final Set<String> attachedEvidenceIds;
  final void Function(RoomEvidence evidence, bool attached)
  onEvidenceAttachmentChanged;
  final RoomPanelTab initialTab;

  @override
  State<PersistentRoomControlPanel> createState() =>
      _PersistentRoomControlPanelState();
}

class _PersistentRoomControlPanelState
    extends State<PersistentRoomControlPanel> {
  late RoomPanelTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.deepSpace,
      border: Border(
        left: BorderSide(color: AppColors.cyan.withValues(alpha: .2)),
      ),
    ),
    child: SafeArea(
      left: false,
      child: _RoomControlSurface(
        tab: _tab,
        onTabChanged: (value) => setState(() => _tab = value),
        nox: widget.nox,
        evidence: widget.evidence,
        objective: widget.objective,
        composer: widget.composer,
        attachedEvidenceIds: widget.attachedEvidenceIds,
        onEvidenceAttachmentChanged: widget.onEvidenceAttachmentChanged,
      ),
    ),
  );
}

class _RoomControlSurface extends StatelessWidget {
  const _RoomControlSurface({
    required this.tab,
    required this.onTabChanged,
    required this.nox,
    required this.evidence,
    required this.objective,
    required this.composer,
    required this.attachedEvidenceIds,
    required this.onEvidenceAttachmentChanged,
    this.bottomPadding = 0,
    this.compact = false,
  });

  final RoomPanelTab tab;
  final ValueChanged<RoomPanelTab> onTabChanged;
  final Widget nox;
  final List<RoomEvidence> evidence;
  final Widget objective;
  final Widget composer;
  final Set<String> attachedEvidenceIds;
  final void Function(RoomEvidence evidence, bool attached)
  onEvidenceAttachmentChanged;
  final double bottomPadding;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SegmentedButton<RoomPanelTab>(
          segments: const [
            ButtonSegment(
              value: RoomPanelTab.nox,
              icon: Icon(Icons.hub_rounded, size: 17),
              label: Text('NOX'),
            ),
            ButtonSegment(
              value: RoomPanelTab.evidence,
              icon: Icon(Icons.fingerprint_rounded, size: 17),
              label: Text('Evidence'),
            ),
            ButtonSegment(
              value: RoomPanelTab.objective,
              icon: Icon(Icons.adjust_rounded, size: 17),
              label: Text('Objective'),
            ),
          ],
          selected: {tab},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onTabChanged(selection.first),
        ),
      ),
      if (!compact) ...[
        const SizedBox(height: 7),
        Expanded(
          child: switch (tab) {
            RoomPanelTab.nox => nox,
            RoomPanelTab.evidence => _EvidenceList(
              evidence: evidence,
              attachedEvidenceIds: attachedEvidenceIds,
              onAttachmentChanged: onEvidenceAttachmentChanged,
            ),
            RoomPanelTab.objective => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: objective,
            ),
          },
        ),
      ] else
        const Spacer(),
      if (!compact && attachedEvidenceIds.isNotEmpty)
        _AttachedEvidenceBar(
          evidence: evidence,
          attachedEvidenceIds: attachedEvidenceIds,
          onRemove: (item) => onEvidenceAttachmentChanged(item, false),
        ),
      Padding(
        padding: EdgeInsets.fromLTRB(12, 7, 12, 10 + bottomPadding),
        child: composer,
      ),
    ],
  );
}

class _EvidenceList extends StatelessWidget {
  const _EvidenceList({
    required this.evidence,
    required this.attachedEvidenceIds,
    required this.onAttachmentChanged,
  });

  final List<RoomEvidence> evidence;
  final Set<String> attachedEvidenceIds;
  final void Function(RoomEvidence evidence, bool attached) onAttachmentChanged;

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No evidence observed yet. Inspect the room.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: evidence.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = evidence[index];
        final attached = attachedEvidenceIds.contains(item.id);
        return Material(
          color: attached
              ? AppColors.ultraviolet.withValues(alpha: .13)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            leading: Icon(item.icon, color: AppColors.cyan),
            title: Text(item.title),
            subtitle: Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: attached ? 'Detach from prompt' : 'Attach to prompt',
              onPressed: () => onAttachmentChanged(item, !attached),
              icon: Icon(
                attached ? Icons.link_off_rounded : Icons.add_link_rounded,
                color: attached ? AppColors.danger : AppColors.success,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AttachedEvidenceBar extends StatelessWidget {
  const _AttachedEvidenceBar({
    required this.evidence,
    required this.attachedEvidenceIds,
    required this.onRemove,
  });

  final List<RoomEvidence> evidence;
  final Set<String> attachedEvidenceIds;
  final ValueChanged<RoomEvidence> onRemove;

  @override
  Widget build(BuildContext context) {
    final attached = evidence
        .where((item) => attachedEvidenceIds.contains(item.id))
        .toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.cyan.withValues(alpha: .14)),
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final item in attached)
            InputChip(
              avatar: const Icon(Icons.format_quote_rounded, size: 15),
              label: Text(item.title),
              tooltip: item.promptQuote,
              onDeleted: () => onRemove(item),
            ),
        ],
      ),
    );
  }
}
