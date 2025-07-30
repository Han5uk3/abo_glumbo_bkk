import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/login/bloc/login_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

List<BlocProvider> providers = [
  BlocProvider<LoginBloc>(create: (context) => LoginBloc()),
  BlocProvider<AccountBloc>(create: (context) => AccountBloc()),
];
