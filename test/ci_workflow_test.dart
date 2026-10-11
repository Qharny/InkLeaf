import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// Use the YAML parser already pinned in pubspec.lock by the development tools.
// ignore: depend_on_referenced_packages
import 'package:yaml/yaml.dart';

// These contract tests inspect the real workflow without invoking GitHub Actions
// or recursively running the application's test suite.
void main() {
  late YamlMap workflow;
  late YamlMap check;
  late List<YamlMap> steps;

  setUpAll(() {
    workflow =
        loadYaml(File('.github/workflows/ci.yml').readAsStringSync()) as YamlMap;
    check = (workflow['jobs'] as YamlMap)['check'] as YamlMap;
    steps = (check['steps'] as YamlList).cast<YamlMap>();
  });

  group('CI triggers', () {
    test('runs on pull requests without branch or path exclusions', () {
      final events = workflow['on'] as YamlMap;

      // Checking key presence matters: an absent event and a bare YAML event
      // both return null when accessed by key.
      expect(events.containsKey('pull_request'), isTrue);
      final pullRequest = events['pull_request'] as YamlMap?;
      expect(pullRequest ?? {}, isEmpty);
    });

    test('runs on main pushes but excludes feature-branch and tag pushes', () {
      final push = (workflow['on'] as YamlMap)['push'] as YamlMap;

      // A branches-only filter excludes feature-branch and tag push events.
      expect(push['branches'], orderedEquals(['main']));
      for (final filter in [
        'branches-ignore',
        'tags',
        'tags-ignore',
        'paths',
        'paths-ignore',
      ]) {
        expect(push.containsKey(filter), isFalse, reason: filter);
      }
    });
  });

  group('CI scheduling', () {
    test('cancels stale runs only within the same ref', () {
      final concurrency = workflow['concurrency'] as YamlMap;

      // github.ref separates main, feature branches and PR merge refs. A
      // constant group would let unrelated PRs cancel each other's checks.
      expect(concurrency['group'], r'ci-${{ github.ref }}');
      expect(concurrency['cancel-in-progress'], isTrue);
    });

    test('bounds the Linux check job to twenty minutes', () {
      expect(check['runs-on'], 'ubuntu-latest');
      expect(check['timeout-minutes'], 20);
    });
  });

  group('CI preparation', () {
    test('checks out the repository before installing Flutter', () {
      final checkoutIndex = steps.indexWhere(
        (step) => step['uses'] == 'actions/checkout@v4',
      );
      final flutterIndex = steps.indexWhere(
        (step) => step['uses'] == 'subosito/flutter-action@v2',
      );
      final installIndex = steps.indexWhere(
        (step) => step['run'] == 'flutter pub get',
      );

      expect(checkoutIndex, greaterThanOrEqualTo(0));
      expect(flutterIndex, greaterThan(checkoutIndex));
      expect(installIndex, greaterThan(flutterIndex));

      final checkout = steps[checkoutIndex]['with'] as YamlMap?;
      expect(
        checkout?.containsKey('ref') ?? false,
        isFalse,
        reason: 'An explicit ref could check main instead of the PR revision.',
      );
    });

    test('uses the pinned stable Flutter SDK with dependency caching', () {
      final flutter = steps.singleWhere(
        (step) => step['uses'] == 'subosito/flutter-action@v2',
      );
      final inputs = flutter['with'] as YamlMap;

      expect(inputs['flutter-version'], '3.47.7');
      expect(inputs['channel'], 'stable');
      expect(inputs['cache'], isTrue);
    });
  });

  group('CI quality gates', () {
    test('installs packages before formatting, analysis and the full suite', () {
      final commands = steps
          .where((step) => step.containsKey('run'))
          .map((step) => (step['run'] as String).trim());

      // The formatter must fail on changes without rewriting files; analysis
      // and tests must retain their normal failure exit codes. Exact commands
      // also catch accidental test filters, watch mode and `|| true` masking.
      expect(
        commands,
        orderedEquals([
          'flutter pub get',
          'dart format --output=none --set-exit-if-changed lib test',
          'flutter analyze',
          'flutter test',
        ]),
      );
    });

    test('job failures cannot be turned into successful checks', () {
      expect(check['continue-on-error'] ?? false, isFalse);
      expect(check.containsKey('if'), isFalse);
    });

    test('every setup step and quality gate is required to succeed', () {
      for (final step in steps) {
        final label = step['name'] ?? step['uses'] ?? step['run'];
        expect(
          step['continue-on-error'] ?? false,
          isFalse,
          reason: '$label must propagate failures.',
        );
        expect(
          step.containsKey('if'),
          isFalse,
          reason: '$label must use the default success condition.',
        );
      }
    });
  });
}
