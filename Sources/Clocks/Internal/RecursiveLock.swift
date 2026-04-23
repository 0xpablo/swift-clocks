#if canImport(Darwin)
  import Darwin
#elseif os(Windows)
  import ucrt
  import WinSDK
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#elseif canImport(Bionic)
  import Bionic
#elseif canImport(WASILibc)
  import WASILibc
  #if canImport(wasi_pthread)
    import wasi_pthread
  #endif
#else
  #error("The concurrency RecursiveLock module was unable to identify your C library.")
#endif

#if os(Windows)
  typealias RecursiveLockPrimitive = CRITICAL_SECTION
#else
  typealias RecursiveLockPrimitive = pthread_mutex_t
#endif

final class RecursiveLock: @unchecked Sendable {
  private var primitive = RecursiveLockPrimitive()

  init() {
    #if os(Windows)
      InitializeCriticalSection(&self.primitive)
    #else
      var attr = pthread_mutexattr_t()
      var err = pthread_mutexattr_init(&attr)
      precondition(err == 0, "\(#function) failed in pthread_mutexattr_init with error \(err)")
      defer {
        err = pthread_mutexattr_destroy(&attr)
        precondition(
          err == 0, "\(#function) failed in pthread_mutexattr_destroy with error \(err)"
        )
      }

      err = pthread_mutexattr_settype(&attr, Int32(PTHREAD_MUTEX_RECURSIVE))
      precondition(err == 0, "\(#function) failed in pthread_mutexattr_settype with error \(err)")

      err = pthread_mutex_init(&self.primitive, &attr)
      precondition(err == 0, "\(#function) failed in pthread_mutex_init with error \(err)")
    #endif
  }

  deinit {
    #if os(Windows)
      DeleteCriticalSection(&self.primitive)
    #else
      let err = pthread_mutex_destroy(&self.primitive)
      precondition(err == 0, "\(#function) failed in pthread_mutex_destroy with error \(err)")
    #endif
  }

  func lock() {
    #if os(Windows)
      EnterCriticalSection(&self.primitive)
    #else
      let err = pthread_mutex_lock(&self.primitive)
      precondition(err == 0, "\(#function) failed in pthread_mutex_lock with error \(err)")
    #endif
  }

  func unlock() {
    #if os(Windows)
      LeaveCriticalSection(&self.primitive)
    #else
      let err = pthread_mutex_unlock(&self.primitive)
      precondition(err == 0, "\(#function) failed in pthread_mutex_unlock with error \(err)")
    #endif
  }

  func withLock<T>(_ body: () throws -> T) rethrows -> T {
    self.lock()
    defer { self.unlock() }
    return try body()
  }
}
