/// Sườn API Client để bạn cấu hình sau khi có backend API thực tế.
/// Hỗ trợ Base URL, Auth token và các endpoint đồng bộ.
class ApiClient {
  final String baseUrl;
  final String? Function()? tokenProvider;

  const ApiClient({
    this.baseUrl = 'https://api.example.com',
    this.tokenProvider,
  });

  // TODO: Cấu hình Dio / Http client, Interceptors, Bearer token tại đây
  // Ví dụ các endpoint cần đồng bộ:
  // - GET /stats/daily
  // - GET /stats/by-type
  // - GET /profile, PUT /profile
}
