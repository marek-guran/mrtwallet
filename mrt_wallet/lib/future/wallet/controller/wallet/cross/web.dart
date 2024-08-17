import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mrt_native_support/platform_interface.dart';
import 'package:mrt_native_support/web/api/chrome/api/core.dart';
import 'package:mrt_wallet/app/core.dart';
import 'package:mrt_wallet/future/wallet/controller/impl/extention_wallet.dart';
import 'package:mrt_wallet/future/wallet/controller/wallet/ui_wallet.dart';
import 'package:mrt_wallet/future/wallet/controller/impl/web3_request_controller.dart';
import 'package:mrt_wallet/wallet/models/setting/models/lock_time.dart';
import 'package:mrt_wallet/wallet/provider/wallet_provider.dart';
import 'package:mrt_wallet/wroker/impl/worker_impl.dart';
import 'io.dart';

UIWallet uiWallet(GlobalKey<NavigatorState> navigatorKey) {
  if (PlatformInterface.isWeb && isExtention) {
    return ExtentionWallet(navigatorKey);
  }
  return Wallet(navigatorKey);
}

class ExtentionWallet extends UIWallet
    with CryptoWokerImpl, Web3RequestControllerImpl, ExtentionWalletHandler {
  ExtentionWallet(GlobalKey<NavigatorState> navigatorKey) : super(navigatorKey);
  final _lock = SynchronizedLock();

  @override
  Future<MethodResult<WalletLockTime>> login(String password) async {
    final bool isReadOnly = this.isReadOnly || isLock;
    final result = await super.login(password);
    if (isReadOnly && isUnlock) {
      await _lock.synchronized(() async {
        await saveLoginHistory(password);
      });
    }
    return result;
  }

  @override
  Future<void> lock() async {
    await _lock.synchronized(() async {
      await clearLoginHistory();
    });
    await super.lock();
  }

  @override
  Future<void> initWallet(
      {bool useIsolate = true,
      String? initialPassword,
      DateTime? locktime}) async {
    crypto.init(true);
    final loginHistory = await _lock.synchronized(() async {
      return await getLoginHistory();
    });
    await super.initWallet(initialPassword: loginHistory);
    if (loginHistory != null && isUnlock) {
      await _lock.synchronized(() async {
        return await saveLoginHistory(loginHistory);
      });
    }
  }

  @override
  void init(DynamicVoid onNotification) async {
    onNotify = onNotification;
    await initWallet();
    initExtention();
  }

  @override
  WalletCore get walletCore => this;
}