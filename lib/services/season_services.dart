class SeasonService {

  static String getCurrentSeason() {

    int month = DateTime.now().month;

    if(month >= 3 && month <= 4) {
      return "Spring";
    }

    if(month >= 5 && month <= 8) {
      return "Summer";
    }

    if(month >= 9 && month <= 11) {
      return "Autumn";
    }

    return "Winter";
  }
}