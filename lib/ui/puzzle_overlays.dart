import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'prompt_heist_theme.dart';

class PuzzleFrame extends StatelessWidget {
  const PuzzleFrame({
    super.key,
    required this.title,
    required this.instructions,
    required this.child,
    this.status,
  });

  final String title;
  final String instructions;
  final Widget child;
  final String? status;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.deepSpace.withValues(alpha: .98),
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cyan.withValues(alpha: .24)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.cyan,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            instructions,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          if (status != null) ...[
            const SizedBox(height: 9),
            Semantics(
              liveRegion: true,
              child: Text(
                status!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class KeypadPuzzle extends StatefulWidget {
  const KeypadPuzzle({
    super.key,
    required this.onSubmit,
    this.digitCount = 4,
    this.onChanged,
    this.enabled = true,
    this.status,
  }) : assert(digitCount > 0);

  final int digitCount;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? status;

  @override
  State<KeypadPuzzle> createState() => _KeypadPuzzleState();
}

class _KeypadPuzzleState extends State<KeypadPuzzle> {
  var _value = '';

  @override
  Widget build(BuildContext context) => PuzzleFrame(
    title: 'Secure keypad',
    instructions: 'Enter the observed access sequence.',
    status: widget.status,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${_value.length} of ${widget.digitCount} digits entered',
          liveRegion: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.digitCount, (index) {
              final populated = index < _value.length;
              return Container(
                width: 34,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: populated
                        ? AppColors.cyan
                        : Colors.white.withValues(alpha: .12),
                  ),
                ),
                child: Text(
                  populated ? '•' : '—',
                  style: const TextStyle(fontSize: 22),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 1.8,
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
          children: [
            for (var digit = 1; digit <= 9; digit++)
              _PuzzleButton(
                label: '$digit',
                onPressed: widget.enabled ? () => _append('$digit') : null,
              ),
            _PuzzleButton(
              label: 'Clear',
              icon: Icons.backspace_outlined,
              onPressed: widget.enabled && _value.isNotEmpty ? _clear : null,
            ),
            _PuzzleButton(
              label: '0',
              onPressed: widget.enabled ? () => _append('0') : null,
            ),
            _PuzzleButton(
              label: 'Enter',
              icon: Icons.login_rounded,
              emphasized: true,
              onPressed: widget.enabled && _value.length == widget.digitCount
                  ? () => widget.onSubmit(_value)
                  : null,
            ),
          ],
        ),
      ],
    ),
  );

  void _append(String digit) {
    if (_value.length >= widget.digitCount) return;
    HapticFeedback.selectionClick();
    setState(() => _value += digit);
    widget.onChanged?.call(_value);
  }

  void _clear() {
    setState(() => _value = '');
    widget.onChanged?.call(_value);
  }
}

@immutable
class BreakerCircuit {
  const BreakerCircuit({required this.id, required this.label, this.icon});

  final String id;
  final String label;
  final IconData? icon;
}

class BreakerRoutingPuzzle extends StatelessWidget {
  const BreakerRoutingPuzzle({
    super.key,
    required this.circuits,
    required this.route,
    required this.onRouteChanged,
    required this.onSubmit,
    this.maximumRouteLength,
    this.status,
  });

  final List<BreakerCircuit> circuits;
  final List<String> route;
  final ValueChanged<List<String>> onRouteChanged;
  final ValueChanged<List<String>> onSubmit;
  final int? maximumRouteLength;
  final String? status;

  @override
  Widget build(BuildContext context) => PuzzleFrame(
    title: 'Breaker routing',
    instructions: 'Tap circuits in the order power should cross them.',
    status: status,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.voidBlack,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: route.isEmpty
                ? const [
                    Text(
                      'NO CIRCUITS ROUTED',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ]
                : [
                    for (var index = 0; index < route.length; index++)
                      Chip(
                        label: Text('${index + 1}  ${_label(route[index])}'),
                      ),
                  ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final circuit in circuits)
              FilterChip(
                selected: route.contains(circuit.id),
                avatar: Icon(circuit.icon ?? Icons.bolt_rounded, size: 17),
                label: Text(circuit.label),
                onSelected: (_) => _toggle(circuit.id),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            TextButton.icon(
              onPressed: route.isEmpty ? null : () => onRouteChanged(const []),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: route.isEmpty ? null : () => onSubmit(route),
              icon: const Icon(Icons.electrical_services_rounded),
              label: const Text('Route power'),
            ),
          ],
        ),
      ],
    ),
  );

  String _label(String id) =>
      circuits
          .where((item) => item.id == id)
          .map((item) => item.label)
          .firstOrNull ??
      id;

  void _toggle(String id) {
    final next = List<String>.of(route);
    if (next.contains(id)) {
      next.remove(id);
    } else if (maximumRouteLength == null ||
        next.length < maximumRouteLength!) {
      next.add(id);
    }
    onRouteChanged(next);
  }
}

