import 'package:flutter/material.dart';

import '../../theme.dart';

enum PaymentMethodOption { card, paypal }

/// Shared by payment_method_page.dart (insurance) and booking_payment_page.dart
/// (flight/hotel) -- the same two real payment rails, selectable the same
/// way, on every purchase flow in the app. Previously each page either had
/// no picker at all (flight/hotel) or a single hardcoded, non-selectable
/// "Credit / Debit Card" row (insurance); this replaces both with one real
/// choice between Stripe (card) and PayPal.
class PaymentMethodPicker extends StatelessWidget {
  final PaymentMethodOption value;
  final ValueChanged<PaymentMethodOption> onChanged;
  const PaymentMethodPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _tile(
          option: PaymentMethodOption.card,
          icon: Icons.credit_card,
          label: 'Credit / Debit Card',
          sublabel: 'Paid securely via Stripe',
        ),
        const SizedBox(height: 10),
        _tile(
          option: PaymentMethodOption.paypal,
          icon: Icons.account_balance_wallet_outlined,
          label: 'PayPal',
          sublabel: 'Log in to your PayPal account to pay',
        ),
      ],
    );
  }

  Widget _tile({
    required PaymentMethodOption option,
    required IconData icon,
    required String label,
    required String sublabel,
  }) {
    final selected = value == option;
    return GestureDetector(
      onTap: () => onChanged(option),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFECECEC),
            width: selected ? 1.5 : 1,
          ),
          color: selected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textGrey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.primary : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(sublabel, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? AppColors.primary : AppColors.textGrey,
            ),
          ],
        ),
      ),
    );
  }
}
