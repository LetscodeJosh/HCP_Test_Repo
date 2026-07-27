import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/hcp_account.dart';
import '../services/api_service.dart';
import 'components/app_drawer.dart';

class DoctorAccountScreen extends StatefulWidget {
  const DoctorAccountScreen({Key? key}) : super(key: key);

  @override
  State<DoctorAccountScreen> createState() => _DoctorAccountScreenState();
}

class _DoctorAccountScreenState extends State<DoctorAccountScreen> {
  List<HcpAccount> _accounts = [];
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
      final items = await apiService.hcpAccounts.list(
        filters: [['account_or_program', '=', apiService.selectedProgram]],
        limit: 1000,
      );
      setState(() {
        _accounts = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showAccountDetail(HcpAccount account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF0066FF).withOpacity(0.1),
                    child: const Icon(Icons.account_box_rounded, color: Color(0xFF0066FF), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.hcp ?? 'Doctor Account',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          account.name ?? '',
                          style: const TextStyle(color: Color(0xFF64748B), fontFamily: 'monospace', fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('HCP Account Details', style: TextStyle(color: Color(0xFF0066FF), fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _detailRow('Account / Program', account.accountName),
              _detailRow('Territory', account.territory ?? 'All Territories'),
              _detailRow('Territory Manager / Sales Person', account.salesPerson ?? 'Unassigned'),
              _detailRow('Account Type', account.accountType ?? 'Standard'),
              _detailRow('Status', account.isActive ? 'Active' : 'Inactive'),

              if (account.specialties.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Specialties', style: TextStyle(color: Color(0xFF0066FF), fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...account.specialties.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text('• ${s.specialty} ${s.subSpecialty != null ? "(${s.subSpecialty})" : ""}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14)),
                )),
              ],

              if (account.workplaces.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Workplaces', style: TextStyle(color: Color(0xFF0066FF), fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...account.workplaces.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text('• ${w.workplace}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14)),
                )),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B192C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _accounts.where((acc) {
      final hcp = (acc.hcp ?? '').toLowerCase();
      final name = (acc.name ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase().trim();
      return q.isEmpty || hcp.contains(q) || name.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Doctor Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                      hintText: 'Search by Doctor or Account ID...',
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
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 1,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF0066FF).withOpacity(0.1),
                                    child: const Icon(Icons.account_box_rounded, color: Color(0xFF0066FF)),
                                  ),
                                  title: Text(
                                    item.hcp ?? 'Doctor Account',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  subtitle: Text(
                                    '${item.accountName} • ${item.territory ?? "All Territories"}',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  ),
                                  trailing: Text(
                                    item.name ?? '',
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
