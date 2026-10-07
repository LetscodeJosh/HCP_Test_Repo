import 'package:flutter_test/flutter_test.dart';
import 'package:hcp_profiling/models/hcp_account.dart';

void main() {
  group('Dynamic Monthly Validity Lifecycle Tests', () {
    test('Calculates first and last day for 30-day month (September)', () {
      final refDate = DateTime(2026, 9, 15);
      expect(HcpAccount.calculateMonthValidFrom(refDate), '2026-09-01');
      expect(HcpAccount.calculateMonthValidTo(refDate), '2026-09-30');
      expect(HcpAccount.calculateMonthLabel(refDate), 'September 2026');
    });

    test('Calculates first and last day for 31-day month (October)', () {
      final refDate = DateTime(2026, 10, 1);
      expect(HcpAccount.calculateMonthValidFrom(refDate), '2026-10-01');
      expect(HcpAccount.calculateMonthValidTo(refDate), '2026-10-31');
      expect(HcpAccount.calculateMonthLabel(refDate), 'October 2026');
    });

    test('Calculates February in non-leap year (2026 has 28 days)', () {
      final refDate = DateTime(2026, 2, 10);
      expect(HcpAccount.calculateMonthValidFrom(refDate), '2026-02-01');
      expect(HcpAccount.calculateMonthValidTo(refDate), '2026-02-28');
    });

    test('Calculates February in leap year (2028 has 29 days)', () {
      final refDate = DateTime(2028, 2, 5);
      expect(HcpAccount.calculateMonthValidFrom(refDate), '2028-02-01');
      expect(HcpAccount.calculateMonthValidTo(refDate), '2028-02-29');
    });

    test('isCurrentMonthActive accurately distinguishes current vs historical cycles', () {
      final refSept = DateTime(2026, 9, 23);
      final septAccount = HcpAccount(
        name: 'HCP-ACC-00021',
        hcp: 'HCP-0000028',
        accountName: 'Abbott Diabetes Care',
        territory: 'AD0106',
        validFrom: '2026-09-01',
        validTo: '2026-09-30',
      );
      expect(septAccount.isCurrentMonthActive(refSept), isTrue);

      // In October, the September account is no longer current active (it is archived)
      final refOct = DateTime(2026, 10, 1);
      expect(septAccount.isCurrentMonthActive(refOct), isFalse);

      // Rolled over account for October
      final octRolledAccount = HcpAccount(
        name: 'HCP-ACC-00021-ROLL-202610',
        hcp: septAccount.hcp,
        accountName: septAccount.accountName,
        territory: septAccount.territory,
        validFrom: '2026-10-01',
        validTo: '2026-10-31',
        validityPeriod: 'October 2026',
        isRolledOver: true,
        sourceAccountName: 'HCP-ACC-00021',
      );
      expect(octRolledAccount.isCurrentMonthActive(refOct), isTrue);
      expect(octRolledAccount.isRolledOver, isTrue);
      expect(octRolledAccount.sourceAccountName, 'HCP-ACC-00021');
    });

    test('isPastMonth accurately marks historical accounts and excludes them from current', () {
      final septAccount = HcpAccount(
        name: 'HCP-ACC-00010',
        hcp: 'HCP-0000015',
        accountName: 'Bayer',
        validFrom: '2026-09-01',
        validTo: '2026-09-30',
        validityPeriod: 'September 2026',
      );
      final refOct = DateTime(2026, 10, 1);
      expect(septAccount.isPastMonth(refOct), isTrue);
      expect(septAccount.isCurrentMonthActive(refOct), isFalse);
      expect(septAccount.monthLabel, 'September 2026');
      expect(septAccount.monthKey, '2026-09');
    });

    test('copyForNewMonth retains and synthesizes specialization, workplace, and contact info', () {
      final prevAccount = HcpAccount(
        name: 'HCP-ACC-00030',
        hcp: 'HCP-0000045',
        hcpName: 'Dr. Maria Clara Reyes',
        accountName: 'COREnergy',
        territory: 'CR0101',
        specialty: 'Cardiology',
        subSpecialty: 'Interventional Cardiology',
        workplaceId: 'Philippine Heart Center',
        contactNumber: '+63 918 555 1234',
        contactEmail: 'maria.clara@phc.gov.ph',
        validFrom: '2026-09-01',
        validTo: '2026-09-30',
        validityPeriod: 'September 2026',
      );

      final newTargetMonth = DateTime(2026, 10, 1);
      final rolledAccount = prevAccount.copyForNewMonth(targetMonth: newTargetMonth);

      // Verify dates rolled to October
      expect(rolledAccount.validFrom, '2026-10-01');
      expect(rolledAccount.validTo, '2026-10-31');
      expect(rolledAccount.validityPeriod, 'October 2026');
      expect(rolledAccount.isRolledOver, isTrue);

      // Verify Specialization is retained and synthesized
      expect(rolledAccount.specialty, 'Cardiology');
      expect(rolledAccount.subSpecialty, 'Interventional Cardiology');
      expect(rolledAccount.specialties.isNotEmpty, isTrue);
      expect(rolledAccount.specialties.first.hcpSpecialty, 'Cardiology');

      // Verify Workplace is retained and synthesized
      expect(rolledAccount.workplaceId, 'Philippine Heart Center');
      expect(rolledAccount.workplaces.isNotEmpty, isTrue);
      expect(rolledAccount.workplaces.first.hcpWorkplace, 'Philippine Heart Center');

      // Verify Contact Info is retained and synthesized
      expect(rolledAccount.contactNumber, '+63 918 555 1234');
      expect(rolledAccount.contactEmail, 'maria.clara@phc.gov.ph');
      expect(rolledAccount.contacts.isNotEmpty, isTrue);
      expect(rolledAccount.contacts.first.contactNumber, '+63 918 555 1234');
      expect(rolledAccount.contacts.first.emailAddress, 'maria.clara@phc.gov.ph');
    });

    test('Both September rollout copy and October new copy coexist without conflict', () {
      final septAccount = HcpAccount(
        name: 'HCP-ACC-00021',
        hcp: 'HCP-0000028',
        hcpName: 'Rafael Santos Castillo',
        accountName: 'Abbott Diabetes Care',
        territory: 'AD0106',
        validFrom: '2026-09-01',
        validTo: '2026-09-30',
      );

      final octAccount = HcpAccount(
        name: 'HCP-ACC-00147',
        hcp: 'HCP-0000028',
        hcpName: 'Rafael Santos Castillo',
        accountName: 'Abbott Diabetes Care',
        territory: 'AD0106',
        validFrom: '2026-10-01',
        validTo: '2026-10-31',
      );

      // Verify month labels and keys
      expect(septAccount.monthLabel, 'September 2026');
      expect(septAccount.monthKey, '2026-09');
      expect(octAccount.monthLabel, 'October 2026');
      expect(octAccount.monthKey, '2026-10');

      // Verify distinct deduplication keys
      final septKey = '${septAccount.hcp}::${septAccount.accountOrProgram.toLowerCase()}::${septAccount.monthKey}';
      final octKey = '${octAccount.hcp}::${octAccount.accountOrProgram.toLowerCase()}::${octAccount.monthKey}';
      expect(septKey, isNot(equals(octKey)));

      // Reference date: October 1, 2026
      final refOct = DateTime(2026, 10, 1);
      expect(septAccount.isPastMonth(refOct), isTrue);
      expect(septAccount.isCurrentMonthActive(refOct), isFalse);
      expect(octAccount.isPastMonth(refOct), isFalse);
      expect(octAccount.isCurrentMonthActive(refOct), isTrue);
    });
  });
}

