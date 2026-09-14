import 'package:flutter/material.dart';

import '../../controllers/create_plan_wizard_controller.dart';
import '../../repositories/friends_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../group/group_trip_page.dart';

class CreatePlanWizard extends StatefulWidget {
  const CreatePlanWizard({super.key});

  @override
  State<CreatePlanWizard> createState() => _CreatePlanWizardState();
}

class _CreatePlanWizardState extends State<CreatePlanWizard> {
  final CreatePlanWizardController controller = CreatePlanWizardController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                      onPressed: () => controller.step == 0 ? Navigator.of(context).maybePop() : controller.back(),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Let's Plan Your Trip", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        Text('Step ${controller.step + 1} of 3', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
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
                    value: (controller.step + 1) / 3,
                    minHeight: 3,
                    backgroundColor: const Color(0xFFECECEC),
                    color: AppColors.primary,
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: controller.step,
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
              _labeledField('Trip Name', controller.tripNameController),
              const SizedBox(height: 16),
              _labeledField('Destination', controller.destinationController),
              const SizedBox(height: 16),
              _dateField('Start Date', controller.startDate, _pickStartDate),
              const SizedBox(height: 16),
              _dateField('End Date', controller.endDate, _pickEndDate),
            ],
          ),
        ),
        _continueButton(() => controller.goToStep(1)),
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
                    _ownerRow(),
                    ...controller.travellers.asMap().entries.map((e) => _travellerRow(e.key, e.value.name)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _openFriendPicker,
                      icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                      label: const Text('Add Travellers', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _continueButton(() => controller.goToStep(2)),
      ],
    );
  }

  Widget _ownerRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const CircleAvatar(radius: 16, backgroundColor: Color(0xFFFDFDE0)),
          const SizedBox(width: 12),
          Expanded(child: Text(controller.ownerName, style: const TextStyle(fontSize: 14, color: Colors.black))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
            child: const Text('Owner', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
          ),
        ],
      ),
    );
  }

  Widget _travellerRow(int index, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9)),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, color: Colors.black))),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textGrey),
            onPressed: () => controller.removeTravellerAt(index),
          ),
        ],
      ),
    );
  }

  Future<void> _openFriendPicker() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StreamBuilder<List<FriendEntry>>(
        stream: FriendsRepository.instance.watchFriends(uid),
        builder: (context, snapshot) {
          final friends = snapshot.data ?? const [];
          return AnimatedBuilder(
            animation: controller,
            builder: (context, _) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add travellers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 8),
                    if (friends.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No friends yet — add some from Profile > Friends first.',
                            style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
                      )
                    else
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: friends.map((f) {
                            final added = controller.travellers.any((t) => t.uid == f.uid);
                            return CheckboxListTile(
                              value: added,
                              activeColor: AppColors.primary,
                              secondary: const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9)),
                              title: Text(f.name, style: const TextStyle(fontSize: 13.5)),
                              onChanged: (checked) {
                                if (checked == true) {
                                  controller.addTraveller(f);
                                } else {
                                  final idx = controller.travellers.indexWhere((t) => t.uid == f.uid);
                                  if (idx != -1) controller.removeTravellerAt(idx);
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.startDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) controller.setStartDate(picked);
  }

  Future<void> _pickEndDate() async {
    final base = controller.startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.endDate ?? base,
      firstDate: base,
      lastDate: base.add(const Duration(days: 730)),
    );
    if (picked != null) controller.setEndDate(picked);
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
              Center(child: Text('RM ${controller.budget.round()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black))),
              Slider(
                value: controller.budget,
                min: 500,
                max: 10000,
                divisions: 95,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.chipGrey,
                onChanged: controller.setBudget,
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
                children: CreatePlanWizardController.interestOptions.map((label) => _interestChip(label)).toList(),
              ),
            ],
          ),
        ),
        _continueButton(_createPlan, label: controller.creating ? 'Creating...' : 'Create Plan'),
      ],
    );
  }

  Future<void> _createPlan() async {
    if (controller.creating) return;
    try {
      final tripId = await controller.createTrip();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: GroupTripPage.routeName),
          builder: (_) => GroupTripPage(tripId: tripId),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create trip: $e')));
    }
  }

  Widget _interestChip(String label) {
    final selected = controller.interests.contains(label);
    return GestureDetector(
      onTap: () => controller.toggleInterest(label),
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

  Widget _labeledField(String label, TextEditingController? textController, {bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
        const SizedBox(height: 8),
        TextField(
          controller: textController,
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

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    final text = value == null
        ? ''
        : '${value.day}/${value.month}/${value.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFECECEC)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(text.isEmpty ? 'Select date' : text,
                    style: TextStyle(fontSize: 13.5, color: text.isEmpty ? AppColors.textGrey : Colors.black)),
                const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textGrey),
              ],
            ),
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
