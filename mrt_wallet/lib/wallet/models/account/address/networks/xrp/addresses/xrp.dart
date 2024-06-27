import 'package:blockchain_utils/bip/bip/conf/bip_coins.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:mrt_wallet/app/core.dart';

import 'package:mrt_wallet/wallet/models/account/address/balance/balance.dart';
import 'package:mrt_wallet/wallet/models/account/address/core/address.dart';
import 'package:mrt_wallet/wallet/models/account/address/derivation/derivation.dart';
import 'package:mrt_wallet/wallet/models/account/address/new/new_address.dart';
import 'package:mrt_wallet/wallet/models/balance/balance.dart';
import 'package:mrt_wallet/wallet/models/network/network.dart';
import 'package:mrt_wallet/wallet/models/nfts/core/core.dart';
import 'package:mrt_wallet/wallet/models/nfts/networks/ripple.dart';
import 'package:mrt_wallet/wallet/constant/tags/constant.dart';
import 'package:mrt_wallet/wallet/utils/ripple/ripple.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:mrt_wallet/wallet/models/token/token.dart';
import 'multisig.dart';

enum XrpAddressType {
  xAddress("x_address"),
  classic("classic_address");

  final String value;
  const XrpAddressType(this.value);
}

class IXRPAddress
    with Equatable
    implements Bip32AddressCore<BigRational, XRPAddress> {
  IXRPAddress._(
      {required this.keyIndex,
      required this.coin,
      required List<int> publicKey,
      required this.address,
      required this.network,
      required this.networkAddress,
      required this.tag,
      required this.curveType,
      required List<RippleIssueToken> tokens,
      required List<RippleNFToken> nfts,
      String? accountName})
      : publicKey = List.unmodifiable(publicKey),
        _tokens = List.unmodifiable(tokens),
        _nfts = List.unmodifiable(nfts),
        _accountName = accountName,
        addressType =
            tag == null ? XrpAddressType.classic : XrpAddressType.xAddress;

  factory IXRPAddress.newAccount(
      {required RippleNewAddressParam accountParams,
      required List<int> publicKey,
      required WalletXRPNetwork network}) {
    final rippleAddress = RippleUtils.publicKeyToRippleAddress(
        publicKey,
        XRPKeyAlgorithm.values
            .firstWhere((e) => e.curveType == accountParams.type));
    final addressDetauls = IntegerAddressBalance(
        address: accountParams.tag == null
            ? rippleAddress.toString()
            : rippleAddress.toXAddress(
                tag: accountParams.tag,
                isTestnet: accountParams.coin.conf.isTestnet),
        balance: IntegerBalance.zero(network.coinParam.decimal));
    return IXRPAddress._(
      coin: accountParams.coin,
      publicKey: publicKey,
      address: addressDetauls,
      keyIndex: accountParams.deriveIndex,
      networkAddress: XRPAddress(addressDetauls.address),
      network: network.value,
      tag: accountParams.tag,
      curveType: accountParams.type,
      tokens: const [],
      nfts: const [],
    );
  }
  factory IXRPAddress.fromCbsorHex(WalletNetwork network, String hex) {
    return IXRPAddress.fromCborBytesOrObject(network,
        bytes: BytesUtils.fromHexString(hex));
  }
  factory IXRPAddress.fromCborBytesOrObject(WalletNetwork network,
      {List<int>? bytes, CborObject? obj}) {
    final toCborTag = (obj ?? CborObject.fromCbor(bytes!)) as CborTagValue;
    if (BytesUtils.bytesEqual(
        toCborTag.tags, CborTagsConst.rippleMultisigAccount)) {
      return IXRPMultisigAddress.fromCborBytesOrObject(network, obj: toCborTag);
    }

    final CborListValue cbor = CborSerializable.decodeCborTags(
        null, toCborTag, CborTagsConst.rippleAccount);
    final CryptoProposal proposal = CryptoProposal.fromName(cbor.elementAt(0));
    final CryptoCoins coin = CryptoCoins.getCoin(cbor.elementAt(1), proposal)!;
    final keyIndex =
        AddressDerivationIndex.fromCborBytesOrObject(obj: cbor.getCborTag(2));
    final List<int> publicKey = cbor.elementAt(3);
    final networkId = cbor.elementAt(7);
    if (networkId != network.value) {
      throw WalletExceptionConst.incorrectNetwork;
    }
    final IntegerAddressBalance address =
        IntegerAddressBalance.fromCborBytesOrObject(network.coinParam.decimal,
            obj: cbor.getCborTag(4));

    final XRPAddress rippleAddress = XRPAddress(cbor.elementAt(5));
    int? tag = cbor.elementAt(6);

    final List<RippleIssueToken> issueTokens = [];
    final List<dynamic>? tokens = cbor.elementAt(8);
    if (tokens != null) {
      for (final i in tokens) {
        issueTokens.add(RippleIssueToken.fromCborBytesOrObject(obj: i));
      }
    }
    final List<RippleNFToken> accountNfts = [];
    final List<dynamic>? nfts = cbor.elementAt(9);
    if (nfts != null) {
      for (final i in nfts) {
        accountNfts.add(RippleNFToken.fromCborBytesOrObject(obj: i));
      }
    }
    final String? curveName = cbor.elementAt(10);
    final curveType = curveName == null
        ? EllipticCurveTypes.secp256k1
        : EllipticCurveTypes.fromName(curveName);
    final String? accountName = cbor.elementAt(11);
    return IXRPAddress._(
        coin: coin,
        publicKey: publicKey,
        address: address,
        keyIndex: keyIndex,
        networkAddress: rippleAddress,
        network: networkId,
        tag: tag,
        curveType: curveType,
        tokens: issueTokens,
        nfts: accountNfts,
        accountName: accountName);
  }

  @override
  String accountToString() {
    return address.toAddress;
  }

  @override
  final AddressBalanceCore<BigInt> address;

  @override
  final CryptoCoins coin;

  @override
  final AddressDerivationIndex keyIndex;

  @override
  final int network;

  @override
  final List<int> publicKey;

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborListValue.fixedLength([
          coin.proposal.specName,
          coin.coinName,
          keyIndex.toCbor(),
          publicKey,
          address.toCbor(),
          networkAddress.toString(),
          tag == null ? const CborNullValue() : CborIntValue(tag!),
          network,
          CborListValue.fixedLength(_tokens.map((e) => e.toCbor()).toList()),
          CborListValue.fixedLength(_nfts.map((e) => e.toCbor()).toList()),
          curveType.name,
          accountName ?? const CborNullValue()
        ]),
        CborTagsConst.rippleAccount);
  }

  @override
  List get variabels {
    return [tag, keyIndex, network];
  }

  @override
  final XRPAddress networkAddress;
  final XrpAddressType addressType;
  final EllipticCurveTypes curveType;
  final int? tag;

  @override
  String get type => addressType.value;

  List<RippleIssueToken> _tokens;
  @override
  List<RippleIssueToken> get tokens => _tokens;

  List<RippleNFToken> _nfts;
  @override
  List<RippleNFToken> get nfts => _nfts;

  @override
  void addToken(TokenCore<BigRational> newToken) {
    if (newToken is! RippleIssueToken) {
      throw WalletExceptionConst.invalidArgruments(
          "RippleIssueToken", "${newToken.runtimeType}");
    }
    if (_tokens.contains(newToken)) {
      throw WalletExceptionConst.tokenAlreadyExist;
    }
    _tokens = List.unmodifiable([newToken, ..._tokens]);
  }

  @override
  void updateToken(TokenCore<BigRational> token, Token updatedToken) {
    if (!tokens.contains(token)) return;
    if (token is! RippleIssueToken) {
      throw WalletExceptionConst.invalidArgruments(
          "RippleIssueToken", "${token.runtimeType}");
    }
    List<RippleIssueToken> existTokens = List<RippleIssueToken>.from(_tokens);
    existTokens.removeWhere((element) => element == token);
    existTokens = [token.updateToken(updatedToken), ...existTokens];
    _tokens = List.unmodifiable(existTokens);
  }

  @override
  void removeToken(TokenCore<BigRational> token) {
    if (!tokens.contains(token)) return;
    final existTokens = List.from(_tokens);
    existTokens.removeWhere((element) => element == token);
    _tokens = List.unmodifiable(existTokens);
  }

  @override
  void addNFT(NFTCore newNft) {
    if (newNft is! RippleNFToken) {
      throw WalletExceptionConst.invalidArgruments(
          "RippleNFToken", "${newNft.runtimeType}");
    }
    if (_nfts.contains(newNft)) {
      throw WalletExceptionConst.nftsAlreadyExist;
    }
    _nfts = List.unmodifiable([newNft, ..._nfts]);
  }

  @override
  void removeNFT(NFTCore nft) {
    if (!_nfts.contains(nft)) return;
    final existNfts = List.from(_nfts);
    existNfts.removeWhere((element) => element == nft);
    _nfts = List.unmodifiable(_nfts);
  }

  @override
  bool get multiSigAccount => false;

  String? _accountName;
  @override
  String? get accountName => _accountName;

  @override
  void setAccountName(String? name) {
    _accountName = name;
  }

  @override
  String get orginalAddress => networkAddress.address;

  @override
  List<AddressDerivationIndex> get keyIndexes => [keyIndex];

  @override
  bool isEqual(Bip32AddressCore<BigRational, XRPAddress> other) {
    return networkAddress.address == other.networkAddress.address &&
        networkAddress.tag == other.networkAddress.tag &&
        multiSigAccount == other.multiSigAccount;
  }
}

