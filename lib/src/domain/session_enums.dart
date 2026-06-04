enum SessionPhase {
  idle,
  discovering,
  ready,
  permissionRequested,
  starting,
  streaming,
  stopping,
  error,
}

enum LogLevel { debug, info, warning, error }

enum LogTopic { system, device, permission, session, error }
