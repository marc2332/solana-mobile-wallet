import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:reactor_wallet/dialogs/prepare_transaction.dart';
import 'package:reactor_wallet/utils/base_account.dart';
import 'package:reactor_wallet/utils/tracker.dart';
import 'package:reactor_wallet/utils/wallet_account.dart';
import 'package:solana/solana.dart';

String? transactionAddressValidator(String? value) {
  if (value == null || value.isEmpty) {
    return 'Empty address';
  }
  if (value.length < 43 || value.length > 50) {
    return 'Address length is not correct';
  } else {
    return null;
  }
}

String? transactionAmountValidator(String? value) {
  if (value == null || value.isEmpty) {
    return 'Empty ammount';
  }
  if (double.parse(value) <= 0) {
    return 'You must send at least 0.000000001 SOL';
  } else {
    return null;
  }
}

Future<void> sendTransactionDialog(
  BuildContext context,
  WalletAccount walletAccount, {
  String initialDestination = "",
  double initialSendAmount = 0,
  String defaultTokenSymbol = "SOL",
  List<String> references = const [],
}) async {
  String destination = initialDestination;
  double sendAmount = initialSendAmount;

  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return HookConsumer(builder: (context, ref, _) {
        // Retrieve all the tokens owned by the account
        List<Token> tokens = List.from(walletAccount.tokens);

        // Add Solana like if it was a Token just to make the UX easier
        tokens.insert(
          0,
          Token(
            walletAccount.balance,
            SystemProgram.programId,
            TokenInfo(name: "Solana", symbol: "SOL"),
          ),
        );

        final selectedToken = useState(
          tokens.firstWhere(
            (token) => token.info.symbol == defaultTokenSymbol,
          ),
        );

        return AlertDialog(
          title: const Text('Transfer'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButton<String>(
                  iconSize: 20,
                  value: selectedToken.value.info.symbol,
                  icon: const Icon(Icons.arrow_downward),
                  underline: Container(),
                  onChanged: (String? tokenSymbol) {
                    if (tokenSymbol != null) {
                      selectedToken.value = tokens.firstWhere(
                        (token) => token.info.symbol == tokenSymbol,
                      );
                    }
                  },
                  items: tokens.map<DropdownMenuItem<String>>((Token token) {
                    return DropdownMenuItem<String>(
                      value: token.info.symbol,
                      child: Text(token.info.symbol + (token is NFT ? ' - NFT' : '')),
                    );
                  }).toList(),
                ),
                ListBody(
                  children: <Widget>[
                    Form(
                      autovalidateMode: AutovalidateMode.always,
                      child: TextFormField(
                        initialValue: initialDestination,
                        validator: transactionAddressValidator,
                        decoration: InputDecoration(
                          hintText: walletAccount.address,
                        ),
                        onChanged: (String value) async {
                          destination = value;
                        },
                      ),
                    ),
                    Form(
                      autovalidateMode: AutovalidateMode.always,
                      child: TextFormField(
                        initialValue: initialSendAmount.toString(),
                        validator: transactionAmountValidator,
                        decoration: const InputDecoration(
                          hintText: 'Amount',
                        ),
                        onChanged: (String value) async {
                          sendAmount = double.parse(value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Send'),
              onPressed: () async {
                bool addressIsOk = transactionAddressValidator(destination) == null;
                bool balanceIsOk = transactionAmountValidator(sendAmount.toString()) == null;

                // Only let send if the address and the ammount is OK
                if (addressIsOk && balanceIsOk) {
                  // Close the dialog
                  Navigator.of(dialogContext).pop();

                  Transaction tx = Transaction(
                    walletAccount.address,
                    destination,
                    sendAmount,
                    false,
                    selectedToken.value.mint,
                  );

                  tx.references = references;

                  prepareTransaction(context, tx, walletAccount, selectedToken.value);
                }
              },
            ),
          ],
        );
      });
    },
  );
}
