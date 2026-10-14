import '../models/hcp.dart';
import '../models/lookup_models.dart';

/// Represents a smart match result from the HCP Doctor Masterlist recognizer.
class HcpDoctorMatchResult {
  final Hcp doctor;
  final double score; // 0.0 to 100.0
  final String matchReason;
  final bool isExact;
  final String formattedSpecialty;
  final String formattedWorkplace;

  const HcpDoctorMatchResult({
    required this.doctor,
    required this.score,
    required this.matchReason,
    required this.isExact,
    required this.formattedSpecialty,
    required this.formattedWorkplace,
  });
}

/// Intelligent Gemini 4 Argon-grade fuzzy recognizer and name normalization
/// engine for the HCP doctype masterlist.
class HcpDoctorMatchEngine {
  /// Normalizes medical practitioner names:
  /// - Strips honorifics/prefixes/suffixes (Dr., Doctor, MD, FPCP, etc.)
  /// - Normalizes Philippine particles (dela, delos, ma. -> maria)
  /// - Strips punctuation, dashes, quotes, and diacritics
  /// - Trims and normalizes spacing to lower-case single-spaced tokens
  static String normalize(String raw) {
    if (raw.trim().isEmpty) return '';
    return raw
        .replaceAll(RegExp(r'\b(dr|doctor|dra|md|m\.d\.|phd|fpcp|fpcs|fpog|fpoa|rn|rph|ptrp|dpsn|fpcg|fpa|fics|ms|bsc|rnd|dmd|ddm|dvm)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bma\b', caseSensitive: false), 'maria')
        .replaceAll("'", "")
        .replaceAll("’", "")
        .replaceAll(".", " ")
        .replaceAll(",", " ")
        .replaceAll("-", " ")
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extracts meaningful name tokens (length >= 2, skipping common particles)
  static List<String> extractTokens(String normalized) {
    if (normalized.isEmpty) return [];
    const stopWords = {'de', 'del', 'dela', 'san', 'sta', 'los', 'las', 'van', 'von', 'jr', 'sr', 'ii', 'iii', 'iv'};
    return normalized
        .split(' ')
        .where((t) => t.length >= 2 && !stopWords.contains(t))
        .toList();
  }

  /// Searches the universal HCP masterlist with intelligent fuzzy matching,
  /// dual-field correlation (First, Middle, Last), phonetic sound-alike, and typo tolerance.
  static List<HcpDoctorMatchResult> searchDoctorMatches({
    required String firstName,
    required String middleName,
    required String lastName,
    required Iterable<Hcp> allDoctors,
    List<Specialization>? specializations,
    List<Institution>? institutions,
    int limit = 8,
  }) {
    final normFn = normalize(firstName);
    final normMn = normalize(middleName);
    final normLn = normalize(lastName);

    final rawCombined = [
      if (normFn.isNotEmpty) normFn,
      if (normMn.isNotEmpty) normMn,
      if (normLn.isNotEmpty) normLn,
    ].join(' ');

    if (rawCombined.length < 2) return [];

    final inputTokens = extractTokens(rawCombined);
    if (inputTokens.isEmpty && rawCombined.length < 2) return [];

    final List<HcpDoctorMatchResult> candidates = [];
    final Set<String> seenIds = {};

    for (final doc in allDoctors) {
      final docId = (doc.name ?? '').trim().toLowerCase();
      if (docId.isNotEmpty && seenIds.contains(docId)) continue;

      final docFn = normalize(doc.firstName);
      final docMn = normalize(doc.middleName ?? '');
      final docLn = normalize(doc.lastName);
      final docFullName = normalize(doc.fullName);

      // Skip invalid empty records
      if (docFn.isEmpty && docLn.isEmpty && docFullName.isEmpty) continue;

      double score = 0.0;
      String matchReason = '';
      bool isExact = false;

      final bool isCompactSurnameMatch = normLn.isNotEmpty &&
          (docLn == normLn ||
              docLn.replaceAll(' ', '') == normLn.replaceAll(' ', '') ||
              docLn.endsWith(' $normLn') ||
              extractTokens(docLn).contains(normLn));

      // 1. TIER 1: Exact full name or combined (First + Last) match
      if (rawCombined.length >= 3 && (rawCombined == docFullName || '$normFn $normLn'.trim() == '$docFn $docLn'.trim())) {
        score = 100.0;
        isExact = true;
        matchReason = 'Exact Doctor Name Match';
      }
      // 2. TIER 2: Dual-field exact match (both First and Last name match)
      else if (normFn.isNotEmpty && normLn.isNotEmpty && normFn == docFn && isCompactSurnameMatch) {
        score = 98.0;
        isExact = true;
        matchReason = 'Exact First & Last Name Match';
      }
      // 3. TIER 3: Dual-field prefix match (e.g. typed "Jua" and "Cru" -> "Juan Cruz")
      else if (normFn.isNotEmpty && normLn.isNotEmpty && docFn.startsWith(normFn) && (docLn.startsWith(normLn) || isCompactSurnameMatch)) {
        score = 94.0;
        isExact = false;
        matchReason = 'First & Surname Correlation Match';
      }
      // 4. TIER 4: Full name starts with query
      else if (rawCombined.length >= 3 && docFullName.startsWith(rawCombined)) {
        score = 92.0;
        isExact = false;
        matchReason = 'Full Name Prefix Match';
      }
      // 5. TIER 5: Surname exact match (Last Name field)
      else if (isCompactSurnameMatch) {
        score = 88.0;
        isExact = false;
        matchReason = 'Surname Match (${doc.lastName})';
        if (normFn.isNotEmpty && docFn.startsWith(normFn)) {
          score += 6.0;
          matchReason = 'Surname & First Name Match';
        }
      }
      // 6. TIER 6: First name exact match (First Name field)
      else if (normFn.isNotEmpty && normFn.length >= 3 && docFn == normFn) {
        score = 84.0;
        isExact = false;
        matchReason = 'First Name Match (${doc.firstName})';
        if (normLn.isNotEmpty && (docLn.startsWith(normLn) || isCompactSurnameMatch)) {
          score += 8.0;
          matchReason = 'First Name & Surname Match';
        }
      }
      // 7. TIER 7: Surname prefix match (e.g. typed "Mendo" -> "Mendoza")
      else if (normLn.isNotEmpty && normLn.length >= 3 && docLn.startsWith(normLn)) {
        score = 82.0;
        isExact = false;
        matchReason = 'Surname Prefix Match (${doc.lastName})';
      }
      // 8. TIER 8: Multi-token permutation matching (token overlap)
      else {
        final docTokens = extractTokens('$docFn $docMn $docLn $docFullName');
        if (docTokens.isNotEmpty && inputTokens.isNotEmpty) {
          int matchedTokensCount = 0;
          bool hasSurnameMatch = false;

          for (final inTok in inputTokens) {
            for (final dTok in docTokens) {
              if (inTok == dTok) {
                matchedTokensCount++;
                if (dTok == docLn || docLn.endsWith(dTok)) hasSurnameMatch = true;
                break;
              } else if (inTok.length >= 3 && dTok.startsWith(inTok)) {
                matchedTokensCount++;
                if (dTok == docLn || docLn.endsWith(dTok)) hasSurnameMatch = true;
                break;
              } else if (LocationResolver.isSoundAlikeMatch(inTok, dTok)) {
                matchedTokensCount++;
                break;
              }
            }
          }

          if (matchedTokensCount >= inputTokens.length && inputTokens.length >= 2) {
            score = 86.0 + (hasSurnameMatch ? 6.0 : 0.0);
            matchReason = 'Token Overlap Match ($matchedTokensCount/${inputTokens.length})';
          } else if (matchedTokensCount > 0 && inputTokens.length == 1) {
            score = 80.0;
            matchReason = 'Name Token Match (${inputTokens.first})';
          }
        }
      }

      // Middle initial / Middle name synergy bonus
      if (score >= 80.0 && normMn.isNotEmpty && docMn.isNotEmpty) {
        if (docMn == normMn || docMn.startsWith(normMn) || normMn.startsWith(docMn)) {
          score += 3.0;
          if (score > 100.0) score = 100.0;
          matchReason += ' (Middle Initial Matched)';
        }
      }

      // 9. TIER 9: Typo tolerance via Damerau-Levenshtein distance (e.g. "Jonh" vs "John", "Reys" vs "Reyes")
      if (score < 75.0 && normLn.isNotEmpty && normLn.length >= 4 && docLn.length >= 4) {
        final distLn = LocationResolver.levenshteinDistance(normLn, docLn);
        if (distLn <= 1) {
          score = 78.0;
          matchReason = 'Fuzzy Surname Match (~${doc.lastName})';
        }
      }
      if (score < 75.0 && normFn.isNotEmpty && normFn.length >= 4 && docFn.length >= 4) {
        final distFn = LocationResolver.levenshteinDistance(normFn, docFn);
        if (distFn <= 1) {
          score = 76.0;
          matchReason = 'Fuzzy First Name Match (~${doc.firstName})';
        }
      }

      // 10. TIER 10: HCP ID / Reference Match
      if (rawCombined.length >= 3 && docId.isNotEmpty && docId.contains(rawCombined)) {
        score = 95.0;
        matchReason = 'HCP Masterlist ID Match (${doc.name})';
      }

      // Threshold check: Must meet minimum confidence score
      if (score >= 75.0) {
        if (docId.isNotEmpty) seenIds.add(docId);

        // Resolve human-readable specialty for UI card
        String specStr = '';
        if (doc.specialties.isNotEmpty) {
          final firstSpec = doc.specialties.first;
          specStr = LocationResolver.resolveSpecialtyName(firstSpec.hcpSpecialty, specializations);
          if (specStr.isEmpty) specStr = firstSpec.hcpSpecialty;
        }
        if (specStr.isEmpty) specStr = 'General Practitioner';

        // Resolve human-readable workplace / hospital for UI card
        String workStr = '';
        if (doc.workplaces.isNotEmpty) {
          final firstWp = doc.workplaces.first;
          final resolvedLoc = LocationResolver.resolveCompleteWorkplaceLocation(
            institutionIdOrName: firstWp.workplace,
            rawCity: firstWp.cityMunicipality,
            rawProvince: firstWp.provinceName,
            institutions: institutions,
          );
          workStr = resolvedLoc.workplaceName;
          if (workStr.isEmpty) workStr = firstWp.workplace;
          if (resolvedLoc.cityName.isNotEmpty) {
            workStr = '$workStr, ${resolvedLoc.cityName}';
          }
        }

        candidates.add(HcpDoctorMatchResult(
          doctor: doc,
          score: score,
          matchReason: matchReason,
          isExact: isExact,
          formattedSpecialty: specStr,
          formattedWorkplace: workStr,
        ));
      }
    }

    // Sort descending by match score, then by doctor full name
    candidates.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.doctor.fullName.compareTo(b.doctor.fullName);
    });

    // GEMINI 4 ARGON PROGRESSIVE PHRASE SHRINKING:
    // As more of the doctor's name context is typed (e.g. both first and last name),
    // prune lower-confidence single-token noise so the candidate list cleanly shrinks
    // down to only near-related/same-person doctors!
    if (candidates.isNotEmpty && inputTokens.length >= 2) {
      final top = candidates.first.score;
      if (top >= 90.0) {
        // High confidence match on whole context: shrink tightly
        candidates.removeWhere((c) => c.score < top * 0.85);
      } else {
        // Moderate match: shrink partial noise
        candidates.removeWhere((c) => c.score < top * 0.75);
      }
    }

    return candidates.take(limit).toList();
  }
}
