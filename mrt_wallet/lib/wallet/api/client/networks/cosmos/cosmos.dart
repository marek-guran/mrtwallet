import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cosmos_sdk/cosmos_sdk.dart';
import 'package:mrt_wallet/wallet/utils/cosmos/cosmos.dart';
import 'package:mrt_wallet/wallet/api/client/core/client.dart';
import 'package:mrt_wallet/wallet/api/provider/networks/cosmos.dart';
import 'package:mrt_wallet/wallet/api/services/core/base_service.dart';
import 'package:mrt_wallet/wallet/api/services/core/tracker.dart';
import 'package:mrt_wallet/wallet/models/account/address/networks/cosmos/cosmos.dart';
import 'package:mrt_wallet/wallet/models/network/network.dart';

class CosmosClient implements NetworkClient<ICosmosAddress> {
  CosmosClient(
      {required this.provider,
      required this.network,
      required this.nodeProvider});
  final TendermintProvider provider;
  final ThorNodeProvider? nodeProvider;

  @override
  final WalletCosmosNetwork network;
  @override
  APIServiceTracker<CosmosAPIProvider> get serviceProvider =>
      (provider.rpc as BaseServiceProtocol).provider
          as APIServiceTracker<CosmosAPIProvider>;

  @override
  Future<void> updateBalance(ICosmosAddress account) async {
    final request = QueryBalanceRequest(
        address: account.networkAddress,
        denom: network.coinParam.mainCoin.denom);
    final result =
        await provider.request(TendermintRequestAbciQuery(request: request));
    account.address.updateBalance(result.balance.amount);
  }

  Future<BaseAccount?> getBaseAccount(CosmosBaseAddress address) async {
    try {
      final request = QueryAccountRequest(address);
      final result =
          await provider.request(TendermintRequestAbciQuery(request: request));
      return result.account.baseAccount;
    } on RPCError catch (e) {
      if (e.errorCode == CosmosUtils.accountNotFoundErrorCode) {
        return null;
      }
      rethrow;
    }
  }

  Future<GetLatestBlockResponse> getLatestBlock() async {
    return await provider.request(
        TendermintRequestAbciQuery(request: const GetLatestBlockRequest()));
  }

  Future<SimulateResponse> simulateTransaction(List<int> txBytes) async {
    try {
      return await provider.request(
          TendermintRequestAbciQuery(request: SimulateRequest(txBytes)));
    } catch (e) {
      rethrow;
    }
  }

  Future<String> broadcastTransaction(List<int> txRaw) async {
    final result = await provider.request(TendermintRequestBroadcastTxCommit(
        BytesUtils.toHexString(txRaw, prefix: "0x")));
    if (!result.isSuccess) {
      throw RPCError(
          message: result.checkTx.log ?? "",
          errorCode: result.checkTx.code ?? 0,
          data: result.toJson(),
          request: {});
    }
    return result.hash;
  }

  Future<ThorNodeNetworkConstants> getThorNodeConstants() async {
    return await nodeProvider!.request(ThorNodeRequestConstants());
  }
}