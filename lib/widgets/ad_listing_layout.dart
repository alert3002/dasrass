/// Фиксированные размеры карточки объявления (как «Рекомендация» на главной).
class AdListingCardLayout {
  AdListingCardLayout._();

  static const double pagePaddingH = 16;
  static const double gridTopPadding = 12;
  static const double gridGap = 8;

  static const double bodyPaddingH = 8;
  static const double bodyPaddingTop = 8;
  static const double bodyPaddingBottom = 10;
  static const double titleBlockHeight = 32.5;
  static const double gapAfterTitle = 4;
  static const double priceBlockHeight = 17;
  static const double gapAfterPrice = 2;
  static const double locationBlockHeight = 15.6;
  static const double gapAfterLocation = 2;
  static const double timeBlockHeight = 13.75;

  static const double bodyHeight =
      bodyPaddingTop +
      titleBlockHeight +
      gapAfterTitle +
      priceBlockHeight +
      gapAfterPrice +
      locationBlockHeight +
      gapAfterLocation +
      timeBlockHeight +
      bodyPaddingBottom;
}