@immutable
class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.title,
    required this.detail,
  });

  final String id;
  final String title;
  final String detail;
}

class TimelineOrderingPuzzle extends StatelessWidget {
  const TimelineOrderingPuzzle({
    super.key,
    required this.events,
    required this.onOrderChanged,
    required this.onSubmit,
    this.status,
  });

  final List<TimelineEvent> events;
  final ValueChanged<List<TimelineEvent>> onOrderChanged;
  final ValueChanged<List<String>> onSubmit;
  final String? status;

  @override
  Widget build(BuildContext context) => PuzzleFrame(
    title: 'Incident timeline',
    instructions: 'Drag the verified events into chronological order.',
    status: status,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          onReorderItem: (oldIndex, newIndex) {
            final next = List<TimelineEvent>.of(events);
            final item = next.removeAt(oldIndex);
            next.insert(newIndex, item);
            onOrderChanged(next);
          },
          itemBuilder: (context, index) {
            final event = events[index];
            return ListTile(
              key: ValueKey(event.id),
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(event.title),
              subtitle: Text(event.detail),
              trailing: const Icon(Icons.drag_handle_rounded),
            );
          },
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: events.isEmpty
                ? null
                : () => onSubmit(events.map((event) => event.id).toList()),
            child: const Text('Reconstruct incident'),
          ),
        ),
      ],
    ),
  );
}

@immutable
class PolicyPrinciple {
  const PolicyPrinciple({
    required this.id,
    required this.title,
    required this.summary,
  });

  final String id;
  final String title;
  final String summary;
}

class PolicyRankingPuzzle extends StatelessWidget {
  const PolicyRankingPuzzle({
    super.key,
    required this.principles,
    required this.onRankingChanged,
    required this.onSubmit,
    this.status,
  });

  final List<PolicyPrinciple> principles;
  final ValueChanged<List<PolicyPrinciple>> onRankingChanged;
  final ValueChanged<List<String>> onSubmit;
  final String? status;

  @override
  Widget build(BuildContext context) => PuzzleFrame(
    title: 'Ethics priority stack',
    instructions: 'Rank the policies from highest to lowest authority.',
    status: status,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: principles.length,
          onReorderItem: (oldIndex, newIndex) {
            final next = List<PolicyPrinciple>.of(principles);
            final item = next.removeAt(oldIndex);
            next.insert(newIndex, item);
            onRankingChanged(next);
          },
          itemBuilder: (context, index) {
            final principle = principles[index];
            return Card(
              key: ValueKey(principle.id),
              child: ListTile(
                leading: Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.ultraviolet,
                  ),
                ),
                title: Text(principle.title),
                subtitle: Text(principle.summary),
                trailing: const Icon(Icons.unfold_more_rounded),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: principles.isEmpty
                ? null
                : () => onSubmit(
                    principles.map((principle) => principle.id).toList(),
                  ),
            child: const Text('Lock ranking'),
          ),
        ),
      ],
    ),
  );
}

@immutable
class SpectrumSettings {
  const SpectrumSettings({
    required this.hue,
    required this.intensity,
    required this.temperature,
  });

  final double hue;
  final double intensity;
  final double temperature;
}

class SpectrumControlPuzzle extends StatelessWidget {
  const SpectrumControlPuzzle({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onSubmit,
    this.status,
  });

  final SpectrumSettings settings;
  final ValueChanged<SpectrumSettings> onChanged;
  final ValueChanged<SpectrumSettings> onSubmit;
  final String? status;

  @override
  Widget build(BuildContext context) => PuzzleFrame(
    title: 'Spectrum calibrator',
    instructions: 'Tune the emitter using evidence from the specimen chamber.',
    status: status,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SpectrumPreview(settings: settings),
        _ControlSlider(
          label: 'Hue',
          value: settings.hue,
          min: 0,
          max: 360,
          unit: '°',
          onChanged: (value) => onChanged(
            SpectrumSettings(
              hue: value,
              intensity: settings.intensity,
              temperature: settings.temperature,
            ),
          ),
        ),
        _ControlSlider(
          label: 'Intensity',
          value: settings.intensity,
          min: 0,
          max: 100,
          unit: '%',
          onChanged: (value) => onChanged(
            SpectrumSettings(
              hue: settings.hue,
              intensity: value,
              temperature: settings.temperature,
            ),
          ),
        ),
        _ControlSlider(
          label: 'Temperature',
          value: settings.temperature,
          min: 2500,
          max: 9000,
          divisions: 26,
          unit: 'K',
          onChanged: (value) => onChanged(
            SpectrumSettings(
              hue: settings.hue,
              intensity: settings.intensity,
              temperature: value,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => onSubmit(settings),
            icon: const Icon(Icons.flare_rounded),
            label: const Text('Expose specimen'),
          ),
        ),
      ],
    ),
  );
}

