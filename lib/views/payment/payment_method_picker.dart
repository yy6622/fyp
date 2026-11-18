import 'package:flutter/material.dart';

import '../../theme.dart';

enum PaymentMethodOption { card, paypal }

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
        ),
        const SizedBox(height: 10),
        _tile(
          option: PaymentMethodOption.paypal,
          icon: Icons.account_balance_wallet_outlined,
          label: 'PayPal',
        ),
      ],
    );
  }

  Widget _tile({
    required PaymentMethodOption option,
    required IconData icon,
    required String label,
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
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : Colors.black,
                ),
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
