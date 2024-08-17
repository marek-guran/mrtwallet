import 'package:blockchain_utils/cbor/cbor.dart';
import 'package:blockchain_utils/utils/utils.dart';
import 'package:mrt_wallet/app/core.dart';
import 'package:mrt_wallet/wallet/web3/core/messages/types/message_types.dart';
import 'package:mrt_wallet/wallet/web3/core/permission/models/authenticated.dart';
import 'response.dart';

class Web3WalletResponseMessage extends Web3ResponseMessage {
  final Web3APPAuthentication authenticated;
  Web3WalletResponseMessage._({Object? result, required this.authenticated})
      : super(result);
  factory Web3WalletResponseMessage(
      {Object? result, required Web3APPAuthentication authenticated}) {
    return Web3WalletResponseMessage._(
        result: result, authenticated: authenticated);
  }

  factory Web3WalletResponseMessage.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborListValue values = CborSerializable.cborTagValue(
        cborBytes: bytes,
        hex: hex,
        object: object,
        tags: Web3MessageTypes.walletResponse.tag);
    final Map<String, dynamic> result =
        StringUtils.toJson(values.elementAt<String>(0));
    return Web3WalletResponseMessage._(
        result: result["result"],
        authenticated:
            Web3APPAuthentication.deserialize(object: values.getCborTag(1)));
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborListValue.fixedLength([
          StringUtils.fromJson({"result": result}),
          authenticated.toCbor()
        ]),
        type.tag);
  }

  @override
  Web3MessageTypes get type => Web3MessageTypes.walletResponse;
}