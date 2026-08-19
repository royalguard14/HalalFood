class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  Future<void> login({
    required String email,
    required String password,
  }) async {
    // Real authentication API will be connected here.
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    // Real registration API will be connected here.
  }

  Future<void> logout() async {
    // Real logout will be connected here.
  }
}