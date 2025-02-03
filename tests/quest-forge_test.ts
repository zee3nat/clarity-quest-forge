import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure user can initialize character",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("quest-forge", "initialize-character", [], wallet_1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    assertEquals(block.receipts[0].result, "(ok true)");
  },
});

Clarinet.test({
  name: "Can create and complete quest",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("quest-forge", "initialize-character", [], wallet_1.address),
      Tx.contractCall("quest-forge", "create-quest", [
        types.utf8("Test Quest"),
        types.uint(1)
      ], wallet_1.address),
      Tx.contractCall("quest-forge", "complete-quest", [
        types.uint(0)
      ], wallet_1.address)
    ]);
    
    assertEquals(block.receipts.length, 3);
    assertEquals(block.receipts[2].result, "(ok true)");
  },
});

Clarinet.test({
  name: "Character levels up correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("quest-forge", "initialize-character", [], wallet_1.address),
      Tx.contractCall("quest-forge", "create-quest", [
        types.utf8("High XP Quest"),
        types.uint(10)
      ], wallet_1.address),
      Tx.contractCall("quest-forge", "complete-quest", [
        types.uint(0)
      ], wallet_1.address)
    ]);
    
    let stats = chain.callReadOnlyFn(
      "quest-forge",
      "get-character-stats",
      [types.principal(wallet_1.address)],
      wallet_1.address
    );
    
    assertEquals(stats.result, '(ok {level: u2, experience: u0, quests-completed: u1})');
  },
});
