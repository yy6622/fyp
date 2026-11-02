import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/countries.dart';
import '../repositories/friends_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';

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
    final outcome = await FriendsRepository.instance.sendFriendRequest(myUid: _uid, myName: me?.name ?? 'Traveller', query: query);
    addingFriend = false;
    addFriendMessage = switch (outcome.status) {
      FriendRequestStatus.sent => 'Friend request sent to ${outcome.name}!',
      FriendRequestStatus.autoAccepted => '${outcome.name} had already requested you — you\'re now friends!',
      FriendRequestStatus.alreadyFriends => 'You and ${outcome.name} are already friends.',
      FriendRequestStatus.alreadyRequested => 'Friend request to ${outcome.name} is already pending.',
      FriendRequestStatus.isSelf => "That's your own account.",
      FriendRequestStatus.noMatch => "Couldn't find anyone with that email or username.",
    };
    if (outcome.status != FriendRequestStatus.noMatch && outcome.status != FriendRequestStatus.isSelf) {
      friendQueryController.clear();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    phoneController.dispose();
    friendQueryController.dispose();
    super.dispose();
  }
}
