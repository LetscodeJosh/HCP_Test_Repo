import 'package:flutter_test/flutter_test.dart';
import 'package:hcp_profiling/services/data_sanitizer.dart';

void main() {
  group('Enterprise Data Sanitizer (Clean, Trim, Proper) Tests', () {
    test('1. Clean & Trim: Strips invisible zero-width spaces, non-breaking spaces, tabs, newlines', () {
      const dirty = '\uFEFF \u200B Dr.   Juan \t  Dela \u00A0 Cruz \r\n ';
      final cleaned = DataSanitizer.clean(dirty);
      expect(cleaned, 'Dr. Juan Dela Cruz');
      expect(DataSanitizer.trim(dirty), 'Dr. Juan Dela Cruz');
    });

    test('2. Literal null and undefined strings are safely converted to empty', () {
      expect(DataSanitizer.clean('null'), '');
      expect(DataSanitizer.clean('undefined'), '');
      expect(DataSanitizer.clean('  NULL  '), '');
      expect(DataSanitizer.clean('N/A'), '');
      expect(DataSanitizer.clean('None'), '');
    });

    test('3. Proper Case: Capitalizes names and respects minor connectors', () {
      expect(DataSanitizer.properCase('juan dela cruz'), 'Juan dela Cruz');
      expect(DataSanitizer.properCase('DR. MARIA SANTOS-REYES'), 'Dr. Maria Santos-Reyes');
      expect(DataSanitizer.properCase('CARDINAL SANTOS MEDICAL CENTER'), 'Cardinal Santos Medical Center');
      expect(DataSanitizer.properCase('our lady of lourdes hospital'), 'Our Lady of Lourdes Hospital');
      expect(DataSanitizer.properCase('de los santos medical center'), 'De Los Santos Medical Center');
    });

    test('4. Proper Case: Preserves critical medical acronyms and Roman numerals', () {
      expect(DataSanitizer.properCase('DR. JUAN DELA CRUZ, MD'), 'Dr. Juan dela Cruz, MD');
      expect(DataSanitizer.properCase('ob-gyn clinic'), 'OB-GYN Clinic');
      expect(DataSanitizer.properCase('st. luke\'s medical center bgc'), 'St. Luke\'s Medical Center BGC');
      expect(DataSanitizer.properCase('philippine general hospital pgh'), 'Philippine General Hospital PGH');
      expect(DataSanitizer.properCase('region iv-a'), 'Region IV-A');
    });

    test('5. Territory Codes: Guarantees trimmed uppercase', () {
      expect(DataSanitizer.cleanTrimUpper('  adc0101  '), 'ADC0101');
      expect(DataSanitizer.cleanTrimUpper('\tad0106\n'), 'AD0106');
      expect(DataSanitizer.cleanTrimUpper('bay-manila-01'), 'BAY-MANILA-01');
    });

    test('6. Phone Numbers: Normalizes digits and leading plus', () {
      expect(DataSanitizer.cleanPhone(' 0917-123-4567 '), '09171234567');
      expect(DataSanitizer.cleanPhone('+63 917 123 4567'), '+639171234567');
      expect(DataSanitizer.cleanPhone('(02) 8888-1234'), '0288881234');
      expect(DataSanitizer.cleanPhone('N/A'), '');
    });

    test('7. Emails: Normalizes lowercase and trimmed', () {
      expect(DataSanitizer.cleanTrimLower('  DOCTOR.DELACRUZ@HOSPITAL.COM \n'), 'doctor.delacruz@hospital.com');
      expect(DataSanitizer.cleanTrimLower('MedRep.Abbott@Gmail.Com'), 'medrep.abbott@gmail.com');
    });

    test('8. Deep Payload Map Sanitization for ERPNext Export', () {
      final rawPayload = {
        'first_name': '  juan  ',
        'last_name': 'DELA CRUZ',
        'territory_code': ' adc0101 ',
        'email_address': ' DOCTOR@HOSPITAL.COM ',
        'contact_number': ' 0917-888-9999 ',
        'workplace_name': 'MANILA DOCTORS HOSPITAL',
        'status': ' pending approval ',
        'meta': {
          'user_id': ' emp-00123 ',
          'district': 'north metro manila',
        }
      };

      final sanitized = DataSanitizer.sanitizePayload(rawPayload);

      expect(sanitized['first_name'], 'Juan');
      expect(sanitized['last_name'], 'Dela Cruz');
      expect(sanitized['territory_code'], 'ADC0101');
      expect(sanitized['email_address'], 'doctor@hospital.com');
      expect(sanitized['contact_number'], '09178889999');
      expect(sanitized['workplace_name'], 'Manila Doctors Hospital');
      expect(sanitized['status'], 'PENDING APPROVAL');
      expect((sanitized['meta'] as Map)['user_id'], 'EMP-00123');
      expect((sanitized['meta'] as Map)['district'], 'North Metro Manila');
    });
  });
}
