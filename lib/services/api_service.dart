class ApiService {
  Future<String> fetchData() async {
    await Future.delayed(Duration(seconds: 1));
    return "Datos de la API";
  }
}