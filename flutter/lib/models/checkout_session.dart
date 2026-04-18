class CheckoutSession {
  const CheckoutSession({
    required this.id,
    required this.url,
    required this.status,
  });

  final String id;
  final Uri url;
  final String status;

  factory CheckoutSession.fromJson(Map<String, dynamic> json) {
    return CheckoutSession(
      id: json['id'] as String,
      url: Uri.parse(json['url'] as String),
      status: json['status'] as String,
    );
  }
}
