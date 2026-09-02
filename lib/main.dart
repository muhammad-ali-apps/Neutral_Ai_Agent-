import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'package:go_router/go_router.dart';
import 'services/api_services.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'widgets/home_shell.dart';
import 'screens/admin_panel_screen.dart';

void main() {
  runApp(const NeuroRouteApp());
}
class NeuroRouteApp extends StatefulWidget {
  const NeuroRouteApp({super.key});

  @override
  State<NeuroRouteApp> createState() => _NeuroRouteAppState();
}

class _NeuroRouteAppState extends State<NeuroRouteApp> {
  bool _isDarkMode = true;

  void _toggleTheme() => setState(() => _isDarkMode = !_isDarkMode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NeuroRoute - AI Router',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    );
  }
  
  late final GoRouter _router = GoRouter(
    initialLocation: '/home', // App start hone par kahan jaye
    
    // YEH HAI AAPKA MAIN CHECK (Global Redirect)
    redirect: (BuildContext context, GoRouterState state) async {
      // 1. Check karein ke kya user logged in hai (Aapki API call)
      final bool isLoggedIn = await ApiService.isUserLoggedIn();
      
      // 2. User abhi kis page par jana chahta hai?
      final bool isGoingToLogin = state.matchedLocation == '/login';
      final bool isGoingToSignup = state.matchedLocation == '/signup';
      // 3. Logic: Agar login nahi hai, aur woh login/signup par bhi nahi ja raha..
      if (!isLoggedIn && !isGoingToLogin && !isGoingToSignup) {
        return '/login'; // ..to usay zabardasti Login par bhej do!
      }
      // 4. Logic: Agar logged in hai, aur phir bhi login page kholne ki koshish kare..
      if (isLoggedIn && (isGoingToLogin || isGoingToSignup)) {
        return '/home'; // ..to usay Home par bhej do!
      }
      // Agar sab theek hai, to jahan ja raha hai janay do (return null)
      return null; 
    },
    // YAHAN AAP APNE ROUTES (PAGES) DEFINE KARTE HAIN
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return  LoginScreen(isDarkMode: _isDarkMode, onToggleTheme: _toggleTheme); // Apne parameters theek kar lijiye ga
        },
      ),
      GoRoute(
        path: '/signup',
        builder: (BuildContext context, GoRouterState state) {
          return  SignupScreen(isDarkMode: false, onToggleTheme: () {});
        },
      ),
      GoRoute(
        path: '/home',
        builder: (BuildContext context, GoRouterState state) {
          return  HomeShell(isDarkMode: _isDarkMode, onToggleTheme: _toggleTheme);
        },
      ),
      GoRoute(
        path: '/admin-panel',
        builder: (BuildContext context, GoRouterState state) {
          return  HomeShell(isDarkMode: _isDarkMode, onToggleTheme: _toggleTheme, startWithAdmin: true);
        },
      ),
    ],
  );
}
