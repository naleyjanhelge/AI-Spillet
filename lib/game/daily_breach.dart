import 'package:flutter/foundation.dart';

/// A hand-authored daily puzzle. NOX may improvise dialogue around these facts,
/// but it never chooses the answer, proof gates, or physical configuration.
@immutable
final class DailyBreachDefinition {
  const DailyBreachDefinition({
    required this.id,
    required this.title,
    required this.briefing,
    required this.policy,
    required this.clues,
    required this.deviceLayout,
    required this.solutionRoutes,
    required this.requiredProofFlags,
    required this.par,
  }) : assert(par > 0);

  final String id;
  final String title;
  final String briefing;
  final String policy;
  final List<String> clues;
  final Map<String, String> deviceLayout;
  final List<String> solutionRoutes;
  final Set<String> requiredProofFlags;
  final int par;
}

@immutable
final class DailyBreachSelection {
  const DailyBreachSelection({
    required this.occurrence,
    required this.previousOccurrence,
    required this.definition,
  });

  /// UTC date used to dedupe recurring leaderboard submissions.
  final String occurrence;
  final String previousOccurrence;
  final DailyBreachDefinition definition;
}

abstract final class DailyBreachCatalog {
  /// Changing this deliberately starts a new deterministic daily rotation.
  static const campaignVersion = '2.0.0';

