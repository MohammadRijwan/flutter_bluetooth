import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:intl/intl.dart';

//U 32,0,0,128,0,0,0,18765,100,200,300,400,500,600,700,12300,1001,1002
class DataConvertor {
  static final q32ResponseRegex = RegExp(r"U[,|\s][0-3][0-9]");
  static final fuseSaverResponseRegex = RegExp(r"DF[\s]");
  static final airPressureResponseRegex =
      RegExp(r"AIR[\s]", caseSensitive: false);

  static List<int> encode(String message) {
    message = message.toUpperCase();
    if (message != null && !message.endsWith("\n")) {
      message = message + "\n";
    }
    return utf8.encode(message);
  }

  static String? decode(List<int> value) {
    if (value != null && value.isNotEmpty) {
      return utf8.decode(value);
    }
    return null;
  }

  static String? decodeUtf8(List<int> value) {
    if (value != null && value.isNotEmpty) {
      return utf8.decode(value);
    }
    return null;
  }

  static String getUtf8FormattedData(List<int> data) {
    try {
      final String utf8Data = utf8.decode(data);
      print('bluetooth interactor utf8Data:$utf8Data');
      return '${getDateTime()}:$utf8Data';
    } catch (e) {
      print(
          ' getFormattedData() ${getDateTime()} Format Exception ${e.toString()}');
      return '${getDateTime()},rawData:$data';
    }
  }

  static String getHexFormattedData(List<int> data) {
    try {
      final String hexString = hex.encode(data);
      print('bluetooth interactor HexData:$hexString');
      return '${getDateTime()}:$hexString';
    } catch (e) {
      print(
          ' getFormattedData() ${getDateTime()} Format Exception ${e.toString()}');
      return '${getDateTime()},rawData:$data';
    }
  }

  static String getDateTime() {
    var formatter = new DateFormat('yyyy-MM-dd_hh:mm:ss');
    return formatter.format(DateTime.now());
  }

  static String getDateTimeMillis() {
    var formatter = new DateFormat('yyyy-MM-dd_hh:mm:ss:SSS');
    return formatter.format(DateTime.now());
  }

  // static Q32Response? getQ32Response(String message) {
  //   var match = q32ResponseRegex.firstMatch(message);
  //   if (match != null) {
  //     List<String> elemList = <String>[];
  //     elemList
  //         .addAll(message.substring(match.end).split(",").map((s) => s.trim()));
  //     return Q32Response.fromArray(elemList);
  //   }
  //   return null;
  // }

  static bool isValidQ32Response(String message) {
    return q32ResponseRegex.firstMatch(message) == null ? false : true;
  }

  // static FuseSaverResponse? getFuseSaverResponse(String message) {
  //   var match = fuseSaverResponseRegex.firstMatch(message);
  //   if (match != null) {
  //     List<String> elemList = <String>[];
  //     elemList
  //         .addAll(message.substring(match.end).split(",").map((s) => s.trim()));
  //     return FuseSaverResponse.fromArray(elemList);
  //   }
  //   return null;
  // }

  static bool isValidFuseSaverResponse(String message) {
    return fuseSaverResponseRegex.firstMatch(message) == null ? false : true;
  }

  static bool isValidAirResponse(String message) {
    return airPressureResponseRegex.firstMatch(message) == null ? false : true;
  }

  // static AirPressueResponse? getAirPressureResponse(String message) {
  //   var match = airPressureResponseRegex.firstMatch(message);
  //   if (match != null) {
  //     List<String> elemList = <String>[];
  //     elemList
  //         .addAll(message.substring(match.end).split(",").map((s) => s.trim()));
  //     return AirPressueResponse.fromArray(elemList);
  //   }
  //   return null;
  // }

  static String convertSubUnitToFullUnit(String? value,
      {int divisor = 1000,
      String defaultValue = '',
      int decimalPrecision = 1}) {
    try {
      if (value != null && value != '') {
        double subUnit = double.parse(value);
        if (subUnit == 0.0) {
          return defaultValue;
        }
        double fullUnit = subUnit / divisor;
        print('k ${fullUnit.toStringAsFixed(decimalPrecision)} ');
        return fullUnit.toStringAsFixed(decimalPrecision);
      }
    } catch (e) {
      print(e);
      return defaultValue;
    }
    return defaultValue;
  }

  static String convertFullUnitToSubUnit(String? value,
      {int multiplier = 1000,
      String defaultValue = '',
      int decimalPrecision = 1}) {
    try {
      if (value != null && value != '') {
        double fullUnit = double.parse(value);
        if (fullUnit == 0.0) {
          return defaultValue;
        }
        double subUnit = fullUnit * multiplier;
        print('k ${subUnit.toStringAsFixed(decimalPrecision)} ');
        return subUnit.toStringAsFixed(decimalPrecision);
      }
    } catch (e) {
      print(e);
      return defaultValue;
    }
    return defaultValue;
  }

  static bool isValueGreater(String value1, String value2) {
    try {
      if (value1 != null && value1 != '' && value2 != null && value2 != '') {
        double dValue1 = double.parse(value1);
        double dValue2 = double.parse(value2);
        return dValue1 > dValue2;
      }
    } catch (e) {
      print(e);
      return false;
    }
    return false;
  }

  static bool isBitZeroAtPosition(int byteValue, int position) {
    String binaryString = byteValue.toRadixString(2);
    return binaryString[8 - position] == '0';
  }
}
