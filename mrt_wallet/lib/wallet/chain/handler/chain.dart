import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:mrt_wallet/app/core.dart';
import 'package:mrt_wallet/wallet/api/client/core/client.dart';
import 'package:mrt_wallet/wallet/api/utils/utils.dart';
import 'package:mrt_wallet/wallet/models/network/network.dart';

import 'package:mrt_wallet/wallet/models/account/account.dart';
import 'package:mrt_wallet/wallet/api/constant/constant.dart';
import 'package:mrt_wallet/wallet/chain/utils/utils.dart';
import 'package:mrt_wallet/wallet/api/provider/core/provider.dart';

import 'package:mrt_wallet/wallet/constant/tags/constant.dart';
import 'package:mrt_wallet/wallet/utils/ethereum/utils.dart';

class ChainHandler with CborSerializable {
  ChainHandler._(this.network, this._networkApiProvider, this.account)
      : assert(network.value == account.network.value, "invalid account");
  final WalletNetwork network;
  final NetworkAccountCore account;
  bool get haveAddress => account.haveAddress;
  NetworkClient? _networkApiProvider;
  late final List<String> services = List.unmodifiable(_services(network));

  static List<String> _services(WalletNetwork network) {
    switch (network.type) {
      case NetworkType.xrpl:
        return ["services", "tokens"];
      case NetworkType.tron:
        return ["services", "trc20_tokens", "trc10_tokens"];
      case NetworkType.ethereum:
        return ["tokens"];
      case NetworkType.solana:
        return ["services", "tokens"];
      case NetworkType.ton:
        return ["services", "jettons"];
      default:
        return ["services"];
    }
  }

  factory ChainHandler.fromAccount(NetworkAccountCore account) {
    return ChainHandler._(
        account.network, APIUtils.createApiClient(account.network), account);
  }

  T? provider<T extends NetworkClient>([APIProvider? service]) {
    return _networkApiProvider as T?;
  }

  void setProvider(APIProvider service) {
    final currentProvider = _networkApiProvider;
    _networkApiProvider = APIUtils.createApiClient(network, service: service);
    currentProvider?.serviceProvider.notify();
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborListValue.dynamicLength([
          network.toCbor(),
          _networkApiProvider?.serviceProvider.provider.toCbor(),
          account.toCbor()
        ]),
        CborTagsConst.network);
  }

  factory ChainHandler.fromHex(String hex) {
    return ChainHandler.fromCborBytesOrObject(
        bytes: BytesUtils.fromHexString(hex));
  }

  factory ChainHandler.fromCborBytesOrObject(
      {List<int>? bytes, CborObject? obj}) {
    final CborListValue cbor =
        CborSerializable.decodeCborTags(bytes, obj, CborTagsConst.network);
    final networkObject = cbor.getCborTag(0)?.getList;
    final int networkId = networkObject?.elementAt(0);
    final network = MethodUtils.nullOnException(
        () => WalletNetwork.fromCborBytesOrObject(obj: cbor.getCborTag(0)));
    final updateNetwork =
        ChainUtils.updateNetwork(networkId: networkId, network: network);
    final provider = MethodUtils.nullOnException(
        () => APIProvider.fromCborBytesOrObject(obj: cbor.getCborTag(1)));
    final apiProvider =
        APIUtils.createApiClient(updateNetwork, service: provider);
    return ChainHandler._(updateNetwork, apiProvider,
        ChainUtils.account(updateNetwork, cbor.getCborTag(2)));
  }
}

class ChainsHandler {
  ChainsHandler._(this.networks, this._network);
  final Map<int, ChainHandler> networks;
  int _network;
  WalletNetwork get network => networks[_network]!.network;
  ChainHandler get chain => networks[_network]!;
  factory ChainsHandler.setup() {
    return ChainsHandler._({
      for (final i in ChainUtils.defaultCoins.values)
        i.value: ChainHandler._(
            i, APIUtils.createApiClient(i), ChainUtils.createNetworkAccount(i))
    }, 0);
  }

  factory ChainsHandler(List<ChainHandler> chains, {int? currentNetwork}) {
    final toMap = {for (final i in chains) i.network.value: i};
    for (final i in ChainUtils.defaultCoins.keys) {
      if (toMap.containsKey(i)) {
        continue;
      }
      final network = ChainUtils.defaultCoins[i]!;
      toMap.addAll({
        network.value: ChainHandler._(
            network,
            APIUtils.createApiClient(network),
            ChainUtils.createNetworkAccount(network))
      });
    }
    if (!toMap.containsKey(currentNetwork)) {
      currentNetwork = 0;
    }
    return ChainsHandler._(toMap, currentNetwork ?? 0);
  }

  void setNetwork(int networkId) {
    if (_network == networkId || !networks.containsKey(networkId)) return;
    final currentChain = chain;
    _network = networkId;
    currentChain._networkApiProvider?.serviceProvider.notify();
    chain._networkApiProvider?.serviceProvider.notify();
  }

  ChainHandler fromAccount(NetworkAccountCore account) =>
      networks[account.network.value]!;
  ChainHandler fromAddress(CryptoAddress adresss) => networks[adresss.network]!;
  ChainHandler updateImportNetwork(WalletNetwork network) {
    if (network.coinParam.providers.isEmpty) {
      if (ProvidersConst.getDefaultProvider(network).isEmpty) {
        throw WalletException("invalid_network_information");
      }
    }

    int networkId = network.value;
    if (networkId == 0) {
      if (network is! WalletEthereumNetwork) {
        throw WalletException("invalid_network_information");
      }
      if (network.coinParam.token.decimal != EthereumUtils.decimal) {
        throw WalletException("invalid_network_information");
      }
      final evmIds = networks.values.map((e) => e.network.value).toList();
      networkId = StrUtils.findFirstMissingNumber(evmIds, start: 100);
      network = network.copyWith(value: networkId);
    } else {
      if (networks[networkId] == null ||
          networks[networkId]!.network.runtimeType != network.runtimeType ||
          network.value != _network) {
        throw WalletException("invalid_network_information");
      }
    }
    final currentChain = chain;
    final updateChain = ChainHandler._(
        network,
        APIUtils.createApiClient(network),
        networks[networkId]?.account ??
            ChainUtils.createNetworkAccount(network));
    networks[networkId] = updateChain;
    currentChain._networkApiProvider?.serviceProvider.notify();
    return chain;
  }
}