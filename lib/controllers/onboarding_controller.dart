import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/countries.dart';
import '../repositories/friends_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';

/// Controller for the post-registration onboarding wizard (Avatar → Phone
/// Number → Region/Country → Currency → Add Friend), shown once right
/// after email verification — see [OtpVerificationPage]. Every step is
/// individually skippable, and the whole wizard can be skipped too;
/// nothing collected here is required to use the app, so each step just
/// saves whatever was filled in and moves on rather than validating.
class OnboardingController extends ChangeNotifier {
  static const totalSteps = 5;

  int step = 0;
  void goToStep(int value) {
    step = value.clamp(0, totalSteps - 1);
    notifyListeners();
  }

  void next() => goToStep(step + 1);
  void back() => goToStep(step - 1);

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  // ---------------- Step 1: Avatar ----------------
  File? avatarFile;
  String? avatarUrl;
  bool uploadingAvatar = false;
  String? avatarError;

  Future<void> pickAvatar(ImageSource source) async {
    File? file;
    try {
      file = await AvatarService.instance.pick(source);
    } catch (_) {
      avatarError = "Couldn't open the picker on this device.";
      notifyListeners();
      return;
    }
    if (file == null) return;
    avatarFile = file;
    avatarError = null;
    uploadingAvatar = true;
    notifyListeners();
    try {
      final url = await AvatarService.instance.upload(_uid, file);
      avatarUrl = url;
      if (_uid.isNotEmpty) {
        await UserRepository.instance.updateProfile(_uid, avatarUrl: url);
      }
    } catch (e) {
      // Showing the raw error (not just a generic message) so it's
      // possible to tell a Storage permission/setup problem apart from a
      // platform-support problem without needing the debug console.
      avatarError = "Couldn't upload that photo: $e";
    } finally {
      uploadingAvatar = false;
      notifyListeners();
    }
  }

  // ---------------- Step 2: Phone number ----------------
  final phoneController = TextEditingController();
  bool savingPhone = false;

  Future<void> savePhoneAndNext() async {
    final phone = phoneController.text.trim();
    if (phone.isNotEmpty && _uid.isNotEmpty) {
      savingPhone = true;
      notifyListeners();
      await UserRepository.instance.updateProfile(_uid, phone: phone);
      savingPhone = false;
    }
    next();
  }

  // ---------------- Step 3: Region / Country ----------------
  Country? selectedCountry;
  bool savingCountry = false;

  void selectCountry(Country country) {
    selectedCountry = country;
    // Default the Currency step to match, but don't overwrite a choice
    // already made if they go back and forth between steps.
    selectedCurrency ??= country.currencyCode;
    notifyListeners();
  }

  Future<void> saveCountryAndNext() async {
    final country = selectedCountry;
    if (country != null && _uid.isNotEmpty) {
      savingCountry = true;
      notifyListeners();
      await UserRepository.instance.updateProfile(_uid, country: country.name);
      savingCountry = false;
    }
    next();
  }

  // ---------------- Step 4: Currency ----------------
  String? selectedCurrency;
  bool savingCurrency = false;

  void selectCurrency(String code) {
    selectedCurrency = code;
    notifyListeners();
  }

  Future<void> saveCurrencyAndNext() async {
    final currency = selectedCurrency;
    if (currency != null && _uid.isNotEmpty) {
      savingCurrency = true;
      notifyListeners();
      await UserRepository.instance.updateProfile(_uid, currencyCode: currency);
      savingCurrency = false;
    }
    next();
  }

  // ---------------- Step 5: Add a friend ----------------
  final friendQueryController = TextEditingController();
  bool addingFriend = false;
  String? addFriendMessage;

  Future<void> addFriend() async {
    final query = friendQueryController.text.trim();
    if (query.isEmpty || _uid.isEmpty) return;
    addingFriend = true;
    addFriendMessage = null;
    notifyListeners();
    final me = await UserRepository.instance.fetchProfile(_uid);
    final addedName = await FriendsRepository.instance.addFriend(myUid: _uid, myName: me?.name ?? 'Traveller', query: query);
    addingFriend = false;
    addFriendMessage = addedName != null ? 'Added $addedName as a friend!' : "Couldn't find anyone with that email or username.";
    if (addedName != null) friendQueryController.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    phoneController.dispose();
    friendQueryController.dispose();
    super.dispose();
  }
}