class IXRPMultisigAddress extends IXRPAddress
    implements MultiSigCryptoAccountAddress {
  IXRPMultisigAddress._(
      {required super.address,
      required super.network,
      required super.coin,
      required super.networkAddress,
      required super.nfts,
      required super.tag,
      required super.tokens,
      required this.multiSignatureAccount,
      String? accountName})
      : super._(
            keyIndex: const MultiSigAddressIndex(),
            curveType: EllipticCurveTypes.secp256k1,
            publicKey: const [],
            accountName: accountName);

  factory IXRPMultisigAddress.newAccount(
      {required RippleMultisigNewAddressParam accountParams,
      required WalletXRPNetwork network}) {
    final addressDetails = IntegerAddressBalance(
        address: accountParams.tag == null
            ? accountParams.masterAddress.toString()
            : accountParams.masterAddress.toXAddress(
                tag: accountParams.tag,
                isTestnet: accountParams.coin.conf.isTestnet),
        balance: IntegerBalance.zero(network.coinParam.decimal));

    return IXRPMultisigAddress._(
        coin: accountParams.coin,
        multiSignatureAccount: accountParams.multiSigAccount,
        address: addressDetails,
        networkAddress: XRPAddress(addressDetails.address),
        network: network.value,
        tag: accountParams.tag,
        tokens: const [],
        nfts: const []);
  }
  factory IXRPMultisigAddress.fromCborBytesOrObject(WalletNetwork network,
      {List<int>? bytes, CborObject? obj}) {
    final toCborTag = (obj ?? CborObject.fromCbor(bytes!)) as CborTagValue;

    final CborListValue cbor = CborSerializable.decodeCborTags(
        null, toCborTag, CborTagsConst.rippleMultisigAccount);
    final CryptoProposal proposal =
        CryptoProposal.fromName(cbor.value[0].value);
    final CryptoCoins coin =
        CryptoCoins.getCoin(cbor.value[1].value, proposal)!;

    final int networkId = cbor.elementAt(7);
    if (networkId != network.value) {
      throw WalletExceptionConst.incorrectNetwork;
    }
    final IntegerAddressBalance address =
        IntegerAddressBalance.fromCborBytesOrObject(network.coinParam.decimal,
            obj: cbor.value[4]);

    final XRPAddress rippleAddress = XRPAddress(cbor.value[5].value);
    int? tag;
    if (cbor.value[6] is CborIntValue) {
      tag = cbor.value[6].value;
    }
    final List<RippleIssueToken> issueTokens = [];
    final List<dynamic>? tokens = cbor.elementAt(8);
    if (tokens != null) {
      for (final i in tokens) {
        issueTokens.add(RippleIssueToken.fromCborBytesOrObject(obj: i));
      }
    }
    final List<RippleNFToken> accountNfts = [];
    final List<dynamic>? nfts = cbor.elementAt(9);
    if (nfts != null) {
      for (final i in nfts) {
        accountNfts.add(RippleNFToken.fromCborBytesOrObject(obj: i));
      }
    }
    RippleMultiSignatureAddress multiSigAccount =
        RippleMultiSignatureAddress.fromCborBytesOrObject(
            obj: cbor.getCborTag(11));
    final String? accountName = cbor.elementAt(12);
    return IXRPMultisigAddress._(
        coin: coin,
        address: address,
        networkAddress: rippleAddress,
        network: networkId,
        tag: tag,
        tokens: issueTokens,
        multiSignatureAccount: multiSigAccount,
        nfts: accountNfts,
        accountName: accountName);
  }

  final RippleMultiSignatureAddress multiSignatureAccount;
  @override
  List<int> get publicKey => throw UnimplementedError();
  @override
  EllipticCurveTypes get curveType => throw UnimplementedError();

  @override
  List get variabels {
    return [tag, keyIndex, network, multiSignatureAccount];
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborListValue.fixedLength([
          coin.proposal.specName,
          coin.coinName,
          const CborNullValue(),
          const CborNullValue(),
          address.toCbor(),
          networkAddress.toString(),
          tag == null ? const CborNullValue() : CborIntValue(tag!),
          network,
          CborListValue.fixedLength(_tokens.map((e) => e.toCbor()).toList()),
          CborListValue.fixedLength(_nfts.map((e) => e.toCbor()).toList()),
          const CborNullValue(),
          multiSignatureAccount.toCbor(),
          accountName ?? const CborNullValue()
        ]),
        CborTagsConst.rippleMultisigAccount);
  }

  @override
  bool get multiSigAccount => true;

  @override
  List<(String, AddressDerivationIndex)> get keyDetails =>
      multiSignatureAccount.signers
          .map((e) => (e.publicKey, e.keyIndex))
          .toList();
}