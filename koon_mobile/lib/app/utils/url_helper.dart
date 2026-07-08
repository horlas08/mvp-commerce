class UrlHelper {
  /// Converts standard shop URLs to their corresponding Arabic domains/subdomains.
  static String convertToArabicUrl(String url) {
    if (url.trim().isEmpty) return url;
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      
      // Alibaba redirection (www.alibaba.com -> arabic.alibaba.com)
      if (host.contains('alibaba.com') && 
          !host.contains('arabic.alibaba.com') && 
          !host.contains('aliexpress.com')) {
        return url
            .replaceAll('www.alibaba.com', 'arabic.alibaba.com')
            .replaceAll('://alibaba.com', '://arabic.alibaba.com');
      }
      
      // AliExpress redirection (www.aliexpress.com -> ar.aliexpress.com)
      if (host.contains('aliexpress.com') && !host.contains('ar.aliexpress.com')) {
        return url
            .replaceAll('www.aliexpress.com', 'ar.aliexpress.com')
            .replaceAll('://aliexpress.com', '://ar.aliexpress.com');
      }
      
      // SHEIN redirection (www.shein.com -> ar.shein.com)
      if (host.contains('shein.com') && !host.contains('ar.shein.com')) {
        return url
            .replaceAll('www.shein.com', 'ar.shein.com')
            .replaceAll('://shein.com', '://ar.shein.com');
      }
      
      // iHerb redirection (www.iherb.com -> ar.iherb.com)
      if (host.contains('iherb.com') && !host.contains('ar.iherb.com')) {
        return url
            .replaceAll('www.iherb.com', 'ar.iherb.com')
            .replaceAll('://iherb.com', '://ar.iherb.com');
      }
      
      // Amazon.sa parameter enforcement (forces Arabic localization)
      if (host.contains('amazon.sa')) {
        if (!url.contains('language=ar_AE')) {
          final separator = url.contains('?') ? '&' : '?';
          return '$url${separator}language=ar_AE';
        }
      }
    } catch (_) {}
    return url;
  }
}