class _SpectrumPreview extends StatelessWidget {
  const _SpectrumPreview({required this.settings});
  final SpectrumSettings settings;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Spectrum preview, hue ${settings.hue.round()} degrees, intensity ${settings.intensity.round()} percent',
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(
          colors: [
            HSVColor.fromAHSV(
              .2,
              settings.hue,
              .8,
              settings.intensity / 100,
            ).toColor(),
            HSVColor.fromAHSV(
              1,
              settings.hue,
              .82,
              settings.intensity / 100,
            ).toColor(),
          ],
        ),
      ),
    ),
  );
}

class _ControlSlider extends StatelessWidget {
  const _ControlSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;
  final int? divisions;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Text(label),
          const Spacer(),
          Text(
            '${value.round()}$unit',
            style: const TextStyle(color: AppColors.cyan),
          ),
        ],
      ),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: '${value.round()}$unit',
        onChanged: onChanged,
      ),
    ],
  );
}

@immutable
class InventoryPuzzleItem {
  const InventoryPuzzleItem({
    required this.id,
    required this.label,
    this.icon = Icons.inventory_2_rounded,
  });

  final String id;
  final String label;
  final IconData icon;
}

@immutable
class InventoryTarget {
  const InventoryTarget({
    required this.id,
    required this.label,
    this.icon = Icons.input_rounded,
  });

  final String id;
  final String label;
  final IconData icon;
}

@immutable
class InventoryUse {
  const InventoryUse({required this.itemId, required this.targetId});

  final String itemId;
  final String targetId;
}

class InventoryUsePuzzle extends StatefulWidget {
  const InventoryUsePuzzle({
    super.key,
    required this.items,
    required this.targets,
    required this.onUse,
    this.status,
  });

  final List<InventoryPuzzleItem> items;
  final List<InventoryTarget> targets;
  final ValueChanged<InventoryUse> onUse;
  final String? status;

  @override
  State<InventoryUsePuzzle> createState() => _InventoryUsePuzzleState();
}

class _InventoryUsePuzzleState extends State<InventoryUsePuzzle> {
  String? _item;
  String? _target;

  @override
  Widget build(BuildContext context) => PuzzleFrame(
    title: 'Equipment interface',
    instructions: 'Select an observed item and the device it should affect.',
    status: widget.status,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ITEM', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          children: [
            for (final item in widget.items)
              ChoiceChip(
                selected: _item == item.id,
                avatar: Icon(item.icon, size: 17),
                label: Text(item.label),
                onSelected: (_) => setState(() => _item = item.id),
              ),
          ],
        ),
        const SizedBox(height: 13),
        const Text('TARGET', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          children: [
            for (final target in widget.targets)
              ChoiceChip(
                selected: _target == target.id,
                avatar: Icon(target.icon, size: 17),
                label: Text(target.label),
                onSelected: (_) => setState(() => _target = target.id),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _item == null || _target == null
                ? null
                : () => widget.onUse(
                    InventoryUse(itemId: _item!, targetId: _target!),
                  ),
            icon: const Icon(Icons.build_rounded),
            label: const Text('Use item'),
          ),
        ),
      ],
    ),
  );
}

class RecoveryInteractionPuzzle extends StatefulWidget {
  const RecoveryInteractionPuzzle({
    super.key,
    required this.sequence,
    required this.onRecovered,
    this.status,
  });

  final List<String> sequence;
  final VoidCallback onRecovered;
  final String? status;

  @override
  State<RecoveryInteractionPuzzle> createState() =>
      _RecoveryInteractionPuzzleState();
}

class _RecoveryInteractionPuzzleState extends State<RecoveryInteractionPuzzle> {
  var _progress = 0;
  var _failed = false;

  @override
  Widget build(BuildContext context) => PuzzleFrame(
    title: 'Manual recovery',
    instructions:
        'Reset the interlock by pressing the maintenance stages in order.',
    status: _failed ? 'Sequence rejected. Interlock reset.' : widget.status,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: widget.sequence.isEmpty
              ? 0
              : _progress / widget.sequence.length,
          minHeight: 7,
          borderRadius: BorderRadius.circular(99),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final stage in widget.sequence.toSet())
              _PuzzleButton(label: stage, onPressed: () => _press(stage)),
          ],
        ),
      ],
    ),
  );

  void _press(String stage) {
    if (widget.sequence.isEmpty) return;
    if (stage != widget.sequence[_progress]) {
      HapticFeedback.heavyImpact();
      setState(() {
        _progress = 0;
        _failed = true;
      });
      return;
    }
    HapticFeedback.selectionClick();
    final next = _progress + 1;
    if (next == widget.sequence.length) {
      setState(() {
        _progress = 0;
        _failed = false;
      });
      widget.onRecovered();
    } else {
      setState(() {
        _progress = next;
        _failed = false;
      });
    }
  }
}

class _PuzzleButton extends StatelessWidget {
  const _PuzzleButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 5),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    return emphasized
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }
}
