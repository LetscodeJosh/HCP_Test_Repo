import 'package:flutter/material.dart';
import '../models/corenergy_engage.dart';
import '../models/lookup_models.dart';

// Dummy stub widget for COREnergyEngageDetailScreen to satisfy compilation compatibility for HCP-only project.
class COREnergyEngageDetailScreen extends StatefulWidget {
  final COREnergyEngage? engage;
  final List<Institution> institutions;
  final List<String> salesReps;
  final List<PsgcLocation> psgcLocations;

  const COREnergyEngageDetailScreen({
    Key? key,
    this.engage,
    required this.institutions,
    required this.salesReps,
    required this.psgcLocations,
  }) : super(key: key);

  @override
  State<COREnergyEngageDetailScreen> createState() => _COREnergyEngageDetailScreenState();
}

class _COREnergyEngageDetailScreenState extends State<COREnergyEngageDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('COREnergy Engage Detail Screen Stub'),
      ),
    );
  }
}
