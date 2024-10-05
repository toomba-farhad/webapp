import 'dart:io';

import 'package:webapp/src/cli/core/cmd_console.dart';
import 'package:webapp/src/cli/core/cmd_controller.dart';
import 'package:webapp/src/tools/extensions/directory.dart';
import 'package:webapp/src/tools/path.dart';
import 'package:webapp/wa_server.dart';
import 'package:archive/archive_io.dart';

class ProjectCommands {
  Future<CmdConsole> get(CmdController controller) async {
    await Process.start(
      'dart',
      ['pub', 'get'],
      mode: ProcessStartMode.inheritStdio,
    );
    return CmdConsole("dart pub get", Colors.info);
  }

  Future<CmdConsole> runner(CmdController controller) async {
    await Process.start(
      'dart',
      ['run', 'build_runner', 'build'],
      mode: ProcessStartMode.inheritStdio,
    );
    return CmdConsole('dart run build_runner build', Colors.none);
  }

  Future<CmdConsole> run(CmdController controller) async {
    var path = controller.getOption('path');
    var defaultPath = [
      './bin',
      './lib',
      './src',
    ];

    var defaultApp = [
      'app.dart',
      'server.dart',
      'dart.dart',
      'example.dart',
      'run.dart',
      'watcher.dart',
    ];

    if (path.isEmpty) {
      for (var p in defaultPath) {
        for (var a in defaultApp) {
          var file = File(joinPaths([p, a]));
          if (file.existsSync()) {
            path = file.path;
            break;
          }
        }
      }
    }
    if (path.isEmpty) {
      path = CmdConsole.read(
        "Enter path of app file:",
        isRequired: true,
      );
      if (!File(path).existsSync()) {
        return run(controller);
      }
    } else {
      print("Running project from: $path");
    }

    var proccess = await Process.start(
      'dart',
      [
        'run',
        "--enable-asserts",
        path,
      ],
      mode: ProcessStartMode.inheritStdio,
      workingDirectory: File(path).parent.parent.path,
    );

    var help = "Project is running (${proccess.pid})...\n\n" +
        "┌┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬──────────┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┐\n" +
        "││││││││││││││││││││││  WEBAPP  │││││││││││││││││││││\n" +
        "├┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴──────────┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┤\n" +
        "│  * Press 'r' to Reload  the project               │\n" +
        "├───────────────────────────────────────────────────┤\n" +
        "│  * Press 'c' to clear screen                      │\n" +
        "├───────────────────────────────────────────────────┤\n" +
        "│  * Press 'i' to write info                        │\n" +
        "├───────────────────────────────────────────────────┤\n" +
        "│  * Press 'q' to quit the project                  │\n" +
        "└───────────────────────────────────────────────────┘\n";

    // Listen for user input in a separate loop
    stdin.listen((input) async {
      String userInput = String.fromCharCodes(input).trim();

      if (userInput.toLowerCase() == 'r') {
        CmdConsole.clear();
        CmdConsole.write("Restart project...", Colors.warnnig);
        proccess.kill();
        proccess = await Process.start(
          'dart',
          [
            'run',
            "--enable-asserts",
            path,
          ],
          mode: ProcessStartMode.inheritStdio,
        );
      } else if (['q', 'qy', 'qq'].contains(userInput.toLowerCase())) {
        var res = true;
        if (userInput.toLowerCase() == 'q') {
          res = CmdConsole.yesNo("Do you want to quit the project?");
        }
        if (res) {
          proccess.kill();
          exit(0);
        }
      } else if (userInput.toLowerCase() == 'c') {
        CmdConsole.clear();
      } else if (userInput.toLowerCase() == 'i') {
        CmdConsole.write("WebApp version: v${WaServer.info.version}");
        CmdConsole.write("Dart version: v${Platform.version}");
      } else {
        CmdConsole.write(
          "Unknown input: ${userInput.toLowerCase()}",
          Colors.error,
        );
        CmdConsole.write(help, Colors.success);
      }
    });

    return CmdConsole(help, Colors.success);
  }

  Future<CmdConsole> test(CmdController controller) async {
    var report = controller.getOption('reporter', def: '');

    await Process.start(
      'dart',
      [
        'test',
        if (report.isNotEmpty) ...['--reporter', '$report'],
      ],
      environment: {
        'WEBAPP_IS_TEST': 'true',
      },
      mode: ProcessStartMode.inheritStdio,
    );
    return CmdConsole("", Colors.off);
  }

