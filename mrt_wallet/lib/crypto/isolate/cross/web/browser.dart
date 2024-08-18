part of 'package:mrt_wallet/crypto/isolate/cross/web/web.dart';

@JS("#workerListener")
external set workerListener(JSFunction? f);
@JS("#workerListener")
external JSFunction get workerListener;

@JS("#errorListener")
external set onWorkerErrorListener(JSFunction? f);
@JS("#errorListener")
external JSFunction get onWorkerErrorListener;

class BrowserCryptoWorker extends IsolateCryptoWoker {
  BrowserCryptoWorker._() : super();
  late final bool isExtention = web.isExtention;
  // static const String _scriptHash =
  //     "6e0bbc3031e089a4b81d9d52130552129d06e9d92205ffe21ad06bd5fc702598";
  // static const String _wasmhash =
  //     "a5d82db82c25525ffa69e3f2708815a842dc5cab48d877415974547550a6903f";
  // static const String _workerHash =
  //     "3e271fd1f7f2f62d511d7d0d4c2a39328b60ec83e947290a4507edf64db2d335";

  static const String _wasmPath = "assets/wasm/crypto.wasm";
  static const String _extentionJs = "assets/wasm/wasm.mjs";
  static const String _scryptPath = "assets/wasm/crypto.mjs";
  bool _hasIsolate = true;
  @override
  bool get hasIsolate => _hasIsolate;
  int _id = 0;

  final _lock = SynchronizedLock();

  @override
  Future<T> getResult<T extends MessageArgs>(
      WorkerRequestMessage message) async {
    await _init();
    final args = await _connector!.sentRequest(message, _id++);
    if (args.type == ArgsType.exception) {
      throw WalletException((args as MessageArgsException).message);
    }
    if (args is! T) {
      throw WalletExceptionConst.dataVerificationFailed;
    }
    return args;
  }

  _WebConnectionInfo? _connector;

  Future<String> loadFileText(String path) async {
    final f = await jsWindow.fetch_(path);
    return await f.text_();
  }

  Future<ByteBuffer> loadFileBinary(String path) async {
    final f = await jsWindow.fetch_(path);
    return await f.arrayBuffer_();
  }

  String _getAssetPath(String assetPath) {
    if (isExtention) {
      final path = web.extention.runtime.getURL("assets/$assetPath");
      return path;
    }
    return assetPath;
  }

  // Future<String> _loadWorker() async {
  //   final file = await loadFileText(_getAssetPath(_extentionJs));
  //   return file;
  // }

  Future<ByteBuffer> _loadWasm() async {
    final file = await loadFileBinary(_getAssetPath(_wasmPath));
    return file;
  }

  Future<web.Worker> _buildExtentionWorker() async {
    final url = _getAssetPath(_extentionJs);
    return web.Worker(url, WorkerOptions()..type = "module");
  }

  // Future<web.Worker> _buildWebWorker() async {
  //   final workerJs = await _loadWorker();
  //   return web.Worker(
  //       "data:text/javascript,$workerJs", WorkerOptions()..type = "module");
  // }

  Future<web.Worker> _buildWorker() async {
    // if (isExtention) {
    //   return _buildExtentionWorker();
    // }
    return _buildExtentionWorker();
  }

  Future<String?> _loadModuleScript() async {
    if (isExtention) return null;
    // final file = await rootBundle.loadString(_scryptPath);
    final file = await loadFileText(_getAssetPath(_scryptPath));
    // final scriptHash = BytesUtils.toHexString(
    //     QuickCrypto.sha3256Hash(StringUtils.encode(file)));
    // if (scriptHash != _scriptHash) {
    //   throw IsolateAuthenticated.failed;
    // }
    return file;
  }

  Future<_WebConnectionInfo> _loadMoudle() async {
    Completer<_WebConnectionInfo> completer = Completer();
    String? moudle;
    final ByteBuffer wasm;
    try {
      wasm = await _loadWasm();
      moudle = await _loadModuleScript();
    } catch (e) {
      throw IsolateAuthenticated.failed;
    }
    final worker = await _buildWorker();
    void onEvent(MessageEvent event) {
      final String key = event.data.dartify() as String;
      completer.complete(_WebConnectionInfo(
          key: BytesUtils.fromHexString(key), worker: worker));
    }

    onWorkerErrorListener = _onError.toJS;
    worker.addEventListener("error", onWorkerErrorListener);
    workerListener = onEvent.toJS;
    worker.addEventListener("message", workerListener);
    worker.postMessage({"module": moudle, "wasm": wasm}.jsify()!);
    final result = await completer.future.timeout(const Duration(seconds: 20));
    worker.removeEventListener("message", workerListener);
    worker.addEventListener("message", _onMessage.toJS);
    WalletLogging.log("initialized.");
    return result;
  }

  void _onError(MessageEvent e) {
    _lock.synchronized(() {
      _connector = null;
    });
  }

  void _onMessage(MessageEvent e) {
    _connector?.onResponse(e);
  }

  Future<void> _init() async {
    await _lock.synchronized(() async {
      if (!_hasIsolate) {
        throw FailedIsolateInitialization.failed;
      }
      try {
        _connector ??= await _loadMoudle();
      } catch (e) {
        print("has error $e");
        _hasIsolate = false;
        throw FailedIsolateInitialization.failed;
      }
    });
  }

  @override
  void init(bool useIsolate) {
    _hasIsolate = useIsolate;
    if (_hasIsolate) {
      _init();
    }
  }
}

class _WebConnectionInfo {
  final ChaCha20Poly1305 chacha;
  final web.Worker worker;
  _WebConnectionInfo({
    required List<int> key,
    required this.worker,
  }) : chacha = ChaCha20Poly1305(key);

  final Map<int, WorkerMessageCompleter> _requests = {};
  void onResponse(MessageEvent e) {
    final String message = (e.data.dartify() as String);
    final result = getResult(message);
    _requests[result.id]?.complete(result);
  }

  String _toEncryptedMessage(WorkerRequestMessage request, int id) {
    final nonce = QuickCrypto.generateRandom(16);
    final enc = chacha.encrypt(nonce, request.toCbor().encode());
    final encryptMessage =
        WorkerEncryptedMessage(message: enc, nonce: nonce, id: id);
    return BytesUtils.toHexString(encryptMessage.toCbor().encode());
  }

  Future<MessageArgs> sentRequest(
      WorkerRequestMessage request, int requestId) async {
    final id = WorkerMessageCompleter(requestId);
    _requests[id.id] = id;
    final encryptMessage = _toEncryptedMessage(request, requestId);
    worker.postMessage(encryptMessage.toJS);
    final r = await id.getResult();
    return r;
  }

  WorkerResponseMessage getResult(dynamic message) {
    int? id;
    try {
      final encryptMessageBytes = BytesUtils.fromHexString(message);
      final encryptedMessage =
          WorkerEncryptedMessage.deserialize(encryptMessageBytes);
      final decode =
          chacha.decrypt(encryptedMessage.nonce, encryptedMessage.message);
      id = encryptedMessage.id;
      final response = WorkerResponseMessage.deserialize(decode!);
      return response;
    } catch (e) {
      return WorkerResponseMessage(
          args: IsolateMessageController.verificationFailed, id: id ?? -1);
    }
  }
}