import 'package:cosmos_sdk/cosmos_sdk.dart';
import 'package:mrt_wallet/models/api/api_provider_tracker.dart';
import 'package:mrt_wallet/provider/api/core/http_provider.dart';
import 'package:mrt_wallet/provider/api/networks/cosmos/api_provider/api_provider.dart';

class ThorNodeHTTPProvider extends HttpProvider
    implements ThorNodeServiceProvider {
  ThorNodeHTTPProvider({
    required this.url,
    required this.provider,
    this.defaultTimeOut = const Duration(seconds: 30),
  });
  @override
  final String url;
  @override
  Future<dynamic> get(ThorNodeRequestDetails params,
      [Duration? timeout]) async {
    return await providerGET<Map<String, dynamic>>(params.url(url), headers: {
      'Content-Type': 'application/json',
      "Accept": "application/json"
    });
  }

  @override
  Future<dynamic> post(ThorNodeRequestDetails params,
      [Duration? timeout]) async {
    return await providerPOST(params.url(url), params.body,
        headers: {"Accept": "application/json", ...params.header});
  }

  @override
  final Duration defaultTimeOut;

  @override
  final ApiProviderTracker<CosmosAPIProviderService> provider;
}