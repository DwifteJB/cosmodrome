enum SubsonicError {
  genericError,
  missingParameter,
  incompatibleClientVersion,
  incompatibleServerVersion,
  wrongCredentials,
  tokenAuthNotSupported,
  userNotAuthorized,
  trialPeriodOver,
  dataNotFound,
}

SubsonicError getErrorFromCode(int code) {
  switch (code) {
    case 0:
      return SubsonicError.genericError;
    case 10:
      return SubsonicError.missingParameter;
    case 20:
      return SubsonicError.incompatibleClientVersion;
    case 30:
      return SubsonicError.incompatibleServerVersion;
    case 40:
      return SubsonicError.wrongCredentials;
    case 41:
      return SubsonicError.tokenAuthNotSupported;
    case 50:
      return SubsonicError.userNotAuthorized;
    case 60:
      return SubsonicError.trialPeriodOver;
    case 70:
      return SubsonicError.dataNotFound;
    default:
      return SubsonicError.genericError;
  }
}

String errorToSensibleNames(SubsonicError error) {
  switch (error) {
    case SubsonicError.genericError:
      return 'Generic error';
    case SubsonicError.missingParameter:
      return 'Missing parameter';
    case SubsonicError.incompatibleClientVersion:
      return 'Incompatible client version';
    case SubsonicError.incompatibleServerVersion:
      return 'Incompatible server version';
    case SubsonicError.wrongCredentials:
      return 'Wrong credentials';
    case SubsonicError.tokenAuthNotSupported:
      return 'Token authentication not supported';
    case SubsonicError.userNotAuthorized:
      return 'User not authorized';
    case SubsonicError.trialPeriodOver:
      return 'Trial period over';
    case SubsonicError.dataNotFound:
      return 'Data not found';
  }
}
