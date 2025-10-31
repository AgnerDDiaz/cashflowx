import '../models/account.dart';
import '../services/exchange_rate_service.dart';

class TotalsCalculator {
  static Future<double> groupTotal(List<Account> accounts, String mainCurrency) async {
    double total = 0.0;
    for (final a in accounts) {
      if (a.visible == 1 && a.includeInBalance == 1) {
        total += await ExchangeRateService.localConvert(a.balance, a.currency, mainCurrency);
      }
    }
    return total;
  }

  static Future<(double inc, double exp, double total)> generalTotals(List<Account> all, String mainCurrency) async {
    double inc = 0.0; // saldos >=0
    double exp = 0.0; // saldos <0
    for (final a in all) {
      if (a.visible == 1 && a.includeInBalance == 1) {
        final v = await ExchangeRateService.localConvert(a.balance, a.currency, mainCurrency);
        if (v >= 0) inc += v; else exp += v;
      }
    }
    return (inc, exp, inc + exp);
  }
}