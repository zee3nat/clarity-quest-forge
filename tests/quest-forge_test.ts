import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure user can initialize character with valid class",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("quest-forge", "initialize-character", [
        types.uint(1)  // Warrior class
      ], wallet_1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result, "(ok true)");
  },
});

Clarinet.test({
  name: "Can create and complete quest with deadline",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("quest-forge", "initialize-character", [
        types.uint(1)
      ], wallet_1.address),
      Tx.contractCall("quest-forge", "create-quest", [
        types.utf8("Test Quest"),
        types.uint(1),
        types.uint(100)  // 100 blocks deadline
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
  name: "Character levels up and gains skill points",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("quest-forge", "initialize-character", [
        types.uint(1)
      ], wallet_1.address),
      Tx.contractCall("quest-forge", "create-quest", [
        types.utf8("High XP Quest"),
        types.uint(10),
        types.uint(100)
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
    
    assertEquals(stats.result, 
      '(ok {level: u2, experience: u0, quests-completed: u1, class: u1, skill-points: u1, quest-streak: u1})');
  },
});
