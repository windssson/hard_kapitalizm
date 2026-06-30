class AppMoney {
  static const String currencySymbol = '₺';

  static String compact(
    num? amount, {
    bool withSymbol = true,
    bool signed = false,
  }) {
    final value = (amount ?? 0).toDouble();
    final absolute = value.abs();

    String formatted;
    if (absolute >= 1000000000) {
      formatted = '${_trimZeros((absolute / 1000000000).toStringAsFixed(1))}B';
    } else if (absolute >= 1000000) {
      formatted = '${_trimZeros((absolute / 1000000).toStringAsFixed(1))}M';
    } else if (absolute >= 1000) {
      formatted = '${_trimZeros((absolute / 1000).toStringAsFixed(1))}K';
    } else {
      formatted = absolute.toStringAsFixed(0);
    }

    return '${_prefix(value, withSymbol: withSymbol, signed: signed)}$formatted';
  }

  static String full(
    num? amount, {
    int decimals = 0,
    bool withSymbol = true,
    bool signed = false,
  }) {
    final value = (amount ?? 0).toDouble();
    final absolute = value.abs();
    final fixed = absolute.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final whole = _groupThousands(parts.first);
    final decimalPart = decimals > 0 ? ',${parts[1]}' : '';
    return '${_prefix(value, withSymbol: withSymbol, signed: signed)}$whole$decimalPart';
  }

  static String _prefix(
    double value, {
    required bool withSymbol,
    required bool signed,
  }) {
    final sign = value < 0
        ? '-'
        : signed && value > 0
        ? '+'
        : '';
    final symbol = withSymbol ? currencySymbol : '';
    return '$sign$symbol';
  }

  static String _trimZeros(String value) {
    if (!value.contains('.')) return value;
    return value.replaceFirst(RegExp(r'\.0$'), '');
  }

  static String _groupThousands(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final reverseIndex = digits.length - i;
      buffer.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }
}
