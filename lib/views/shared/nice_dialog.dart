import 'package:flutter/material.dart';

import '../../theme.dart';

/// Shared "nice" form-dialog chrome, used across the app in place of
/// Flutter's plain default `AlertDialog` + underlined `TextField`s: a
/// rounded card, an icon-in-a-circle header with a close (X) button,
/// filled no-underline fields (see [niceDialogField]), and a two-button
/// Cancel/Confirm footer matching the rest of the app's pill-shaped
/// primary-button language.
///
/// [fieldsBuilder] is handed a [StateSetter] so a dialog that needs its
/// own local state (a star picker, an icon picker, ...) can still rebuild
/// just its own content, the same way [StatefulBuilder] normally would.
Future<bool?> showNiceFormDialog({
  required BuildContext context,
  required String title,
  required IconData headerIcon,
  required List<Widget> Function(BuildContext ctx, StateSetter setState) fieldsBuilder,
  String confirmLabel = 'Add',
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(headerIcon, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: const Icon(Icons.close, size: 20, color: AppColors.textGrey),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...fieldsBuilder(ctx, setState),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A single filled, rounded field for [showNiceFormDialog] — no underline,
/// a soft grey fill, and an optional leading icon, in place of the default
/// Material [TextField] underline look.
Widget niceDialogField(
  TextEditingController controller,
  String label, {
  IconData? icon,
  TextInputType? keyboardType,
  String? prefixText,
  bool autofocus = false,
  int maxLines = 1,
  bool readOnly = false,
  VoidCallback? onTap,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontSize: 13.5, color: AppColors.navy, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        prefixIcon: icon == null ? null : Icon(icon, size: 18, color: AppColors.textGrey),
        suffixIcon: onTap == null ? null : const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textGrey),
        labelStyle: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
        filled: true,
        fillColor: AppColors.chipGrey,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    ),
  );
}

/// Same filled look as [niceDialogField], but with a filter-as-you-type
/// dropdown of [options] underneath — used for the "Add Flight" dialog's
/// Airline field so the person can pick from a list instead of having to
/// type an airline name out exactly.
Widget niceAutocompleteField(
  TextEditingController controller,
  String label, {
  required List<String> options,
  IconData? icon,
  bool autofocus = false,
  FocusNode? focusNode,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: RawAutocomplete<String>(
      textEditingController: controller,
      // A caller inside a dialog's `fieldsBuilder` should pass its own
      // FocusNode created once outside the builder (the builder re-runs on
      // every setState, e.g. picking a date in a sibling field) — creating
      // a fresh FocusNode here on every rebuild would make RawAutocomplete
      // detach/reattach focus each time and silently drop the keyboard.
      focusNode: focusNode ?? FocusNode(),
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return options.where((o) => o.toLowerCase().contains(q)).take(6);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          autofocus: autofocus,
          style: const TextStyle(fontSize: 13.5, color: AppColors.navy, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon == null ? null : Icon(icon, size: 18, color: AppColors.textGrey),
            suffixIcon: const Icon(Icons.expand_more, size: 18, color: AppColors.textGrey),
            labelStyle: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
            filled: true,
            fillColor: AppColors.chipGrey,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, suggestions) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, i) {
                  final option = suggestions.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Text(option, style: const TextStyle(fontSize: 13, color: AppColors.navy)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// A row of 5 large tappable stars for picking a 1-5 rating inside a
/// [showNiceFormDialog] `fieldsBuilder` — pair with the builder's
/// [StateSetter] so tapping a star actually redraws the row.
Widget niceStarPicker({required int rating, required ValueChanged<int> onChanged}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(filled ? Icons.star : Icons.star_border, size: 32, color: filled ? AppColors.orange : AppColors.textGrey),
          ),
        );
      }),
    ),
  );
}

/// A single-button info/success dialog — replaces a plain default
/// `AlertDialog` for "here's what happened, tap to continue" moments
/// (email sent, payment confirmed, booking added) with the same
/// rounded-card, icon-in-a-circle language as [showNiceFormDialog], just
/// with no input fields and one wide confirm button instead of a
/// Cancel/Confirm pair.
Future<void> showNiceInfoDialog({
  required BuildContext context,
  required String title,
  required String message,
  IconData icon = Icons.check_circle,
  Color iconColor = Colors.green,
  String buttonLabel = 'Done',
  VoidCallback? onDone,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onDone?.call();
                },
                child: Text(buttonLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A Cancel/Confirm confirmation dialog — replaces a plain default
/// `AlertDialog` for "are you sure?" moments (leave group, remove member,
/// delete account, log out). [destructive] switches the icon and confirm
/// button to red for actions that can't be undone; returns `true` only if
/// the person actually tapped confirm (never `null`, so callers can use it
/// directly in an `if`).
Future<bool> showNiceConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (destructive ? Colors.redAccent : AppColors.primary).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: destructive ? Colors.redAccent : AppColors.primary, size: 28),
            ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.4)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(cancelLabel, style: const TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: destructive ? Colors.redAccent : AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
