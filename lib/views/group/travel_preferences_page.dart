import 'package:flutter/material.dart';

import '../../controllers/create_plan_wizard_controller.dart' show CreatePlanWizardController;
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';

// ---------------------------------------------------------------------
// Travel Preferences — real, per-trip settings edited by any group member
// and shared by the whole group (reached from Group Setting). Replaces
// the old Profile > Travel Preferences screen, which only ever showed two
// hardcoded fake plans ("Japan Trips"/"Korea Trips") with fixed values
// that could never actually be changed. Everything here reads and writes
// the trip's own Firestore document.
// ---------------------------------------------------------------------
class TravelPreferencesPage extends StatelessWidget {
  final String tripId;
  const TravelPreferencesPage({super.key, required this.tripId});

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  static const _travelStyleOptions = ['Adventure', 'Relaxation', 'Culture', 'Balanced', 'Luxury', 'Budget'];
  static const _accommodationOptions = ['Hotel', 'Hostel', 'Homestay', 'Resort', 'Apartment'];
  static const _foodPreferenceOptions = ['No restrictions', 'Halal', 'Vegetarian', 'Vegan', 'Kosher', 'Gluten-free'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Travel Preferences', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: StreamBuilder<Trip?>(
        stream: TripRepository.instance.watchTrip(tripId, _uid),
        builder: (context, snapshot) {
          final trip = snapshot.data;
          if (trip == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('These preferences are shared by the whole group and help shape suggestions for this trip.',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4)),
              const SizedBox(height: 18),
              _navRow(context, 'Budget per Person', trip.budgetPerPerson > 0 ? 'RM ${trip.budgetPerPerson.toStringAsFixed(0)}' : 'Not set',
                  onTap: () => _editBudget(context, trip)),
              _navRow(context, 'Travel Style', trip.travelStyle.isEmpty ? 'Not set' : trip.travelStyle,
                  onTap: () => _pickSingle(context, title: 'Travel Style', options: _travelStyleOptions, current: trip.travelStyle,
                      onPicked: (v) => TripRepository.instance.updateSettings(tripId, travelStyle: v))),
              _navRow(context, 'Accommodation', trip.accommodation.isEmpty ? 'Not set' : trip.accommodation,
                  onTap: () => _pickSingle(context, title: 'Accommodation', options: _accommodationOptions, current: trip.accommodation,
                      onPicked: (v) => TripRepository.instance.updateSettings(tripId, accommodation: v))),
              _navRow(context, 'Food Preference', trip.foodPreference.isEmpty ? 'Not set' : trip.foodPreference,
                  onTap: () => _pickSingle(context, title: 'Food Preference', options: _foodPreferenceOptions, current: trip.foodPreference,
                      onPicked: (v) => TripRepository.instance.updateSettings(tripId, foodPreference: v))),
              const SizedBox(height: 18),
              const Text('Interests', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CreatePlanWizardController.interestOptions.map((label) {
                  final selected = trip.interests.contains(label);
                  return GestureDetector(
                    onTap: () {
                      final next = List<String>.from(trip.interests);
                      if (selected) {
                        next.remove(label);
                      } else {
                        next.add(label);
                      }
                      TripRepository.instance.updateSettings(tripId, interests: next);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.chipGrey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(label,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textGrey)),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _navRow(BuildContext context, String label, String value, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13.5, color: Colors.black)),
            const Spacer(),
            Flexible(
              child: Text(value, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, Trip trip) async {
    final budgetController = TextEditingController(text: trip.budgetPerPerson > 0 ? trip.budgetPerPerson.toStringAsFixed(0) : '');
    final result = await showNiceFormDialog(
      context: context,
      title: 'Budget per Person',
      headerIcon: Icons.savings_outlined,
      confirmLabel: 'Save',
      fieldsBuilder: (ctx, setState) => [
        niceDialogField(
          budgetController,
          'Budget per Person (RM)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
      ],
    );
    if (result != true) return;
    final parsed = double.tryParse(budgetController.text.trim());
    if (parsed == null || parsed < 0) return;
    await TripRepository.instance.updateSettings(tripId, budgetPerPerson: parsed);
  }

  /// A simple single-select bottom sheet — matches [GroupSettingPage]'s
  /// own notification-option picker rather than introducing a different
  /// look for the same "pick one of a few options" interaction.
  void _pickSingle(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onPicked,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
            ...options.map((option) {
              final selected = current == option;
              return ListTile(
                title: Text(option, style: const TextStyle(fontSize: 13.5)),
                trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  onPicked(option);
                  Navigator.of(sheetContext).pop();
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
