import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

/// Mobile shell with the bottom navigation: Меню, Корзина, Заказы, Профиль.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    required this.ordersRepository,
  });

  final CustomerMenuRepository repository;
  final CustomerOrdersRepository ordersRepository;

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
      ],
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: IndexedStack(
              index: _tab,
              children: [
                const MenuScreen(),
                CartScreen(onGoToMenu: () => setState(() => _tab = 0)),
                _PlaceholderTab(
                  title: 'Заказы',
                  icon: Icons.receipt_long_outlined,
                ),
                _PlaceholderTab(
                  title: 'Профиль',
                  icon: Icons.person_outline,
                ),
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

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            Text(
              '$title — скоро будет',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
