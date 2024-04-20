import 'package:flutter/material.dart';
import 'package:mrt_wallet/app/core.dart';
import 'package:mrt_wallet/future/pages/start_page/controller/wallet_provider.dart';
import 'package:mrt_wallet/future/pages/wallet_pages/network/ripple_pages/transaction/controller/impl/memo_impl.dart';
import 'package:mrt_wallet/future/widgets/progress_bar/page_progress.dart';
import 'package:mrt_wallet/models/wallet_models/wallet_models.dart';

import 'package:mrt_wallet/provider/api/networks/ripple/ripple_api_provider.dart';
import 'package:xrpl_dart/xrpl_dart.dart';

abstract class RippleTransactionImpl extends StateController {
  RippleTransactionImpl(
      {required this.walletProvider,
      required this.account,
      required this.network,
      required this.address,
      required this.apiProvider});
  final WalletProvider walletProvider;
  final NetworkAccountCore account;
  final AppXRPNetwork network;
  final RippleApiProvider apiProvider;
  final IXRPAddress address;
  IXRPAddress get owner => address;
  void setFee(String? feeType, {BigInt? customFee});
  List<XRPLMemo> get memos;
  Future<void> onSetupMemo(XRPLMemo? memo, OnSetupMemo onSetupMemo);
  NoneDecimalBalance get fee;
  XrplFeeType? get feeType;
  Map<String, NoneDecimalBalance> get fees;
  final GlobalKey<PageProgressState> progressKey = GlobalKey<PageProgressState>(
      debugLabel: "progressKey_XRPTransaactionStateController");
}