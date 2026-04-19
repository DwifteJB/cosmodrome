// choose between local storage backends based on platform
// web does not have storage
export 'local_storage_backend_factory_stub.dart'
    if (dart.library.io) 'local_storage_backend_factory_io.dart'
    if (dart.library.html) 'local_storage_backend_factory_web.dart';
