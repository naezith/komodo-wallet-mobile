import 'package:rational/rational.dart';
import 'package:komodo_dex/blocs/coins_bloc.dart';
import 'package:komodo_dex/blocs/main_bloc.dart';
import 'package:komodo_dex/blocs/swap_bloc.dart';
import 'package:komodo_dex/localizations.dart';
import 'package:komodo_dex/model/coin_balance.dart';
import 'package:komodo_dex/model/orderbook.dart';
import 'package:komodo_dex/model/trade_preimage.dart';
import 'package:komodo_dex/screens/dex/trade/trade_form.dart';
import 'package:komodo_dex/utils/utils.dart';

class TradeFormValidator {
  final CoinBalance sellBalance = swapBloc.sellCoinBalance;
  final CoinBalance receiveBalance = swapBloc.receiveCoinBalance;
  final double amountSell = swapBloc.amountSell;
  final double amountReceive = swapBloc.amountReceive;
  final Ask matchingBid = swapBloc.matchingBid;
  final AppLocalizations appLocalizations = AppLocalizations();

  Future<String> get errorMessage async {
    final String message = _validateNetwork() ??
        _validateMaxTakerVolume() ??
        _validateMinValues() ??
        await _validateGas();
    return message;
  }

  String _validateNetwork() {
    if (mainBloc.isNetworkOffline) {
      return appLocalizations.noInternet;
    } else {
      return null;
    }
  }

  String _validateMaxTakerVolume() {
    if (swapBloc.matchingBid != null &&
        swapBloc.maxTakerVolume == Rational.parse('0')) {
      return '${swapBloc.sellCoinBalance.coin.abbr} balance not suffisient'
          ' to pay trading fee';
    }

    return null;
  }

  String _validateMinValues() {
    final double minVolumeSell =
        tradeForm.minVolumeDefault(swapBloc.sellCoinBalance.coin.abbr);
    final double minVolumeReceive =
        tradeForm.minVolumeDefault(swapBloc.receiveCoinBalance.coin.abbr);

    if (amountSell > 0 && amountSell < minVolumeSell) {
      return appLocalizations.minValue(
          swapBloc.sellCoinBalance.coin.abbr, '$minVolumeSell');
    } else if (amountReceive > 0 && amountReceive < minVolumeReceive) {
      return appLocalizations.minValueBuy(
          swapBloc.receiveCoinBalance.coin.abbr, '$minVolumeReceive');
    } else if (matchingBid != null && matchingBid.minVolume != null) {
      if (amountReceive < matchingBid.minVolume) {
        return appLocalizations.minValueBuy(
            swapBloc.receiveCoinBalance.coin.abbr,
            cutTrailingZeros(formatPrice(matchingBid.minVolume)));
      }
      return null;
    } else {
      return null;
    }
  }

  Future<String> _validateGas() async {
    return await validateGasFor(
            swapBloc.sellCoinBalance.coin.abbr, swapBloc.tradePreimage) ??
        await validateGasFor(
            swapBloc.receiveCoinBalance.coin.abbr, swapBloc.tradePreimage);
  }

  Future<String> validateGasFor(String coin, TradePreimage preimage) async {
    final String gasCoin = coinsBloc.getCoinByAbbr(coin)?.payGasIn;
    if (gasCoin == null) return null;

    if (!coinsBloc.isCoinActive(gasCoin)) {
      return appLocalizations.swapGasActivate(gasCoin);
    }

    if (preimage == null) {
      // If gas coin is active, but api wasn't able to
      // generate tradePreimage, we assume
      // that gas coin ballance is insufficient.
      // TBD: refactor when 'trade_preimage' will return detailed error
      return appLocalizations.swapGasAmount(gasCoin);
    } else {
      final CoinFee totalGasFee = preimage.totalFees
          .firstWhere((item) => item.coin == gasCoin, orElse: () => null);
      if (totalGasFee != null) {
        final double totalGasAmount =
            double.tryParse(totalGasFee.amount ?? '0') ?? 0;
        final double gasBalance =
            coinsBloc.getBalanceByAbbr(gasCoin).balance.balance.toDouble();
        if (totalGasAmount > gasBalance) {
          return appLocalizations.swapGasAmount(
              gasCoin, cutTrailingZeros(formatPrice(totalGasAmount, 4)));
        }
      }
    }

    return null;
  }
}
