import 'dart:convert';

import 'package:webapp/wa_tools.dart';
import 'package:webapp/src/render/web_request.dart';
import 'package:mongo_dart/mongo_dart.dart';

class WaJson {
  static String jsonEncoder(Object data, {WebRequest? rq}) {
    return jsonEncode(data, toEncodable: (obj) {
      if (obj == null) {
        return null;
      }
      if (obj is TString) {
        return obj.write(rq!);
      }
      if (obj is ObjectId) {
        return obj.oid;
      }
      if (obj is DateTime) {
        return obj.toString();
      }
      if (obj is Duration) {
        return obj.toString();
      }

      return obj.toString();
    });
  }

  static dynamic jsonDecoder(String data) {
    return jsonDecode(data);
  }
}
