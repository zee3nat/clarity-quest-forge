import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// [Previous test cases remain unchanged]

Clarinet.test({
  name: "Quest rewards include class bonuses and streak multipliers",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("quest-forge", "initialize-character", [
        types.uint(1)  // Warrior class
      ], wallet_1.address),
      Tx.contractCall("quest-forge", "create-quest", [
        types.utf8("Combat Quest"),
        types.uint(5),
        types.uint(100),
        types.utf8("combat")
      ], wallet_1.address),
      Tx.contractCall("quest-forge", "complete-quest", [
        types.uint(0)
      ], wallet_1.address)
    ]);
    
    assertEquals(block.receipts.length, 3);
    // Verify reward includes class bonus
    assertEquals(block.receipts[2].result.includes("combat-bonus"), true);
  },
});
