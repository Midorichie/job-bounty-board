import { Clarinet, Tx, chain, Account } from "clarinet-sdk";

Clarinet.test({
  name: "Users can post and approve tasks",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    let deployer = accounts.get("deployer")!;
    let worker = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("job-bounty-board", "post-task", [
        "u\"Translate article\"",
        "u\"Translate English to Yoruba\"",
        "u1000"
      ], deployer.address),
    ]);

    block.receipts[0].result.expectOk().expectUint(1);
  },
});
