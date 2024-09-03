import 'dart:convert';
import 'package:webapp/wa_tools.dart';

import '../render/web_request.dart';

typedef ValidatorEvent<T> = FieldValidateResult Function(T value);

/// A class for validating form data using customizable field validators.
///
/// The `FormValidator` class allows defining validation rules for form fields
/// and then validating input data against those rules. It also handles error
/// reporting and formatting for easy form validation and feedback display.
class FormValidator {
  /// The web request instance containing the form data to validate.
  WebRequest rq;

  /// A map of field names to a list of validator events that will be applied to them.
  Map<String, List<ValidatorEvent>> fields;

  /// The value to indicate a field is valid.
  Object success;

  /// The value to indicate a field is invalid.
  Object failed;

  /// The name of the form or validation context. we will use this name in front-end and api key.
  String name;

  /// Additional data that can be used in validation, not coming directly from the request.
  Map<String, Object> extraData;

  /// Constructor to initialize the `FormValidator`.
  ///
  /// Parameters:
  /// - [rq]: The web request object containing form data. (required)
  /// - [fields]: A map of fields to validate with their respective validation rules. (required)
  /// - [name]: The name of the form or validation context. (required)
  /// - [failed]: The value to mark a field as invalid. (optional, defaults to 'is-invalid')
  /// - [success]: The value to mark a field as valid. (optional, defaults to an empty string)
  /// - [extraData]: Additional data to be considered during validation. (optional, defaults to an empty map)
  FormValidator({
    required this.rq,
    required this.fields,
    required this.name,
    this.failed = 'is-invalid',
    this.success = '',
    this.extraData = const {},
  });

  /// Validates the form data and returns a boolean result.
  ///
  /// If [data] is provided, it will be used instead of loading data from the request.
  ///
  /// Returns `true` if all validations pass, otherwise `false`.
  Future<bool> validate({
    Map data = const {},
  }) async {
    var res = await validateAndForm(data: data);
    return res.result;
  }

  /// Validates the form data and returns both the result and the validated form structure.
  ///
  /// The validated form structure contains information about the validation results,
  /// including error messages, the validity state, and field values.
  ///
  /// If [data] is provided, it will be used instead of loading data from the request.
  ///
  /// Returns a tuple containing:
  /// - [result]: The overall validation result (true if all validations pass).
  /// - [form]: A map of the form structure containing field validation details.
  Future<({bool result, Map<String, dynamic> form})> validateAndForm({
    Map data = const {},
  }) async {
    bool result = true;
    var thisForm = <String, dynamic>{};

    for (var fieldName in fields.keys) {
      var fieldResult = <String, dynamic>{};
      Object fieldValue;
      if (data.isEmpty) {
        fieldValue = rq.data(fieldName);
      } else {
        fieldValue = data[fieldName] ?? extraData[fieldName];
      }

      fieldResult["value"] = fieldValue;

      var fieldEvents = fields[fieldName] ?? [];

      var success = true;
      var errors = [];
      for (var validateField in fieldEvents) {
        FieldValidateResult check = validateField(fieldValue);
        if (!check.success) {
          success = false;
        }

        errors.addAll(check.errors);
      }

      fieldResult['valid'] = success ? this.success : failed;
      fieldResult['error'] = errors.join(',');
      fieldResult['errorHtml'] = errors.join('<br/>');
      fieldResult['errors'] = errors;
      fieldResult['success'] = success;
      fieldResult['failed'] = !success;
      if (!success) {
        result = false;
      }

      thisForm[fieldName] = fieldResult;
    }

    extraData.forEach((key, value) {
      if (!thisForm.containsKey(key)) {
        thisForm[key] = {
          'success': true,
          'failed': false,
          'error': '',
          'errors': [],
          'errorHtml': '',
          'valid': success,
          'value': value,
        };
      }
    });

    rq.addValidator(name, thisForm);

    return (result: result, form: thisForm);
  }

  /// Creates and returns a `FormValidator` instance with empty validators for all fields in [data].
  ///
  /// Useful for initializing a validator instance without predefined validation rules.
  ///
  /// Parameters:
  /// - [rq]: The web request object containing form data. (required)
  /// - [name]: The name of the form or validation context. (required)
  /// - [data]: A map representing the fields to validate. (required)
  ///
  /// Returns a `FormValidator` instance.
  static Future<FormValidator> filling({
    required WebRequest rq,
    required String name,
    required Map data,
  }) async {
    var fields = <String, List<ValidatorEvent>>{};
    for (var item in data.keys) {
      fields[item] = <ValidatorEvent>[];
    }

    final emptyValidator = FormValidator(rq: rq, fields: fields, name: name);
    await emptyValidator.validate(data: data);
    return emptyValidator;
  }
}

