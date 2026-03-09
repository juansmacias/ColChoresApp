import 'package:bloc_test/bloc_test.dart';
import 'package:family_chores_app/core/deep_links/deep_link_redirect_cubit.dart';

void main() {
  blocTest<DeepLinkRedirectCubit, Uri?>(
    'stores and clears a pending deep link',
    build: DeepLinkRedirectCubit.new,
    act: (cubit) {
      cubit.setPendingLink(
        Uri.parse('https://familychores.app/join?code=ABC123'),
      );
      cubit.clearPendingLink();
    },
    expect: () => [
      Uri.parse('https://familychores.app/join?code=ABC123'),
      null,
    ],
  );
}
