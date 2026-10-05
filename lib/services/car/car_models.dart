class CarPage {
  final String id;
  final String title;
  final String? emptyText;
  final String? symbol;
  final String? tabIcon;
  List<CarSection> sections;

  CarPage({
    required this.id,
    required this.title,
    this.sections = const [],
    this.emptyText,
    this.symbol,
    this.tabIcon,
  });
}

class CarRow {
  final String title;
  final String? subtitle;
  final String? image;
  final bool icon;
  final bool browsable;
  final bool playing;
  final Future<void> Function()? onTap;

  const CarRow({
    required this.title,
    this.subtitle,
    this.image,
    this.icon = false,
    this.browsable = false,
    this.playing = false,
    this.onTap,
  });
}

class CarSection {
  final String? header;
  final List<CarRow> rows;

  const CarSection({this.header, required this.rows});
}