/// A class representing the result of a field validation.
///
/// The `FieldValidateResult` contains information about whether a field is valid,
/// any error messages, and a combined error message for easy access.
class FieldValidateResult {
  /// Whether the validation was successful.
  bool success;

  /// A list of error messages returned from the validation.
  List<String> errors;

  /// A combined error message, usually representing the first error.
  String error;

  /// Constructor for `FieldValidateResult`.
  ///
  /// If [error] is provided and not empty, it is added to the [errors] list automatically.
  FieldValidateResult({
    this.success = false,
    this.errors = const [],
    this.error = '',
  }) {
    if (error.isNotEmpty) {
      errors = [...errors, error];
    }
  }
}

/// A utility class providing common field validators.
///
/// The `FieldValidator` class contains static methods for common validation tasks,
/// such as checking if a field is required, validating the length of a string,
/// or ensuring a field is a number or an email address.
class FieldValidator {
  /// Validator to check if a field is required (non-null and non-empty).
  static ValidatorEvent requiredField() => (value) {
        var res = (value != null && value.toString().trim().isNotEmpty);
        return FieldValidateResult(
          success: res,
          error: res ? '' : 'error.field.required',
        );
      };

  /// Validator to check if a field is required in multiple languages.
  ///
  /// This validator expects a JSON object with language keys and checks if at least
  /// one value is non-null and non-empty.
  static ValidatorEvent requiredFieldMultiLanguage() {
    return (value) {
      var res = (value != null && value.toString().trim().isNotEmpty);

      if (!res) {
        return FieldValidateResult(
          success: res,
          error: res ? '' : 'error.field.required',
        );
      }

      Map<String, String> resMap = {};

      try {
        var json = jsonDecode(value.toString());
        for (var key in json.keys) {
          if (json[key] != null && json[key]!.trim().isNotEmpty) {
            resMap[key] = json[key]!.trim();
          }
        }
      } catch (e) {
        resMap = {};
      }

      return FieldValidateResult(
        success: resMap.isNotEmpty,
        error: resMap.isNotEmpty ? '' : 'error.field.required',
      );
    };
  }

  /// Validator to check if a field's length falls within a specified range.
  ///
  /// - [max]: The maximum allowed length.
  /// - [min]: The minimum allowed length.
  static ValidatorEvent fieldLength({
    int? max,
    int? min,
  }) {
    return (value) {
      var res = true;
      var error = <String>[];

      if (max != null) {
        if (value.toString().length > max) {
          res = false;
          error.add('error.field.max#{$max}');
        }
      }

      if (min != null) {
        if (value.toString().length < min) {
          res = false;
          error.add('error.field.min#{$min}');
        }
      }

      return FieldValidateResult(
        success: res,
        error: res ? '' : 'error.field',
        errors: error,
      );
    };
  }

  /// Validator to check if a field is a valid number within optional bounds.
  ///
  /// - [max]: The maximum allowed value.
  /// - [min]: The minimum allowed value.
  /// - [isRequired]: Whether the field is required (non-null). Defaults to `false`.
  static ValidatorEvent isNumberField({
    int? max,
    int? min,
    bool isRequired = false,
  }) {
    return (value) {
      var res = true;
      var error = <String>[];

      if (value != null) {
        if (!value.toString().isInt) {
          res = false;
          error.add('error.field.numeric');
        } else {
          if (max != null) {
            if (value.toString().toInt() > max) {
              res = false;
              error.add('error.field.max#{$max}');
            }
          }

          if (min != null) {
            if (value.toString().toInt() < min) {
              res = false;
              error.add('error.field.min#{$min}');
            }
          }
        }
      } else if (isRequired) {
        res = false;
        error.add('error.field.required');
      }

      return FieldValidateResult(
        success: res,
        error: res ? '' : 'error.field',
        errors: error,
      );
    };
  }

  /// Validator to check if a field contains a valid email address.
  ///
  /// The validator checks whether the provided value is non-null, is a non-empty
  /// string, and matches the format of an email address. If the validation fails,
  /// an error message `'error.field.email'` is returned.
  ///
  /// Returns:
  /// - `FieldValidateResult`: A result indicating whether the validation passed or failed,
  ///    including any associated error messages.
  static ValidatorEvent isEmailField() => (value) {
        var res = (value != null && value.toString().trim().isEmail);
        return FieldValidateResult(
          success: res,
          error: res ? '' : 'error.field.email',
        );
      };
}
