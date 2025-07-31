import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/bookings/bloc/booking_bloc.dart';
import 'package:abo_glumbo_bbk/pages/home/bloc/home_bloc.dart';
import 'package:abo_glumbo_bbk/pages/home/categories/bloc/categories_bloc.dart';
import 'package:abo_glumbo_bbk/pages/home/search/bloc/search_bloc.dart';
import 'package:abo_glumbo_bbk/pages/login/bloc/login_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

List<BlocProvider> providers = [
  BlocProvider<LoginBloc>(create: (context) => LoginBloc()),
  BlocProvider<AccountBloc>(create: (context) => AccountBloc()),
  BlocProvider<BookingBloc>(create: (context) => BookingBloc()),
  BlocProvider<SearchBloc>(create: (context) => SearchBloc()),
  BlocProvider<CategoriesBloc>(create: (context) => CategoriesBloc()),
  BlocProvider<HomeBloc>(create: (context) => HomeBloc()),
];
