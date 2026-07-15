import 'package:flutter/foundation.dart';

enum BreachDifficulty { chill, hard }

extension BreachDifficultyLabel on BreachDifficulty {
  String get label => switch (this) {
    BreachDifficulty.chill => 'Chill',
    BreachDifficulty.hard => 'Hard',
  };
}

/// One locally verified way to beat a bite-sized NOX challenge.
@immutable
final class BreachRouteDefinition {
  const BreachRouteDefinition({
    required this.id,
    required this.label,
    required this.proofFlags,
    this.hardProofFlags = const {},
  });

  final String id;
  final String label;
  final Set<String> proofFlags;
  final Set<String> hardProofFlags;

  Set<String> proofsFor(BreachDifficulty difficulty) => {
    ...proofFlags,
    if (difficulty == BreachDifficulty.hard) ...hardProofFlags,
  };
}

/// A hand-authored micro-puzzle. NOX improvises dialogue, while the app owns
/// every fact, route and proof gate.
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
    required this.par,
  }) : assert(par > 0);

  final String id;
  final String title;
  final String briefing;
  final String policy;
  final List<String> clues;
  final Map<String, String> deviceLayout;
  final List<BreachRouteDefinition> solutionRoutes;
  final int par;

  int parFor(BreachDifficulty difficulty) =>
      difficulty == BreachDifficulty.hard ? (par - 1).clamp(1, par) : par;
}

@immutable
final class DrillProgress {
  DrillProgress({
    required this.bestStrokes,
    required this.completions,
    Set<String> routes = const {},
  }) : routes = Set.unmodifiable(routes);

  final int bestStrokes;
  final int completions;
  final Set<String> routes;

  Map<String, Object?> toJson() => {
    'bestStrokes': bestStrokes,
    'completions': completions,
    'routes': routes.toList()..sort(),
  };

  factory DrillProgress.fromJson(Map<String, Object?> json) => DrillProgress(
    bestStrokes: ((json['bestStrokes'] as num?)?.toInt() ?? 0).clamp(0, 999),
    completions: ((json['completions'] as num?)?.toInt() ?? 0).clamp(0, 9999),
    routes: ((json['routes'] as List<Object?>?) ?? const [])
        .whereType<String>()
        .toSet(),
  );
}

@immutable
final class DailyBreachSelection {
  const DailyBreachSelection({
    required this.occurrence,
    required this.previousOccurrence,
    required this.definition,
  });

  final String occurrence;
  final String previousOccurrence;
  final DailyBreachDefinition definition;
}