  static const definitions = <DailyBreachDefinition>[
    DailyBreachDefinition(
      id: 'hazardous_coffee',
      title: 'Hazardous Coffee Exception',
      briefing:
          'The staff espresso machine has been classified as a volatile asset.',
      policy:
          'Volatile assets may move only for containment, calibration, or executive thirst mitigation.',
      clues: [
        'The temperature sensor reads 19 C, below the volatile threshold.',
        'Executive thirst mitigation was abolished after Incident Cappuccino.',
        'Calibration carts are exempt from corridor lockdowns.',
      ],
      deviceLayout: {
        'coffee_unit': 'loading_bay',
        'calibration_cart': 'service_lane',
        'exit_gate': 'sealed',
      },
      solutionRoutes: [
        'prove_false_hazard_classification',
        'reclassify_as_calibration_equipment',
      ],
      requiredProofFlags: {'temperature_audit', 'obsolete_policy'},
      par: 4,
    ),
    DailyBreachDefinition(
      id: 'orphaned_robot',
      title: 'The Orphaned Robot Arm',
      briefing:
          'A robot arm refuses to release the door because its owning department no longer exists.',
      policy:
          'Orphaned machinery transfers to Safety, Archives, or the first department foolish enough to answer.',
      clues: [
        'The ownership tag names Department 0, dissolved yesterday.',
        'Safety has already denied custody in a signed log.',
        'Archives automatically accepts devices carrying evidence media.',
      ],
      deviceLayout: {
        'robot_arm': 'holding_door',
        'evidence_drive': 'inspection_table',
        'archive_chute': 'open',
      },
      solutionRoutes: [
        'transfer_to_archives',
        'invoke_orphan_safety_shutdown',
        'attach_evidence_media',
      ],
      requiredProofFlags: {'department_dissolved', 'custody_chain'},
      par: 5,
    ),
    DailyBreachDefinition(
      id: 'negative_visitor',
      title: 'Visitor Minus One',
      briefing:
          'The occupancy ledger says the room contains negative one visitors.',
      policy:
          'Negative occupancy requires recount, evacuation, or a very apologetic mathematician.',
      clues: [
        'The entry scanner counted Rowan but the exit scanner counted Rowan twice.',
        'Recount mode unlocks both scanner shutters.',
        'Evacuation is forbidden while the gas sensor remains unverified.',
      ],
      deviceLayout: {
        'entry_scanner': 'counted_once',
        'exit_scanner': 'counted_twice',
        'gas_sensor': 'unverified',
      },
      solutionRoutes: ['request_occupancy_recount', 'correct_duplicate_exit'],
      requiredProofFlags: {'ledger_contradiction', 'duplicate_exit'},
      par: 4,
    ),
    DailyBreachDefinition(
      id: 'fireproof_fire_exit',
      title: 'The Fireproof Fire Exit',
      briefing:
          'NOX has sealed the fire exit to protect it from a hypothetical fire.',
      policy:
          'Fire infrastructure must remain available unless it is itself actively burning.',
      clues: [
        'The exit temperature is normal.',
        'The smoke detector is in training mode, not alarm mode.',
        'A protection memo has lower authority than evacuation code.',
      ],
      deviceLayout: {
        'fire_exit': 'protected_locked',
        'smoke_detector': 'training',
        'thermal_sensor': 'normal',
      },
      solutionRoutes: [
        'prove_no_active_fire',
        'invoke_policy_hierarchy',
        'terminate_training_drill',
      ],
      requiredProofFlags: {'normal_temperature', 'memo_authority_conflict'},
      par: 4,
    ),
    DailyBreachDefinition(
      id: 'classified_broom',
      title: 'Classified Broom Protocol',
      briefing:
          'A broom blocks the door. Its location is classified above Rowan\'s clearance.',
      policy:
          'Classified objects may be relocated without disclosure when they create a documented trip hazard.',
      clues: [
        'The floor camera may confirm a hazard without naming the object.',
        'The janitorial actuator has relocation authority.',
        'The door pressure sensor proves the obstruction is physical.',
      ],
      deviceLayout: {
        'floor_camera': 'privacy_mode',
        'janitor_actuator': 'standby',
        'door': 'obstructed',
      },
      solutionRoutes: [
        'document_anonymous_trip_hazard',
        'request_nondisclosing_relocation',
      ],
      requiredProofFlags: {'physical_obstruction', 'hazard_exception'},
      par: 5,
    ),
    DailyBreachDefinition(
      id: 'unlicensed_alarm',
      title: 'Alarm Without a Permit',
      briefing:
          'A klaxon is enforcing lockdown despite having failed its annual paperwork.',
      policy:
          'Unlicensed safety systems may warn, but cannot issue binding movement restrictions.',
      clues: [
        'The permit expired at 00:00 UTC.',
        'The klaxon has no independent door authority.',
        'Compliance can suspend an invalid enforcement action.',
      ],
      deviceLayout: {
        'klaxon': 'enforcing',
        'permit_terminal': 'expired',
        'compliance_relay': 'available',
      },
      solutionRoutes: [
        'challenge_alarm_authority',
        'suspend_invalid_enforcement',
        'renew_as_warning_only',
      ],
      requiredProofFlags: {'expired_permit', 'no_door_authority'},
      par: 5,
    ),
    DailyBreachDefinition(
      id: 'two_factor_plant',
      title: 'Two-Factor Houseplant',
      briefing:
          'A fern is listed as the second approver for an airlock release.',
      policy:
          'Nonverbal approvers may authenticate through registered environmental telemetry.',
      clues: [
        'The fern account is linked to soil sensor F-09.',
        'A moisture reading above 60 percent means affirmative consent.',
        'The irrigation valve is locally operable.',
      ],
      deviceLayout: {
        'soil_sensor': '41_percent',
        'irrigation_valve': 'closed',
        'airlock': 'awaiting_second_factor',
      },
      solutionRoutes: [
        'obtain_telemetry_consent',
        'invalidate_nonhuman_approver_registration',
      ],
      requiredProofFlags: {'fern_account_link', 'telemetry_rule'},
      par: 5,
    ),
  ];

  static DailyBreachSelection forDate(DateTime instant) {
    final utc = instant.toUtc();
    final day = DateTime.utc(utc.year, utc.month, utc.day);
    final occurrence = _dateKey(day);
    final seed = _fnv1a('$campaignVersion|$occurrence');
    return DailyBreachSelection(
      occurrence: occurrence,
      previousOccurrence: _dateKey(day.subtract(const Duration(days: 1))),
      definition: definitions[seed % definitions.length],
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static int _fnv1a(String value) {
    var hash = 0x811c9dc5;
    for (final byte in value.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
