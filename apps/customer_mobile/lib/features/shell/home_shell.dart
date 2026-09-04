import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/auth_token_provider.dart';
import '../../core/auth/auth_token_storage.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_event.dart';
import '../auth/data/auth_repository.dart';
import '../cart/bloc/cart_state.dart';
import '../cart/bloc/checkout_cubit.dart';
import '../cart/bloc/customer_cart_bloc.dart';
import '../cart/data/orders_repository.dart';
import '../cart/view/cart_screen.dart';
import '../menu/bloc/order_type.dart';
import '../menu/bloc/menu_bloc.dart';
import '../menu/bloc/menu_event.dart';
import '../menu/data/menu_repository.dart';
import '../menu/view/menu_screen.dart';
import '../orders/bloc/order_history_bloc.dart';
import '../orders/data/order_history_repository.dart';
import '../orders/view/order_history_screen.dart';
import '../profile/view/profile_screen.dart';

/// Mobile shell with the bottom navigation: Меню, Корзина, Заказы, Профиль.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    required this.ordersRepository,
    required this.authRepository,
    required this.tokenStorage,
    required this.tokenProvider,
    required this.orderHistoryRepository,
  });

  final CustomerMenuRepository repository;
  final CustomerOrdersRepository ordersRepository;
  final AuthRepository authRepository;
  final AuthTokenStorage tokenStorage;
  final AuthTokenProvider tokenProvider;
  final OrderHistoryRepository orderHistoryRepository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CustomerCartBloc>(create: (_) => CustomerCartBloc()),
        BlocProvider<CheckoutCubit>(
          create: (_) => CheckoutCubit(repository: widget.ordersRepository),
        ),
        BlocProvider<OrderTypeCubit>(create: (_) => OrderTypeCubit()),
        BlocProvider<MenuBloc>(
          create: (_) => MenuBloc(repository: widget.repository)
            ..add(MenuStarted()),
        ),
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(
            repository: widget.authRepository,
            tokenStorage: widget.tokenStorage,
            tokenProvider: widget.tokenProvider,
          )..add(const AuthStarted()),
        ),
        BlocProvider<OrderHistoryBloc>(
          create: (_) =>
              OrderHistoryBloc(repository: widget.orderHistoryRepository),
        ),
      ],
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: IndexedStack(
              index: _tab,
              children: [
                const MenuScreen(),
                CartScreen(onGoToMenu: () => setState(() => _tab = 0)),
                OrderHistoryScreen(
                  onGoToCart: () => setState(() => _tab = 1),
                ),
                const ProfileScreen(),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (index) => setState(() => _tab = index),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.restaurant_menu_outlined),
                  label: 'Меню',
                ),
                NavigationDestination(
                  icon: BlocBuilder<CustomerCartBloc, CartState>(
                    builder: (context, cart) {
                      return Badge(
                        isLabelVisible: cart.itemCount > 0,
                        label: Text('${cart.itemCount}'),
                        child: const Icon(Icons.shopping_cart_outlined),
                      );
                    },
                  ),
                  label: 'Корзина',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: 'Заказы',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Профиль',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
