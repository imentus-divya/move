const { Account, Aptos, AptosConfig, Network,Ed25519PrivateKey } =require( "@aptos-labs/ts-sdk");
const fs = require("fs");
const toml = require("toml");

  
async function get_signer()
{
const privateKey = new Ed25519PrivateKey(privateKeyBytes);
const account = Account.fromPrivateKey({ privateKey });
return account
} 
// Specify which network to connect to via AptosConfig
async function example() 
{

    const config_ = new AptosConfig({ network: Network.TESTNET });
    const aptos = new Aptos(config_);


    const admin='7bb9d6ca22703cbfa939c28908b123227073f60ddb1b889d813cf17222e22536';
    const user='2a0abf2355b42068acea7a8b5862785bf3656f9225872e2020480ca2eaa3e66c';

    // const signer=await get_signer();






    // 1. Build
    console.log("\n=== 1. Building the transaction ===\n");
    const transaction = await aptos.transaction.build.multiAgent({
      sender: admin,
      secondarySignerAddresses: [user],
      data: {
        // REPLACE WITH YOUR MULTI-AGENT FUNCTION HERE

          function: `${admin}::pog::mint_player_nft`,

        functionArguments: [ 
            aptos.types.String("playerUsername05"),
            aptos.types.String("QmRa9FiP3uruiT5Q6r4n6dL8oUcUwVh4NUzEmcwE2mWFqY"),
            true,
            1,
            2,
            3,
            4,
            5,
            aptos.types.String("encryptedPohScore"), // 0x1::string::String
            aptos.types.String("encryptedPopScore"), // 0x1::string::String
            aptos.types.String("encryptedPoskScore"), // 0x1::string::String
            aptos.types.String("encryptedPocScore"), // 0x1::string::String
            aptos.types.String("encryptedPosScore"), // 0x1::string::String
            aptos.types.String("encryptedPogScore"), // 0x1::string::String
            
         ],
      },
    });
    console.log("Transaction:", transaction);

     // 3. Sign
  console.log("\n=== 3. Signing transaction ===\n");


  const adminAuthenticator = aptos.transaction.sign({
    signer: admin,
    transaction,
  });
  const userAuthenticator = aptos.transaction.sign({
    signer: user,
    transaction,
  });
  console.log(adminAuthenticator);
  console.log(userAuthenticator);
   

   

   
}

 Error: Type mismatch for argument 3, expected 'string'
example()