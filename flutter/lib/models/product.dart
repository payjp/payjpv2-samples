class Product {
  const Product({
    required this.id,
    required this.name,
    required this.amount,
  });

  final String id;
  final String name;
  final int amount;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toInt(),
    );
  }
}