  Future<CmdConsole> build(CmdController controller) async {
    if (controller.existsOption('h')) {
      var help = controller.manager.getHelp([controller]);
      return CmdConsole(help, Colors.none);
    }

    var path = controller.getOption('appPath', def: './lib/app.dart');
    if (path.isEmpty || !File(path).existsSync()) {
      return CmdConsole(
          "The path of main file dart is requirment. for example '--path ./bin/app.dart'",
          Colors.error);
    }

    var output = controller.getOption('output', def: './webapp_build');
    if (output == './webapp_build' && Directory(output).existsSync()) {
      Directory(output).deleteSync(recursive: true);
    } else if (Directory(output).existsSync()) {
      return CmdConsole(
        "The output path is requirment. for example '--output ./webapp_build'",
        Colors.error,
      );
    }
    Directory(output).createSync(recursive: true);

    var publicPath = controller.getOption('publicPath', def: './public');
    if (publicPath.isNotEmpty && Directory(publicPath).existsSync()) {
      var publicOutPutPath = joinPaths([output, 'public']);
      Directory(publicOutPutPath).createSync(recursive: true);
      await CmdConsole.progress(
        "Copy public files",
        () => Directory(publicPath).copyDirectory(Directory(publicOutPutPath)),
        type: ProgressType.circle,
      );
    }

    Directory('$output/lib').createSync(recursive: true);

    var langPath = controller.getOption('langPath', def: './lib/languages');
    if (langPath.isNotEmpty && Directory(langPath).existsSync()) {
      var langOutPutPath = joinPaths([output, 'lib/languages']);
      Directory(langOutPutPath).createSync(recursive: true);
      await CmdConsole.progress(
        "Copy Language files",
        () => Directory(langPath).copyDirectory(Directory(langOutPutPath)),
        type: ProgressType.circle,
      );
    }

    var widgetPath = controller.getOption('widgetPath', def: './lib/widgets');
    if (widgetPath.isNotEmpty && Directory(widgetPath).existsSync()) {
      var widgetOutPutPath = joinPaths([output, 'lib/widgets']);
      Directory(widgetOutPutPath).createSync(recursive: true);
      await CmdConsole.progress(
        "Copy widgets",
        () => Directory(widgetPath).copyDirectory(Directory(widgetOutPutPath)),
        type: ProgressType.circle,
      );
    }

    var envPath = controller.getOption('envPath', def: './.env');
    if (envPath.isNotEmpty && File(envPath).existsSync()) {
      File(envPath).copySync(joinPaths([output, 'lib', '.env']));
    } else {
      var envFile = File(joinPaths([output, 'lib', '.env']));
      envFile.createSync(recursive: true);
      envFile.writeAsStringSync([
        "WEBAPP_VERSION='${WaServer.info.version}'",
        "WEBAPP_BUILD_DATE='${DateTime.now().toUtc()}'",
      ].join('\n'));
    }

    var appPath = joinPaths([output, 'lib', 'app.exe']);
    var procces = await Process.start(
      'dart',
      ['compile', 'exe', path, '--output', appPath],
      mode: ProcessStartMode.inheritStdio,
    );

    var result = await CmdConsole.progress<int>(
      "Build project",
      () async {
        return await procces.exitCode;
      },
      type: ProgressType.circle,
    );

    if (result == 0) {
      var type = controller.getOption('type', def: 'exe');
      if (type == 'zip') {
        await CmdConsole.progress(
          "Compress output",
          () async {
            var encoder = ZipFileEncoder();
            String savePath = joinPaths(
              [
                Directory.systemTemp.path,
                'build_${DateTime.now().millisecondsSinceEpoch}.zip',
              ],
            );

            encoder.create(savePath);
            await encoder.addDirectory(Directory(output));
            encoder.closeSync();
            await Directory(output).cleanDirectory();
            File(savePath).renameSync(joinPaths([
              output,
              'webapp_build.zip',
            ]));
          },
          type: ProgressType.circle,
        );
      }
    }

    return CmdConsole('Finish build ${result == 0 ? 'OK!' : ''}', Colors.none);
  }
}
