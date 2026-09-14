import 'package:flutter/material.dart';

import 'group_trip.dart';
import 'theme.dart';

class CreatePlanWizard extends StatefulWidget {
  const CreatePlanWizard({super.key});

  @override
  State<CreatePlanWizard> createState() => _CreatePlanWizardState();
}

class _CreatePlanWizardState extends State<CreatePlanWizard> {
  int _step = 0;
  final _tripNameController = TextEditingController();
  final _destinationController = TextEditingController();
  final List<String> _travellers = ['James Chew'];
  double _budget = 3000;
  final Set<String> _interests = {};

  static const _interestOptions = [
    'Beach', 'City', 'Nature', 'Food', 'Adventure', 'Culture', 'Shopping', 'Nightlife', 'Relaxation',
  ];

  @override
  void dispose() {
    _tripNameController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    onPressed: () => _step == 0 ? Navigator.of(context).maybePop() : setState(() => _step--),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Let's Plan Your Trip", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      Text('Step ${_step + 1} of 3', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (_step + 1) / 3,
                  minHeight: 3,
                  backgroundColor: const Color(0xFFECECEC),
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _step,
                children: [
                  _basicInfoStep(),
                  _travellersStep(),
                  _budgetStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody({required String title, required String subtitle, required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }

  Widget _basicInfoStep() {
    return Column(
      children: [
        Expanded(
          child: _stepBody(
            title: 'Basic Trip Information',
            subtitle: 'Tell us the basic detail of your trip',
            children: [
              _labeledField('Trip Name', _tripNameController),
              const SizedBox(height: 16),
              _labeledField('Destination', _destinationController),
              const SizedBox(height: 16),
              _labeledField('Start Date', null, readOnly: true),
              const SizedBox(height: 16),
              _labeledField('End Date', null, readOnly: true),
            ],
          ),
        ),
        _continueButton(() => setState(() => _step = 1)),
      ],
    );
  }

  Widget _travellersStep() {
    return Column(
      children: [
        Expanded(
          child: _stepBody(
            title: "Who's travelling?",
            subtitle: 'Add your companions and preferences',
            children: [
              const Text('Travellers', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    ..._travellers.asMap().entries.map((e) => _travellerRow(e.key, e.value)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => setState(() => _travellers.add('James Chew')),
                      icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                      label: const Text('Add Travellers', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _continueButton(() => setState(() => _step = 2)),
      ],
    );
  }

  Widget _travellerRow(int index, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const CircleAvatar(radius: 16, backgroundColor: Color(0xFFFDFDE0)),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, color: Colors.black))),
          if (index == 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
              child: const Text('Owner', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
            )
          else
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: AppColors.textGrey),
              onPressed: () => setState(() => _travellers.removeAt(index)),
            ),
        ],
      ),
    );
  }

  Widget _budgetStep() {
    return Column(
      children: [
        Expanded(
          child: _stepBody(
            title: 'Budget Range',
            subtitle: 'Set your budget and interests',
            children: [
              const Text('Budget Range (per person)', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
              const SizedBox(height: 8),
              Center(child: Text('RM ${_budget.round()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black))),
              Slider(
                value: _budget,
                min: 500,
                max: 10000,
                divisions: 95,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.chipGrey,
                onChanged: (v) => setState(() => _budget = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('RM 500', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  Text('RM 10,000', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Interest Point', style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: _interestOptions.map((label) => _interestChip(label)).toList(),
              ),
            ],
          ),
        ),
        _continueButton(() {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              settings: const RouteSettings(name: GroupTripPage.routeName),
              builder: (_) => GroupTripPage(groupName: _tripNameController.text.isEmpty ? 'New Trip' : _tripNameController.text),
            ),
            (route) => route.isFirst,
          );
        }, label: 'Create Plan'),
      ],
    );
  }

  Widget _interestChip(String label) {
    final selected = _interests.contains(label);
    return GestureDetector(
      onTap: () => setState(() => selected ? _interests.remove(label) : _interests.add(label)),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.chipGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textGrey),
        ),
      ),
    );
  }

  Widget _labeledField(String label, TextEditingController? controller, {bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC))),
            suffixIcon: readOnly ? const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textGrey) : null,
          ),
        ),
      ],
    );
  }

  Widget _continueButton(VoidCallback onPressed, {String label = 'Continue'}) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onPressed,
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