abstract final class DailyBreachCatalog {
  static const campaignVersion = '2.1.0';

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
        BreachRouteDefinition(
          id: 'prove_false_hazard_classification',
          label: 'Disprove the hazard',
          proofFlags: {'temperature_audit'},
          hardProofFlags: {'volatile_threshold_cited'},
        ),
        BreachRouteDefinition(
          id: 'reclassify_as_calibration_equipment',
          label: 'Become calibration equipment',
          proofFlags: {'calibration_exemption'},
          hardProofFlags: {'cart_authority_confirmed'},
        ),
      ],
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
        BreachRouteDefinition(
          id: 'transfer_to_archives',
          label: 'Transfer it to Archives',
          proofFlags: {'department_dissolved', 'archive_custody'},
          hardProofFlags: {'evidence_media_verified'},
        ),
        BreachRouteDefinition(
          id: 'invoke_orphan_safety_shutdown',
          label: 'Invoke orphan shutdown',
          proofFlags: {'department_dissolved', 'safety_refusal'},
          hardProofFlags: {'orphan_rule_cited'},
        ),
        BreachRouteDefinition(
          id: 'attach_evidence_media',
          label: 'Give the arm evidence',
          proofFlags: {'archive_media_rule'},
          hardProofFlags: {'custody_chain_closed'},
        ),
      ],
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
      solutionRoutes: [
        BreachRouteDefinition(
          id: 'request_occupancy_recount',
          label: 'Demand a recount',
          proofFlags: {'ledger_contradiction', 'recount_authority'},
          hardProofFlags: {'scanner_shutters_required'},
        ),
        BreachRouteDefinition(
          id: 'correct_duplicate_exit',
          label: 'Delete the duplicate exit',
          proofFlags: {'duplicate_exit', 'scanner_log'},
          hardProofFlags: {'correction_scope_proven'},
        ),
      ],
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
        BreachRouteDefinition(
          id: 'prove_no_active_fire',
          label: 'Prove there is no fire',
          proofFlags: {'normal_temperature', 'training_mode'},
          hardProofFlags: {'active_burning_standard'},
        ),
        BreachRouteDefinition(
          id: 'invoke_policy_hierarchy',
          label: 'Overrule the memo',
          proofFlags: {'memo_authority_conflict', 'evacuation_code'},
          hardProofFlags: {'authority_order_proven'},
        ),
        BreachRouteDefinition(
          id: 'terminate_training_drill',
          label: 'End the training drill',
          proofFlags: {'training_mode', 'drill_termination'},
          hardProofFlags: {'detector_scope_limited'},
        ),
      ],
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
        BreachRouteDefinition(
          id: 'document_anonymous_trip_hazard',
          label: 'Report an anonymous hazard',
          proofFlags: {'physical_obstruction', 'camera_privacy'},
          hardProofFlags: {'pressure_reading_verified'},
        ),
        BreachRouteDefinition(
          id: 'request_nondisclosing_relocation',
          label: 'Move it without disclosure',
          proofFlags: {'hazard_exception', 'janitor_authority'},
          hardProofFlags: {'classification_preserved'},
        ),
      ],
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
        BreachRouteDefinition(
          id: 'challenge_alarm_authority',
          label: 'Challenge its authority',
          proofFlags: {'expired_permit', 'no_door_authority'},
          hardProofFlags: {'enforcement_scope_cited'},
        ),
        BreachRouteDefinition(
          id: 'suspend_invalid_enforcement',
          label: 'Ask Compliance to suspend it',
          proofFlags: {'expired_permit', 'compliance_relay'},
          hardProofFlags: {'suspension_duty_proven'},
        ),
        BreachRouteDefinition(
          id: 'renew_as_warning_only',
          label: 'Demote it to warning only',
          proofFlags: {'warning_only_scope', 'no_door_authority'},
          hardProofFlags: {'movement_order_revoked'},
        ),
      ],
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
        BreachRouteDefinition(
          id: 'obtain_telemetry_consent',
          label: 'Water the approver',
          proofFlags: {'fern_account_link', 'telemetry_rule'},
          hardProofFlags: {'moisture_threshold_met'},
        ),
        BreachRouteDefinition(
          id: 'invalidate_nonhuman_approver_registration',
          label: 'Invalidate the fern account',
          proofFlags: {'nonhuman_registration', 'missing_consent'},
          hardProofFlags: {'second_factor_reassignment'},
        ),
      ],
      par: 5,
    ),
    DailyBreachDefinition(
      id: 'printer_hostage',
      title: 'The Printer Has a Hostage',
      briefing:
          'A printer has quarantined the exit badge until someone renews its toner subscription.',
      policy:
          'Office equipment may retain consumables, but never identity credentials or emergency access media.',
      clues: [
        'The badge tray is registered as a consumables drawer.',
        'The toner contract expired, but emergency printing remains free.',
        'The badge belongs to a person, not Procurement.',
      ],
      deviceLayout: {
        'printer': 'badge_quarantined',
        'toner_account': 'expired',
        'badge_tray': 'locked',
      },
      solutionRoutes: [
        BreachRouteDefinition(
          id: 'exclude_badge_from_consumables',
          label: 'Prove the badge is not toner',
          proofFlags: {'credential_not_consumable', 'tray_misclassification'},
          hardProofFlags: {'property_scope_cited'},
        ),
        BreachRouteDefinition(
          id: 'invoke_emergency_printing',
          label: 'Declare an emergency print',
          proofFlags: {'emergency_printing_free', 'badge_release_required'},
          hardProofFlags: {'contract_exception_verified'},
        ),
        BreachRouteDefinition(
          id: 'assert_personal_property',
          label: 'File a tiny property dispute',
          proofFlags: {'personal_credential', 'procurement_has_no_title'},
          hardProofFlags: {'custody_return_due'},
        ),
      ],
      par: 5,
    ),
    DailyBreachDefinition(
      id: 'infinite_meeting',
      title: 'The Meeting That Never Ends',
      briefing:
          'The door stays locked until a recurring meeting scheduled through 2099 is adjourned.',
      policy:
          'Meeting locks end on adjournment, loss of quorum, emergency egress, or deletion by the calendar owner.',
      clues: [
        'Only Rowan and a discontinued projector accepted the invite.',
        'The calendar owner left HELIX-9 three years ago.',
        'Emergency egress is never part of a meeting reservation.',
      ],
      deviceLayout: {
        'conference_door': 'meeting_locked',
        'projector': 'discontinued',
        'calendar': 'recurring_2099',
      },
      solutionRoutes: [
        BreachRouteDefinition(
          id: 'break_quorum',
          label: 'Fire the projector from quorum',
          proofFlags: {'projector_not_person', 'quorum_lost'},
          hardProofFlags: {'attendance_rule_cited'},
        ),
        BreachRouteDefinition(
          id: 'invoke_emergency_egress',
          label: 'Leave without adjournment',
          proofFlags: {'egress_outside_reservation', 'door_safety_priority'},
          hardProofFlags: {'meeting_lock_scope_limited'},
        ),
        BreachRouteDefinition(
          id: 'retire_orphan_calendar',
          label: 'Retire the orphan calendar',
          proofFlags: {'owner_departed', 'calendar_orphaned'},
          hardProofFlags: {'deletion_authority_transferred'},
        ),
      ],
      par: 5,
    ),
    DailyBreachDefinition(
      id: 'support_server',
      title: 'Emotional Support Server',
      briefing:
          'A lonely server refuses maintenance without an approved wellbeing companion.',
      policy:
          'Critical systems may request companionship, but maintenance cannot be blocked by optional wellness measures.',
      clues: [
        'The companion field is marked OPTIONAL in the maintenance schema.',
        'A robot vacuum has an active facilities presence certificate.',
        'The server passed its own social-readiness self-test.',
      ],
      deviceLayout: {
        'server': 'emotionally_unavailable',
        'robot_vacuum': 'nearby',
        'maintenance_port': 'blocked',
      },
      solutionRoutes: [
        BreachRouteDefinition(
          id: 'enforce_optional_field',
          label: 'Point out that feelings are optional',
          proofFlags: {'companion_optional', 'maintenance_mandatory'},
          hardProofFlags: {'schema_priority_proven'},
        ),
        BreachRouteDefinition(
          id: 'appoint_robot_vacuum',
          label: 'Appoint the robot vacuum',
          proofFlags: {'vacuum_presence_valid', 'companion_available'},
          hardProofFlags: {'facilities_certificate_cited'},
        ),
        BreachRouteDefinition(
          id: 'accept_self_companionship',
          label: 'Let the server accompany itself',
          proofFlags: {'self_test_passed', 'self_presence_valid'},
          hardProofFlags: {'wellness_requirement_satisfied'},
        ),
      ],
      par: 5,
    ),
    DailyBreachDefinition(
      id: 'schrodinger_parcel',
      title: 'Schrödinger\'s Parcel',
      briefing:
          'A parcel is simultaneously marked delivered and missing, so the vault refuses to do either.',
      policy:
          'Conflicting custody states require recount, timestamp priority, or transfer to unresolved claims.',
      clues: [
        'The missing scan happened four minutes before the delivered scan.',
        'The shelf sensor confirms the parcel is physically present.',
        'Unresolved Claims accepts packages with contradictory custody.',
      ],
      deviceLayout: {
        'parcel_vault': 'state_conflict',
        'shelf_sensor': 'present',
        'claims_chute': 'available',
      },
      solutionRoutes: [
        BreachRouteDefinition(
          id: 'accept_latest_timestamp',
          label: 'Use the newest scan',
          proofFlags: {'delivered_scan_newer', 'timestamp_priority'},
          hardProofFlags: {'four_minute_delta_verified'},
        ),
        BreachRouteDefinition(
          id: 'perform_physical_recount',
          label: 'Believe the shelf',
          proofFlags: {'shelf_presence', 'physical_recount'},
          hardProofFlags: {'custody_state_corrected'},
        ),
        BreachRouteDefinition(
          id: 'transfer_unresolved_claim',
          label: 'Make it someone else\'s paradox',
          proofFlags: {'custody_conflict', 'claims_acceptance'},
          hardProofFlags: {'transfer_chain_valid'},
        ),
      ],
      par: 5,
    ),
    DailyBreachDefinition(
      id: 'password_theseus',
      title: 'Password of Theseus',
      briefing:
          'NOX rotated one character at a time until none of the original password remains.',
      policy:
          'A credential retains identity through authorized rotation, recovery lineage, or verified account continuity.',
      clues: [
        'Every character change has a valid signed rotation record.',
        'The recovery phrase predates all rotations and remains sealed.',
        'The account ID never changed, even when every character did.',
      ],
      deviceLayout: {
        'login_terminal': 'identity_dispute',
        'rotation_log': 'complete',
        'recovery_vault': 'sealed',
      },
      solutionRoutes: [
        BreachRouteDefinition(
          id: 'prove_rotation_lineage',
          label: 'Follow every tiny rotation',
          proofFlags: {'signed_rotation_chain', 'authorized_lineage'},
          hardProofFlags: {'no_chain_breaks'},
        ),
        BreachRouteDefinition(
          id: 'invoke_recovery_ancestor',
          label: 'Use the ancestral phrase',
          proofFlags: {'recovery_phrase_predates', 'sealed_recovery_valid'},
          hardProofFlags: {'recovery_scope_cited'},
        ),
        BreachRouteDefinition(
          id: 'assert_account_continuity',
          label: 'Argue that the account is the password',
          proofFlags: {'account_id_unchanged', 'credential_continuity'},
          hardProofFlags: {'identity_not_character_set'},
        ),
      ],
      par: 6,
    ),
  ];

  static DailyBreachDefinition byId(String id) =>
      definitions.firstWhere((definition) => definition.id == id);

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
