import 'package:blockchain_utils/bip/bip/conf/bip_coins.dart';
import 'package:blockchain_utils/cbor/cbor.dart';
import 'package:blockchain_utils/utils/utils.dart';
import 'package:mrt_wallet/app/core.dart';
import 'package:mrt_wallet/wallet/models/account/address/balance/balance.dart';
import 'package:mrt_wallet/wallet/models/account/address/derivation/core/derivation.dart';
import 'package:mrt_wallet/wallet/models/account/address/networks/networks.dart';
import 'package:mrt_wallet/wallet/models/network/network.dart';
import 'package:mrt_wallet/wallet/models/nfts/nfts.dart';

import 'package:mrt_wallet/wallet/constant/tags/constant.dart';
import 'package:mrt_wallet/wallet/models/token/core/core.dart';
import 'package:mrt_wallet/wallet/models/token/token/token.dart';

abstract class CryptoAddress<N, T, X> with CborSerializable {
  abstract final CryptoCoins coin;
  abstract final AddressBalanceCore<N> address;
  abstract final AddressDerivationIndex keyIndex;
  abstract final List<AddressDerivationIndex> keyIndexes;
  abstract final List<TokenCore<T>> tokens;
  abstract final List<NFTCore> nfts;
  abstract final int network;
  abstract final String? type;
  abstract final X networkAddress;
  abstract final String? accountName;

  /// its only for checking duplicate account
  abstract final String orginalAddress;

  ///
  bool isEqual(Bip32AddressCore<T, X> other);

  void setAccountName(String? name);
  bool get multiSigAccount;
  String accountToString();
  void addNFT(NFTCore newNft);
  void removeNFT(NFTCore nft);
  void addToken(TokenCore<T> newToken);
  void removeToken(TokenCore<T> token);
  void updateToken(TokenCore<T> token, Token updatedToken);

  static CryptoAddress fromCbor(WalletNetwork network, CborObject cbor) {
    if (cbor is! CborTagValue) {
      throw WalletExceptionConst.invalidAccountDetails;
    }
    if (BytesUtils.bytesEqual(
        cbor.tags, CborTagsConst.bitcoinMultiSigAccount)) {
      return IBitcoinMultiSigAddress.fromCborBytesOrObject(network, obj: cbor);
    } else if (BytesUtils.bytesEqual(cbor.tags, CborTagsConst.bitcoinAccount)) {
      return IBitcoinAddress.fromCborBytesOrObject(network, obj: cbor);
    } else if (BytesUtils.bytesEqual(
        cbor.tags, CborTagsConst.bitcoinCashAccount)) {
      return IBitcoinCashAddress.fromCborBytesOrObject(network, obj: cbor);
    } else if (BytesUtils.bytesEqual(
        cbor.tags, CborTagsConst.bitcoinCashMultiSigAccount)) {
      return IBitcoinCashMultiSigAddress.fromCborBytesOrObject(network,
          obj: cbor);
    } else if (BytesUtils.bytesEqual(cbor.tags, CborTagsConst.rippleAccount)) {
      return IXRPAddress.fromCborBytesOrObject(network, obj: cbor);
    } else if (BytesUtils.bytesEqual(
        cbor.tags, CborTagsConst.rippleMultisigAccount)) {
      return IXRPMultisigAddress.fromCborBytesOrObject(network, obj: cbor);
    } else if (BytesUtils.bytesEqual(cbor.tags, CborTagsConst.ethAccount)) {
      return IEthAddress.fromCborBytesOrObject(network, obj: cbor);
    } else if (BytesUtils.bytesEqual(cbor.tags, CborTagsConst.tronAccount)) {
      return ITronAddress.fromCborBytesOrObject(network, obj: cbor);
    } else if (BytesUtils.bytesEqual(
        cbor.tags, CborTagsConst.tronMultisigAccount)) {
      return ITronMultisigAddress.fromCborBytesOrObject(network, obj: cbor);
    } else if (BytesUtils.bytesEqual(cbor.tags, CborTagsConst.solAccount)) {
      return ISolanaAddress.fromCborBytesOrObject(network, obj: cbor);
    } else if (BytesUtils.bytesEqual(cbor.tags, CborTagsConst.cardanoAccount)) {
      return ICardanoAddress.fromCborBytesOrObject(network, obj: cbor);
    } else if (BytesUtils.bytesEqual(cbor.tags, CborTagsConst.cosmosAccount)) {
      return ICosmosAddress.fromCborBytesOrObject(network, obj: cbor);
    } else if (BytesUtils.bytesEqual(cbor.tags, CborTagsConst.tonAccount)) {
      return ITonAddress.fromCborBytesOrObject(network, obj: cbor);
    }
    throw WalletExceptionConst.invalidAccountDetails;
  }
}

abstract class MultiSigCryptoAccountAddress {
  abstract final List<(String, AddressDerivationIndex)> keyDetails;
}

abstract class Bip32AddressCore<T, X> implements CryptoAddress<BigInt, T, X> {
  abstract final List<int> publicKey;
}