import 'package:cosmodrome/services/local_storage_backend.dart';
import 'package:cosmodrome/services/local_storage_backend_web.dart';

LocalStorageBackend createLocalStorageBackend() => WebLocalStorageBackend();
