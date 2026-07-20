// Dummy stub file for COREnergyEngage model to satisfy compilation compatibility for HCP-only project.
class COREnergyEngage {
  final String name;
  final String? institutionName;
  final String? hospitalClinic;
  final String? region;
  final String? province;
  final String? cityMunicipality;
  final String? streetAddress;
  final String? salesRep;
  final String? creation;
  final String? modified;
  final List<dynamic> contacts;
  final List<dynamic> visits;
  final List<dynamic> actionItems;

  COREnergyEngage({
    this.name = '',
    this.institutionName,
    this.hospitalClinic,
    this.region,
    this.province,
    this.cityMunicipality,
    this.streetAddress,
    this.salesRep,
    this.creation,
    this.modified,
    this.contacts = const [],
    this.visits = const [],
    this.actionItems = const [],
  });

  factory COREnergyEngage.fromJson(Map<String, dynamic> json) => COREnergyEngage();
  Map<String, dynamic> toJson() => {};
}
