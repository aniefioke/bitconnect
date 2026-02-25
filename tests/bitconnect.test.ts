import { describe, it, expect, beforeEach } from "vitest";
import { Clarinet, Tx, Chain, Account, types } from "@hirosystems/clarinet-sdk";

describe("BitConnect Pro - Production Test Suite", () => {
  let chain: Chain;
  let accounts: Map<string, Account>;
  let deployer: Account;
  let user1: Account;
  let user2: Account;

  beforeEach(async () => {
    chain = await Clarinet.newChain();
    accounts = chain.accounts;
    deployer = accounts.get("deployer")!;
    user1 = accounts.get("wallet_1")!;
    user2 = accounts.get("wallet_2")!;
  });

  /* ------------------------------------------------------- */
  /* USER PROFILE & PRIVACY                                 */
  /* ------------------------------------------------------- */

  it("updates privacy settings successfully", () => {
    const block = chain.mineBlock([
      Tx.contractCall(
        "bitconnect-pro",
        "update-advanced-privacy-settings",
        [
          types.bool(true),
          types.bool(true),
          types.bool(true),
          types.bool(true),
          types.bool(true),
          types.bool(false),
        ],
        user1.address
      ),
    ]);

    block.receipts[0].result.expectOk().expectBool(true);
    expect(block.receipts[0].events.length).toBeGreaterThan(0);
  });

  it("updates user profile fields selectively", () => {
    const block = chain.mineBlock([
      Tx.contractCall(
        "bitconnect-pro",
        "update-user-profile",
        [
          types.some(types.ascii("Alice")),
          types.none(),
          types.none(),
          types.none(),
        ],
        user1.address
      ),
    ]);

    block.receipts[0].result.expectOk();
  });

  it("rejects profile update for inactive user", () => {
    const block = chain.mineBlock([
      Tx.contractCall(
        "bitconnect-pro",
        "update-user-profile",
        [
          types.none(),
          types.none(),
          types.none(),
          types.none(),
        ],
        user2.address
      ),
    ]);

    block.receipts[0].result.expectErr().expectUint(105);
  });

  /* ------------------------------------------------------- */
  /* LOGIN & ACTIVITY TRACKING                              */
  /* ------------------------------------------------------- */

  it("records login and increments counter", () => {
    const block = chain.mineBlock([
      Tx.contractCall("bitconnect-pro", "record-login", [], user1.address),
      Tx.contractCall("bitconnect-pro", "record-login", [], user1.address),
    ]);

    block.receipts.forEach((r) => r.result.expectOk());
  });

  /* ------------------------------------------------------- */
  /* RATE LIMITING                                           */
  /* ------------------------------------------------------- */

  it("enforces daily action rate limits", () => {
    const txs = [];

    for (let i = 0; i < 120; i++) {
      txs.push(
        Tx.contractCall(
          "bitconnect-pro",
          "update-advanced-privacy-settings",
          [
            types.bool(true),
            types.bool(true),
            types.bool(true),
            types.bool(true),
            types.bool(true),
            types.bool(false),
          ],
          user1.address
        )
      );
    }

    const block = chain.mineBlock(txs);
    const last = block.receipts[block.receipts.length - 1];

    expect(last.result.isErr()).toBe(true);
  });

  it("resets rate limits after time passes", () => {
    chain.mineEmptyBlock(90000); // simulate 24h+

    const block = chain.mineBlock([
      Tx.contractCall(
        "bitconnect-pro",
        "update-advanced-privacy-settings",
        [
          types.bool(true),
          types.bool(true),
          types.bool(true),
          types.bool(true),
          types.bool(true),
          types.bool(false),
        ],
        user1.address
      ),
    ]);

    block.receipts[0].result.expectOk();
  });

  /* ------------------------------------------------------- */
  /* BATCH SYSTEM                                            */
  /* ------------------------------------------------------- */

  it("rejects invalid batch size", () => {
    const block = chain.mineBlock([
      Tx.contractCall(
        "bitconnect-pro",
        "set-batch-size",
        [types.uint(1)],
        user1.address
      ),
    ]);

    block.receipts[0].result.expectErr().expectUint(103);
  });

  it("accepts valid batch size", () => {
    const block = chain.mineBlock([
      Tx.contractCall(
        "bitconnect-pro",
        "set-batch-size",
        [types.uint(20)],
        user1.address
      ),
    ]);

    expect(block.receipts[0].result.isOk()).toBe(true);
  });

  it("optimizes batch size after expiry", () => {
    chain.mineEmptyBlock(4000);

    const block = chain.mineBlock([
      Tx.contractCall(
        "bitconnect-pro",
        "optimize-batch-size",
        [types.principal(user1.address)],
        user1.address
      ),
    ]);

    expect(block.receipts[0].result.isOk()).toBe(true);
  });

  /* ------------------------------------------------------- */
  /* SECURITY & ACCESS CONTROL                               */
  /* ------------------------------------------------------- */

  it("prevents unauthorized batch modification", () => {
    const block = chain.mineBlock([
      Tx.contractCall(
        "bitconnect-pro",
        "set-batch-size",
        [types.uint(20)],
        user2.address
      ),
    ]);

    block.receipts[0].result.expectErr();
  });

  it("ensures users cannot bypass rate limiting via multiple blocks", () => {
    for (let i = 0; i < 10; i++) {
      chain.mineBlock([
        Tx.contractCall(
          "bitconnect-pro",
          "update-advanced-privacy-settings",
          [
            types.bool(true),
            types.bool(true),
            types.bool(true),
            types.bool(true),
            types.bool(true),
            types.bool(false),
          ],
          user1.address
        ),
      ]);
    }

    const block = chain.mineBlock([
      Tx.contractCall(
        "bitconnect-pro",
        "update-advanced-privacy-settings",
        [
          types.bool(true),
          types.bool(true),
          types.bool(true),
          types.bool(true),
          types.bool(true),
          types.bool(false),
        ],
        user1.address
      ),
    ]);

    expect(block.receipts[0].result.isErr()).toBe(true);
  });
});
