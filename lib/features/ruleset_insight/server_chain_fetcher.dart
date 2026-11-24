import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/ruleset_insight/server_chain.dart';
import 'package:flutter/services.dart';

const String serverChainScriptAsset = 'assets/tool/fetch-server-chain.ps1';
const String serverChainScriptName = 'fetch-server-chain.ps1';

class ServerChainFetchResult {
  const ServerChainFetchResult({this.chain, this.error});

  final ServerChain? chain;
  final String? error;

  bool get ok => error == null;
}

class ServerChainFetcher {
  static Future<String> ensureScript() async {
    final home = await appPath.homeDirPath;
    final dir = Directory('$home${Platform.pathSeparator}tool');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File(
      '${dir.path}${Platform.pathSeparator}$serverChainScriptName',
    );
    final data = await rootBundle.load(serverChainScriptAsset);
    final bytes = data.buffer.asUint8List();
    if (!file.existsSync() || file.lengthSync() != bytes.length) {
      file.writeAsBytesSync(bytes);
    }
    return file.path;
  }

  static Future<ServerChainFetchResult> refresh(List<String> servers) async {
    String? host;
    for (final item in servers) {
      if (item.trim().isNotEmpty) {
        host = item.trim();
        break;
      }
    }
    if (host == null) {
      return const ServerChainFetchResult(error: 'no proxy server in config');
    }
    try {
      final script = await ensureScript();
      final home = await appPath.homeDirPath;
      final out = '$home${Platform.pathSeparator}$serverChainFileName';
      final result = await _run(script, host, out);
      if (result == null) {
        return const ServerChainFetchResult(
          error: 'PowerShell (pwsh/powershell) not found',
        );
      }
      if (result.exitCode != 0) {
        final message = '${result.stderr}'.trim();
        return ServerChainFetchResult(
          error: message.isEmpty
              ? 'script exited with ${result.exitCode}'
              : message,
        );
      }
      final chain = await ServerChain.load();
      if (chain == null) {
        return const ServerChainFetchResult(error: 'summary file not written');
      }
      return ServerChainFetchResult(chain: chain);
    } catch (error) {
      return ServerChainFetchResult(error: error.toString());
    }
  }

  static Future<ProcessResult?> _run(
    String script,
    String host,
    String out,
  ) async {
    final args = [
      '-NoProfile',
      '-File',
      script,
      '-SshHost',
      host,
      '-Out',
      out,
    ];
    for (final shell in const ['pwsh', 'powershell']) {
      try {
        return await Process.run(shell, args, runInShell: true);
      } on ProcessException {
        continue;
      }
    }
    return null;
  }
}
