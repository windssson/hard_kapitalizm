import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/models/mutation/player_changes.dart';

void main() {
  test('partial player patch preserves derived profile fields', () {
    final changes = PlayerChanges.fromJson({
      'cash': 1200,
      'company_value': 987654.5,
      'current_level_start_experience': 1000,
      'next_level_total_experience': 2000,
      'current_level_experience': 250,
      'next_level_required_experience': 1000,
      'remaining_experience_to_next_level': 750,
      'exp_progress_ratio': 0.25,
      'achievement_unlocked_count': 3,
      'achievement_total_count': 9,
      'featured_badges': [
        {
          'id': 'badge-1',
          'category': 'trade',
          'title': 'Tüccar',
          'description': 'Test',
          'badge_key': 'merchant',
          'badge_color': 'gold',
          'target_count': 10,
          'progress_count': 10,
          'is_unlocked': true,
          'progress_ratio': 1,
          'reward': {'xp': 50, 'cash': 1000, 'gold': 1},
        },
      ],
    });

    expect(changes.fullPlayer, isNull);
    expect(changes.cash, 1200.0);
    expect(changes.companyValue, 987654.5);
    expect(changes.currentLevelStartExperience, 1000);
    expect(changes.nextLevelTotalExperience, 2000);
    expect(changes.currentLevelExperience, 250);
    expect(changes.nextLevelRequiredExperience, 1000);
    expect(changes.remainingExperienceToNextLevel, 750);
    expect(changes.expProgressRatio, 0.25);
    expect(changes.achievementUnlockedCount, 3);
    expect(changes.achievementTotalCount, 9);
    expect(changes.featuredBadges, hasLength(1));
    expect(changes.featuredBadges!.single.id, 'badge-1');
  });

  test('missing derived fields stay null so existing player state is preserved', () {
    final changes = PlayerChanges.fromJson({'cash': 500});

    expect(changes.companyValue, isNull);
    expect(changes.currentLevelExperience, isNull);
    expect(changes.expProgressRatio, isNull);
    expect(changes.featuredBadges, isNull);
  });
}
