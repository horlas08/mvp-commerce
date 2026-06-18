class Product {
  final String id;
  final String title;
  final String price;
  final String imageUrl;
  final String url;
  final String site;

  Product({
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.url,
    required this.site,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      price: json['price'] ?? 'Unknown Price',
      imageUrl: json['image_url'] ?? '',
      url: json['url'] ?? '',
      site: json['site'] ?? 'Unknown Site',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'image_url': imageUrl,
      'url': url,
      'site': site,
    };
  }

  Product copyWith({
    String? id,
    String? title,
    String? price,
    String? imageUrl,
    String? url,
    String? site,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      url: url ?? this.url,
      site: site ?? this.site,
    );
  }
}
