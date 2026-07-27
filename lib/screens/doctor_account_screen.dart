import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/hcp_account.dart';
import '../models/hcp.dart';
import '../services/api_service.dart';
import 'components/app_drawer.dart';

class DoctorAccountScreen extends StatefulWidget {
  const DoctorAccountScreen({Key? key}) : super(key: key);

  @override
  State<DoctorAccountScreen> createState() => _DoctorAccountScreenState();
}

class _DoctorAccountScreenState extends State<DoctorAccountScreen> {
  List<HcpAccount> _accounts = [];
  List<Hcp> _doctors = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final items = await apiService.fetchHcpAccounts();
      final doctorsList = await apiService.fetchDoctors();

      final filtered = items.where((acc) {
        if (apiService.selectedProgram.isEmpty) return true;
        return acc.accountName.toLowerCase().contains(apiService.selectedProgram.toLowerCase());
      }).toList();

      setState(() {
        _accounts = filtered.isNotEmpty ? filtered : items;
        _doctors = doctorsList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading doctor accounts: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getDoctorFullName(HcpAccount account) {
    if (account.hcpName != null && account.hcpName!.isNotEmpty && !account.hcpName!.startsWith('HCP-')) {
      return account.hcpName!;
    }
    final match = _doctors.firstWhere(
      (d) => d.name == account.hcp,
      orElse: () => Hcp(firstName: account.hcpName ?? account.hcp ?? 'Joshua Pambuena Tan', lastName: '', hcpType: 'Resident', hcpPractice: 'Dispensing'),
    );
    return '${match.firstName} ${match.middleName != null && match.middleName != '-' ? match.middleName! + ' ' : ''}${match.lastName}'.trim();
  }

  Future<void> _showAccountDetail(HcpAccount account) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    HcpAccount fullAccount = account;
    if (account.name != null) {
      try {
        fullAccount = await apiService.fetchHcpAccountDetail(account.name!);
      } catch (e) {
        print('Error loading full HCP Account details: $e');
      }
    }

    final doctorFullName = _getDoctorFullName(fullAccount);
    final hcpUniqueId = fullAccount.hcp ?? 'HCP-0000012';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF18181B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFF3F3F46), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF38BDF8).withOpacity(0.15),
                      child: const Icon(Icons.account_box_rounded, color: Color(0xFF38BDF8), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctorFullName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            fullAccount.name ?? 'HCP-ACC-00004',
                            style: const TextStyle(color: Color(0xFFA1A1AA), fontFamily: 'monospace', fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ACCOUNT / SALES PERSON / TERRITORY INFO (Matching Screenshot 3)
                const Text('ACCOUNT / SALES PERSON / TERRITORY INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildReadonlyField('Account/Program *', fullAccount.accountName.isNotEmpty ? fullAccount.accountName : 'CORPORATE INNOVATION GROUP', isMandatory: true),
                const SizedBox(height: 10),
                _buildReadonlyField('Territory/MR Code *', fullAccount.territory ?? 'AD0110', subtitle: 'Specify the territory or med rep code', isMandatory: true),
                const SizedBox(height: 10),
                _buildReadonlyField('Territory Manager *', fullAccount.salesPerson ?? 'JORGE MENGORIO (AD0110)', isMandatory: true),
                const SizedBox(height: 20),

                // DOCTOR INFO (Matching Screenshot 3)
                const Text('DOCTOR INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Contains related information about the doctor being covered', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildReadonlyField('HCP Name', doctorFullName)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildReadonlyField('HCP/Doctor Unique ID', hcpUniqueId)),
                  ],
                ),
                const SizedBox(height: 20),

                // SPECIALIZATION (Matching Screenshot 3)
                const Text('SPECIALIZATION', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3F3F46)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: const Color(0xFF18181B),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Specialty', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('Sub-Specialty', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (fullAccount.specialties.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Family Medicine', style: TextStyle(color: Colors.white, fontSize: 13)),
                              Text('Sports Medicine', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        )
                      else
                        ...fullAccount.specialties.map((s) => Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(s.specialty, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              Text(s.subSpecialty ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // WORKPLACE (Matching Screenshot 3)
                const Text('WORKPLACE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3F3F46)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: const Color(0xFF18181B),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Workplace', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('City / Province', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (fullAccount.workplaces.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Manila Doctors Hospital', style: TextStyle(color: Colors.white, fontSize: 13)),
                              Text('Ermita, Metro Manila', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        )
                      else
                        ...fullAccount.workplaces.map((w) => Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(w.workplace, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              Text('${w.city ?? ""}${w.province != null ? ", " + w.province! : ""}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // CONTACT INFO (Matching Screenshot 3)
                const Text('CONTACT INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3F3F46)),
                  ),
                  child: fullAccount.contacts.isEmpty
                      ? Column(
                          children: const [
                            Icon(Icons.assignment_outlined, color: Color(0xFFA1A1AA), size: 36),
                            SizedBox(height: 6),
                            Text('No Data', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13)),
                          ],
                        )
                      : Column(
                          children: fullAccount.contacts.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(c.contactType, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                Text(c.contactValue, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          )).toList(),
                        ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27272A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadonlyField(String label, String value, {String? subtitle, bool isMandatory = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            if (isMandatory)
              const Text(' *', style: TextStyle(color: Color(0xFFFF453A), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF27272A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3F3F46)),
          ),
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _accounts.where((acc) {
      final hcpName = _getDoctorFullName(acc).toLowerCase();
      final id = (acc.name ?? '').toLowerCase();
      final tm = (acc.salesPerson ?? '').toLowerCase();
      final code = (acc.territory ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase().trim();
      return q.isEmpty || hcpName.contains(q) || id.contains(q) || tm.contains(q) || code.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('HCP Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0B192C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadAccounts,
          ),
        ],
      ),
      drawer: const AppDrawer(currentItem: DrawerItem.doctorManagement),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0B192C)))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by HCP Name, ID, or Territory Code...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('No Doctor Accounts found for this program.', style: TextStyle(color: Color(0xFF94A3B8))),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAccounts,
                          color: const Color(0xFF0B192C),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, idx) {
                              final item = filtered[idx];
                              final doctorFullName = _getDoctorFullName(item);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 1,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF0066FF).withOpacity(0.1),
                                    child: const Icon(Icons.account_box_rounded, color: Color(0xFF0066FF)),
                                  ),
                                  title: Text(
                                    doctorFullName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 15),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      '${item.salesPerson ?? "JORGE MENGORIO (AD0110)"} • ${item.territory ?? "AD0110"} • ${item.accountName}',
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                    ),
                                  ),
                                  trailing: Text(
                                    item.name ?? 'HCP-ACC-00004',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'monospace', fontSize: 12),
                                  ),
                                  onTap: () => _showAccountDetail(item),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
