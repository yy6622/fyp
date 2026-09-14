import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/onboarding_controller.dart';
import '../../data/countries.dart';
import '../../theme.dart';
import '../auth/auth_widgets.dart';
import '../shared/bottom_nav.dart';

// ---------------------------------------------------------------------
// Post-registration onboarding — Avatar / Phone / Region & Country /
// Currency / Add Friend, one page at a time (same step-wizard shape as
// [CreatePlanWizard]: header + progress bar + IndexedStack). Shown once
// right after email verification (see OtpVerificationPage). Every step,
// and the wizard as a whole, can be skipped — nothing collected here is
// required to use the app.
//
// SETUP REQUIRED for the Avatar step to actually work: this project has no
// image-upload package wired in yet. Run
//   flutter pub add image_picker firebase_storage
// then deploy the new storage.rules:
//   firebase deploy --only storage
// Until both are done, this file won't compile.
// ---------------------------------------------------------------------
class OnboardingWizardPage extends StatefulWidget {
  const OnboardingWizardPage({super.key});

  @override
  State<OnboardingWizardPage> createState() => _OnboardingWizardPageState();
}

class _OnboardingWizardPageState extends State<OnboardingWizardPage> {
  final OnboardingController controller = OnboardingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainPage()),
      (route) => false,
    );
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
              _header(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (controller.step + 1) / OnboardingController.totalSteps,
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
                    _avatarStep(),
                    _phoneStep(),
                    _countryStep(),
                    _currencyStep(),
                    _addFriendStep(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.navy),
            onPressed: () => controller.step == 0 ? Navigator.of(context).maybePop() : controller.back(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set Up Your Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
                Text('Step ${controller.step + 1} of ${OnboardingController.totalSteps}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
          TextButton(
            onPressed: _finish,
            child: const Text('Skip for now', style: TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
          ),
        ],
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

  Widget _bottomButtons({required VoidCallback onSkip, required VoidCallback? onContinue, String continueLabel = 'Continue'}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDDDDDD)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onSkip,
              child: const Text('Skip', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onContinue,
              child: Text(continueLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ================= Step 1: Avatar =================
  Widget _avatarStep() {
    return Column(
      children: [
        Expanded(
          child: _stepBody(
            title: 'Add a profile photo',
            subtitle: 'Help your travel friends recognise you — you can always change this later.',
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.chipGrey,
                      backgroundImage: controller.avatarUrl != null ? NetworkImage(controller.avatarUrl!) : null,
                      child: controller.uploadingAvatar
                          ? const CircularProgressIndicator(color: AppColors.primary)
                          : (controller.avatarUrl == null ? const Icon(Icons.person, size: 48, color: AppColors.textGrey) : null),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.avatarError != null) ...[
                const SizedBox(height: 12),
                Text(controller.avatarError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: Colors.redAccent)),
              ],
              const SizedBox(height: 28),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: controller.uploadingAvatar ? null : () => controller.pickAvatar(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18, color: AppColors.primary),
                label: const Text('Choose from Gallery', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: controller.uploadingAvatar ? null : () => controller.pickAvatar(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.primary),
                label: const Text('Take a Photo', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        _bottomButtons(onSkip: () => controller.next(), onContinue: () => controller.next()),
      ],
    );
  }

  // ================= Step 2: Phone number =================
  Widget _phoneStep() {
    return Column(
      children: [
        Expanded(
          child: _stepBody(
            title: "What's your phone number?",
            subtitle: 'Used for booking confirmations and trip updates.',
            children: [
              AuthTextField(hint: 'Phone Number', controller: controller.phoneController),
            ],
          ),
        ),
        _bottomButtons(onSkip: () => controller.next(), onContinue: controller.savingPhone ? null : () => controller.savePhoneAndNext()),
      ],
    );
  }

  // ================= Step 3: Region / Country =================
  Widget _countryStep() {
    return Column(
      children: [
        Expanded(
          child: _stepBody(
            title: 'Where are you based?',
            subtitle: 'This helps us tailor suggestions to your region.',
            children: kCountries
                .map((c) => _pickTile(
                      label: c.name,
                      trailing: c.currencyCode,
                      selected: controller.selectedCountry?.code == c.code,
                      onTap: () => controller.selectCountry(c),
                    ))
                .toList(),
          ),
        ),
        _bottomButtons(
          onSkip: () => controller.next(),
          onContinue: controller.savingCountry ? null : () => controller.saveCountryAndNext(),
        ),
      ],
    );
  }

  // ================= Step 4: Currency =================
  Widget _currencyStep() {
    return Column(
      children: [
        Expanded(
          child: _stepBody(
            title: 'Preferred currency',
            subtitle: 'Trip budgets and prices will be shown using this.',
            children: kCurrencies
                .map((c) => _pickTile(
                      label: c.code,
                      trailing: c.symbol,
                      selected: controller.selectedCurrency == c.code,
                      onTap: () => controller.selectCurrency(c.code),
                    ))
                .toList(),
          ),
        ),
        _bottomButtons(
          onSkip: () => controller.next(),
          onContinue: controller.savingCurrency ? null : () => controller.saveCurrencyAndNext(),
        ),
      ],
    );
  }

  // ================= Step 5: Add a friend =================
  Widget _addFriendStep() {
    return Column(
      children: [
        Expanded(
          child: _stepBody(
            title: 'Add your first friend',
            subtitle: 'Search by their email or username — you can always add more later from Profile.',
            children: [
              Row(
                children: [
                  Expanded(child: AuthTextField(hint: 'Email or username', controller: controller.friendQueryController)),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: controller.addingFriend ? null : () => controller.addFriend(),
                      child: controller.addingFriend
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              if (controller.addFriendMessage != null) ...[
                const SizedBox(height: 12),
                Text(controller.addFriendMessage!, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
              ],
            ],
          ),
        ),
        _bottomButtons(onSkip: _finish, onContinue: _finish, continueLabel: 'Done'),
      ],
    );
  }

  Widget _pickTile({required String label, required String trailing, required bool selected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
            border: Border.all(color: selected ? AppColors.primary : const Color(0xFFECECEC)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : Colors.black)),
              ),
              Text(trailing, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
              const SizedBox(width: 8),
              Icon(selected ? Icons.check_circle : Icons.circle_outlined, size: 18, color: selected ? AppColors.primary : const Color(0xFFDDDDDD)),
            ],
          ),
        ),
      ),
    );
  }
}
