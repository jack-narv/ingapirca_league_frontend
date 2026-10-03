import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingapirca_league_frontend/models/match.dart';
import 'package:ingapirca_league_frontend/features/admin/matches/add_match_event_dialog.dart';

void main() {
  Match match({int? homePenalties, int? awayPenalties, String journal = 'FINAL'}) => Match(
    id: 'm', seasonId: 's', journal: journal, homeTeamId: 'h', awayTeamId: 'a',
    venueId: 'v', matchDate: DateTime(2026), status: 'PLAYED', homeScore: 3, awayScore: 3,
    homePenaltyScore: homePenalties, awayPenaltyScore: awayPenalties,
  );

  test('only shootout results have parenthesized penalty totals', () {
    expect(match().scoreLabel, '3 - 3');
    expect(match(homePenalties: 4, awayPenalties: 5).scoreLabel, '(4) 3 - 3 (5)');
    expect(match(homePenalties: 0, awayPenalties: 1).scoreLabel, '(0) 3 - 3 (1)');
  });

  test('uses the backend knockout journal convention', () {
    expect(match().isKnockout, isTrue);
    expect(match(journal: 'SEMIFINAL').isKnockout, isTrue);
    expect(match(journal: 'JOURNAL 1').isKnockout, isFalse);
    expect(match(journal: '1').isKnockout, isFalse);
  });

  Widget dialog(String status) => MaterialApp(home: Scaffold(body: AddMatchEventDialog(
    matchId: 'm', homeTeamId: 'h', awayTeamId: 'a', homeTeamName: 'Local', awayTeamName: 'Visitante',
    matchStatus: status, homeLineup: const [], awayLineup: const [],
  )));

  testWidgets('penalties hide time and offer only converted or missed kicks', (tester) async {
    await tester.pumpWidget(dialog('PENALTIES'));
    expect(find.byType(TextField), findsNothing);
    final dropdowns = tester.widgetList<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>));
    // Inspect the dropdown rendered by the form field to verify the full option set.
    final typeDropdown = tester.widgetList<DropdownButton<String>>(find.byType(DropdownButton<String>))
        .firstWhere((d) => d.value == 'PENALTY_CONVERTED');
    expect(typeDropdown.items!.map((item) => item.value).toList(), ['PENALTY_CONVERTED', 'PENALTY_MISSED']);
    expect(dropdowns.length, 3);
  });

  for (final status in ['PLAYING_FIRST_HALF', 'PLAYING_SECOND_HALF', 'PLAYING_FIRST_EXTRA_HALF', 'PLAYING_SECOND_EXTRA_HALF']) {
    testWidgets('$status requires a minute and preserves ordinary events', (tester) async {
      await tester.pumpWidget(dialog(status));
      expect(find.byType(TextField), findsOneWidget);
      final typeDropdown = tester.widgetList<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .firstWhere((d) => d.value == 'GOAL');
      expect(typeDropdown.items!.map((item) => item.value), isNot(contains('PENALTY_CONVERTED')));
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      expect(find.text('Minuto invalido'), findsOneWidget);
    });
  }
}
