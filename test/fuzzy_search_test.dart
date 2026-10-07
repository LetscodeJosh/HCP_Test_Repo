import 'package:flutter_test/flutter_test.dart';
import 'package:hcp_profiling/models/lookup_models.dart';

void main() {
  group('LocationResolver.fuzzySearchInstitutions Tests', () {
    final testInstitutions = [
      Institution(
        name: 'INST-00001',
        institutionName: "St. Luke's Medical Center - Global City",
        cityMunicipality: 'Taguig',
        provinceName: 'Metro Manila',
        streetAddress: '32nd St. Bonifacio Global City',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00002',
        institutionName: "St. Luke's Medical Center - Quezon City",
        cityMunicipality: 'Quezon City',
        provinceName: 'Metro Manila',
        streetAddress: '279 E. Rodriguez Sr. Ave',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00003',
        institutionName: 'Asian Hospital and Medical Center',
        cityMunicipality: 'Muntinlupa',
        provinceName: 'Metro Manila',
        streetAddress: '2205 Civic Dr, Filinvest Alabang',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00004',
        institutionName: 'Makati Medical Center',
        cityMunicipality: 'Makati',
        provinceName: 'Metro Manila',
        streetAddress: '2 Amorsolo St, Legaspi Village',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00005',
        institutionName: 'Manila Doctors Hospital',
        cityMunicipality: 'Manila',
        provinceName: 'Metro Manila',
        streetAddress: '667 United Nations Ave, Ermita',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00006',
        institutionName: 'Philippine General Hospital',
        cityMunicipality: 'Manila',
        provinceName: 'Metro Manila',
        streetAddress: 'Taft Avenue, Ermita',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00007',
        institutionName: 'Cardinal Santos Medical Center',
        cityMunicipality: 'San Juan',
        provinceName: 'Metro Manila',
        streetAddress: 'Wilson St, Greenhills',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00008',
        institutionName: 'Chinese General Hospital and Medical Center',
        cityMunicipality: 'Manila',
        provinceName: 'Metro Manila',
        streetAddress: 'Blumentritt St, Santa Cruz',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00009',
        institutionName: 'The Medical City Ortigas',
        cityMunicipality: 'Pasig',
        provinceName: 'Metro Manila',
        streetAddress: 'Ortigas Ave',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00010',
        institutionName: 'De Los Santos Medical Center',
        cityMunicipality: 'Quezon City',
        provinceName: 'Metro Manila',
        streetAddress: 'E Rodriguez Sr Ave',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00011',
        institutionName: 'Lung Center of the Philippines',
        cityMunicipality: 'Quezon City',
        provinceName: 'Metro Manila',
        streetAddress: 'Quezon Ave, Diliman',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00012',
        institutionName: 'Philippine Heart Center',
        cityMunicipality: 'Quezon City',
        provinceName: 'Metro Manila',
        streetAddress: 'East Avenue, Diliman',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00013',
        institutionName: 'Our Lady of Lourdes Hospital',
        cityMunicipality: 'Manila',
        provinceName: 'Metro Manila',
        streetAddress: '46 P. Sanchez St, Santa Mesa',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00014',
        institutionName: 'University of Santo Tomas Hospital',
        cityMunicipality: 'Manila',
        provinceName: 'Metro Manila',
        streetAddress: 'España Blvd, Sampaloc',
        workflowState: 'Approved',
      ),
    ];

    test('Searching "Philippine" places institutions starting with "Philippine" at beginning, and retains all potential clues', () {
      final results = LocationResolver.fuzzySearchInstitutions('Philippine', testInstitutions);
      expect(results, isNotEmpty);
      // Top results MUST start with "Philippine"
      expect(results.first.institutionName.startsWith('Philippine'), isTrue);
      // Specifically both Philippine General Hospital and Philippine Heart Center appear first
      final topTwo = results.take(2).map((i) => i.institutionName).toList();
      expect(topTwo, contains('Philippine General Hospital'));
      expect(topTwo, contains('Philippine Heart Center'));
      // Lung Center of the Philippines (contains "Philippines") is also retained in the list, not filterized out
      expect(results.any((i) => i.institutionName == 'Lung Center of the Philippines'), isTrue);
    });

    test('Multi-token query: "st lukes bgc" prioritizes St. Lukes Global City without filterizing away potential clues', () {
      final results = LocationResolver.fuzzySearchInstitutions('st lukes bgc', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, contains("St. Luke's Medical Center - Global City"));
      // Other Luke's and medical centers with partial clues are also present in results (not filterized away)
      expect(results.any((i) => i.institutionName.contains("Quezon City")), isTrue);
    });

    test('Location clue: "asian alabang" matches Asian Hospital in Alabang at top rank', () {
      final results = LocationResolver.fuzzySearchInstitutions('asian alabang', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Asian Hospital and Medical Center'));
    });

    test('Medical abbreviation: "makati med" matches Makati Medical Center at top rank', () {
      final results = LocationResolver.fuzzySearchInstitutions('makati med', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Makati Medical Center'));
    });

    test('Compound word clue: "delos santos" correctly matches De Los Santos Medical Center at top rank', () {
      final results = LocationResolver.fuzzySearchInstitutions('delos santos', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('De Los Santos Medical Center'));
    });

    test('Acronym clue: "pgh" matches Philippine General Hospital as top result', () {
      final results = LocationResolver.fuzzySearchInstitutions('pgh', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Philippine General Hospital'));
    });

    test('Location street clue: "blumentritt" matches Chinese General Hospital', () {
      final results = LocationResolver.fuzzySearchInstitutions('blumentritt', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Chinese General Hospital and Medical Center'));
    });

    test('Partial clue retention: single token "san juan" retains all potential clues with Cardinal Santos at top', () {
      final results = LocationResolver.fuzzySearchInstitutions('san juan', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Cardinal Santos Medical Center'));
      // Other institutions with 'San' or 'Santos' also retained in dropdown
      expect(results.any((i) => i.institutionName.contains('De Los Santos')), isTrue);
    });

    test('Sound-alike / Phonetic search: "lordes" readily returns Our Lady of Lourdes Hospital at top', () {
      final results = LocationResolver.fuzzySearchInstitutions('lordes', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Our Lady of Lourdes Hospital'));
    });

    test('Sound-alike / Phonetic search: "kardinal" readily returns Cardinal Santos Medical Center at top', () {
      final results = LocationResolver.fuzzySearchInstitutions('kardinal', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Cardinal Santos Medical Center'));
    });

    test('Sound-alike / Phonetic search: "makaty" readily returns Makati Medical Center at top', () {
      final results = LocationResolver.fuzzySearchInstitutions('makaty', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Makati Medical Center'));
    });

    test('Sound-alike / Phonetic search: "chines" readily returns Chinese General Hospital at top', () {
      final results = LocationResolver.fuzzySearchInstitutions('chines', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Chinese General Hospital and Medical Center'));
    });

    test('Same-phrase / Permuted word order: "doctors manila" readily returns Manila Doctors Hospital as top choice', () {
      final results = LocationResolver.fuzzySearchInstitutions('doctors manila', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Manila Doctors Hospital'));
    });

    test('Same-phrase / Permuted word order: "general chinese hospital" readily returns Chinese General Hospital as top choice', () {
      final results = LocationResolver.fuzzySearchInstitutions('general chinese hospital', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Chinese General Hospital and Medical Center'));
    });

    test('Same-phrase / Permuted word order: "santos cardinal" readily returns Cardinal Santos Medical Center as top choice', () {
      final results = LocationResolver.fuzzySearchInstitutions('santos cardinal', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Cardinal Santos Medical Center'));
    });

    test('Same-phrase / Permuted word order: "lourdes lady" readily returns Our Lady of Lourdes Hospital as top choice', () {
      final results = LocationResolver.fuzzySearchInstitutions('lourdes lady', testInstitutions);
      expect(results, isNotEmpty);
      expect(results.first.institutionName, equals('Our Lady of Lourdes Hospital'));
    });

    test('Empty query returns complete institution collection', () {
      final results = LocationResolver.fuzzySearchInstitutions('', testInstitutions);
      expect(results.length, equals(testInstitutions.length));
    });
  });

  group('LocationResolver.resolveCompleteWorkplaceLocation Tests', () {
    test('Guarantees all workplace fields (workplace, region, province, city) are NEVER empty', () {
      // Case 1: Complete blank inputs
      final res1 = LocationResolver.resolveCompleteWorkplaceLocation();
      expect(res1.workplaceId, isNotEmpty);
      expect(res1.workplaceName, isNotEmpty);
      expect(res1.regionId, isNotEmpty);
      expect(res1.regionName, isNotEmpty);
      expect(res1.provinceId, isNotEmpty);
      expect(res1.provinceName, isNotEmpty);
      expect(res1.cityId, isNotEmpty);
      expect(res1.cityName, isNotEmpty);

      // Case 2: Institution name only (without city, province, region)
      final res2 = LocationResolver.resolveCompleteWorkplaceLocation(
        institutionName: 'Philippine General Hospital',
      );
      expect(res2.workplaceName, equals('Philippine General Hospital'));
      expect(res2.cityName, isNotEmpty);
      expect(res2.provinceName, isNotEmpty);
      expect(res2.regionName, isNotEmpty);
      expect(res2.cityId, isNotEmpty);
      expect(res2.provinceId, isNotEmpty);
      expect(res2.regionId, isNotEmpty);

      // Case 3: Empty dashes or missing strings in raw fields
      final res3 = LocationResolver.resolveCompleteWorkplaceLocation(
        workplaceNameOrId: 'Asian Hospital and Medical Center',
        rawCity: '-',
        rawProvince: '',
        rawRegion: '-',
        streetAddress: 'Filinvest Alabang Muntinlupa',
      );
      expect(res3.cityName, contains('Muntinlupa'));
      expect(res3.provinceName, contains('Metro Manila'));
      expect(res3.regionName, contains('NCR'));
      expect(res3.cityId, isNotEmpty);
      expect(res3.provinceId, isNotEmpty);
      expect(res3.regionId, isNotEmpty);
    });
  });
}
