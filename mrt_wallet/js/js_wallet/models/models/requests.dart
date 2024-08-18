import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:mrt_wallet/app/core.dart';
import 'package:mrt_wallet/wallet/web3/constant/constant/exception.dart';

import 'ethreum/ethereum.dart';

enum JSWalletMessageType {
  response([100]),
  event([101]);

  final List<int> tag;
  const JSWalletMessageType(this.tag);

  static JSWalletMessageType fromTag(List<int>? tag) {
    return values.firstWhere((e) => BytesUtils.bytesEqual(e.tag, tag),
        orElse: () => throw Web3RequestExceptionConst.internalError);
  }
}

abstract class JSWalletMessage with CborSerializable {
  abstract final String? requestId;
  final JSClientType client;
  JSWalletMessageType get type;
  final Object? data;
  JSWalletMessage({required this.data, required this.client});

  String get resultAsJsonString => StringUtils.fromJson({"result": data});

  static T deserialize<T extends JSWalletMessage>(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborTagValue cbor =
        CborSerializable.decode(cborBytes: bytes, hex: hex, object: object);
    final client = JSWalletMessageType.fromTag(cbor.tags);
    JSWalletMessage response;
    switch (client) {
      case JSWalletMessageType.response:
        response = JSWalletMessageResponse.deserialize(object: cbor);
        break;
      case JSWalletMessageType.event:
        response = JSWalletNetworkEvent.deserialize(object: cbor);
        break;
      default:
        throw Web3RequestExceptionConst.internalError;
    }
    if (response is! T) {
      throw Web3RequestExceptionConst.internalError;
    }
    return response;
  }

  T cast<T extends JSWalletMessage>() {
    if (this is! T) {
      throw Web3RequestExceptionConst.internalError;
    }
    return this as T;
  }
}

abstract class JSWalletNetworkEvent extends JSWalletMessage {
  @override
  final String? requestId = null;
  JSWalletNetworkEvent({required super.data, required super.client});
  @override
  JSWalletMessageType get type => JSWalletMessageType.event;

  factory JSWalletNetworkEvent.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborTagValue cbor =
        CborSerializable.decode(cborBytes: bytes, hex: hex, object: object);
    final CborListValue values = CborSerializable.cborTagValue(
        object: cbor, tags: JSWalletMessageType.event.tag);
    final client = JSClientType.fromTag(values.elementAt(0));
    switch (client) {
      case JSClientType.ethereum:
        return JSWalletMessageResponseEthereum.deserialize(object: cbor);
      default:
    }
    throw Web3RequestExceptionConst.internalError;
  }
}

enum JSWalletResponseType {
  success([50]),
  failed([51]);

  final List<int> tag;
  const JSWalletResponseType(this.tag);
  static JSWalletResponseType fromTag(List<int>? tag) {
    return values.firstWhere((e) => BytesUtils.bytesEqual(e.tag, tag),
        orElse: () => throw Web3RequestExceptionConst.internalError);
  }
}

class JSWalletMessageResponse extends JSWalletMessage {
  @override
  final String requestId;
  final JSWalletResponseType status;

  JSWalletMessageResponse(
      {required this.requestId,
      required super.data,
      required super.client,
      required this.status});

  factory JSWalletMessageResponse.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborListValue values = CborSerializable.cborTagValue(
        cborBytes: bytes,
        object: object,
        hex: hex,
        tags: JSWalletMessageType.response.tag);
    return JSWalletMessageResponse(
        client: JSClientType.fromTag(values.elementAt(0)),
        requestId: values.elementAt(1),
        data: StringUtils.toJson(values.elementAt<String>(2))["result"],
        status: JSWalletResponseType.fromTag(values.elementAt(3)));
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborListValue.fixedLength([
          CborBytesValue(client.tag),
          requestId,
          resultAsJsonString,
          CborBytesValue(status.tag),
        ]),
        type.tag);
  }

  @override
  JSWalletMessageType get type => JSWalletMessageType.response;
}

enum JSClientType {
  global([110]),
  ethereum([111]);

  final List<int> tag;
  const JSClientType(this.tag);

  static JSClientType fromTag(List<int>? tag) {
    return values.firstWhere((e) => BytesUtils.bytesEqual(e.tag, tag),
        orElse: () => throw Web3RequestExceptionConst.internalError);
  }
}

abstract class ClientMessage {
  abstract final String method;
  abstract final String id;
  abstract final JSClientType type;
  CborTagValue toCbor();
}