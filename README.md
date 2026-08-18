# Nutri Expert

Aplicacion integral de gestion nutricional infantil, con graficos de seguimiento y almacenamiento local.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)

8 commits, multiplataforma (Android, iOS, Windows, Linux, macOS, Web)

## Captura

Aun no hay captura publicada: requiere el SDK de Flutter para compilar. Se puede generar con `flutter pub get` seguido de `flutter run -d chrome` (o -d windows / -d android).

## Sobre el proyecto

A comprehensive nutritional management app for children: gestion del estado nutricional infantil con visualizacion de datos mediante graficos, pensada para funcionar incluso sin conexion gracias a almacenamiento local.

## Stack tecnico

Flutter y Dart, con sqflite, sqflite_common_ffi y sqlite3_flutter_libs para base de datos local (incluye soporte Windows), fl_chart para graficos, y shared_preferences para preferencias del usuario.

## Como correrlo

```bash
git clone https://github.com/RichardEsteban/TriajeFlutterApp.git
cd TriajeFlutterApp
flutter pub get
flutter run
```

## Estado

En desarrollo activo (8 commits); la app ya soporta persistencia en Windows ademas de movil.

---

Desarrollado por Richard Esteban
