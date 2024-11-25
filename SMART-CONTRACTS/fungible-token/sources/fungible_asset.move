module fungible_token_addr::fungibleAsset
{
use std::string::{Self, utf8,String};
use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
use aptos_framework::object::{Self, Object};
use std::debug::print;
use std::vector;
use std::signer;
use aptos_framework::primary_fungible_store;
use std::option;
    use aptos_framework::account;
    use aptos_framework::function_info;





 const ASSET_SYMBOL : vector<u8> = b"DTKN";

 #[resource_group_member(group=aptos_framework::object::ObjectGroup)]
//  storage of refs to control mint,transfer and burn
struct ManageFungibleAsset has key
{
    mint_ref:MintRef,
    transfer_ref:TransferRef,
    burn_ref:BurnRef,
} 

fun init_module(admin: &signer)
{
    // An object must store data in resources.
    // ConstructorRef -  to create resources only available at creation time
    // Creates the  non-deletable object with a named address based on our ASSET_SYMBOL
    // let constructor_ref = &object::create_object(admin,ASSET_SYMBOL);
    let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);

   

    // Create the FA's Metadata with your name, symbol, icon, etc.
   primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(b"DToken"), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            8, /* decimals */
            utf8(b"https://i.pinimg.com/736x/6b/1f/03/6b1f03d9ce1421a79a275b7141c7a979.jpg"),
            utf8(b"http://example.com"), /* project */

        );
    //   Generate the MintRef for this object
    // Used by fungible_asset::mint() and fungible_asset::mint_to()
    let mint_ref=fungible_asset::generate_mint_ref(constructor_ref);

    // // Generate the TransferRef for this object
    // Used by fungible_asset::set_frozen_flag(), fungible_asset::withdraw_with_ref(),
    // fungible_asset::deposit_with_ref(), and fungible_asset::transfer_with_ref().
    let transfer_ref=fungible_asset::generate_transfer_ref(constructor_ref);

    // Generate the BurnRef for this object
    // Used by fungible_asset::burn() and fungible_asset::burn_from()
    let burn_ref=fungible_asset::generate_burn_ref(constructor_ref);


    // signer that will allocate/push resources to object
    let metadata_object_signer = object::generate_signer(constructor_ref);


    // transferring ownership of the ManagedFungibleAsset resource (containing mint_ref, transfer_ref, and burn_ref) to the metadata_object_signer.
    move_to(&metadata_object_signer,ManageFungibleAsset{mint_ref,transfer_ref,burn_ref});


}

#[view]
public fun get_metadata():Object<Metadata>
{
// Return the address of the managed fungible asset that's created when this module is deployed.
let asset_address = object::create_object_address(&@fungible_token_addr, ASSET_SYMBOL);
return object::address_to_object<Metadata>(asset_address)
}


// MINT
public entry fun mint(admin: &signer , to: address , amount:u64) acquires ManageFungibleAsset
      
{
let asset = get_metadata();
let manager=borrow_global<ManageFungibleAsset>(object::object_address(&asset));

let to_wallet=primary_fungible_store::ensure_primary_store_exists(to, asset);
print(&to_wallet);


let myAsset=fungible_asset::mint(&manager.mint_ref,amount);
fungible_asset::deposit_with_ref(&manager.transfer_ref,to_wallet,myAsset);
}
// public entry fun transfer(admin:&signer, to:address , from:address , amount:u64) acquires ManageFungibleAsset
// {
//     let asset= get_metadata();
//     let manager=borrow_global<ManageFungibleAsset>(object::object_address(&asset));
//     let from_wallet=primary_fungible_store::primary_store(from,asset);
//     print (&from_wallet);
//     let to_wallet=primary_fungible_store::ensure_primary_store_exists(to,asset);
//     let myAsset=withdraw(from_wallet,amount,manager.transfer_ref);
//     deposit(to_wallet,myAsset,manager.transfer_ref);


// }



#[test(creator = @fungible_token_addr)]
fun test_paused(creator: &signer) acquires ManageFungibleAsset {
    let creator_address = signer::address_of(creator);
     
    // Initialize the fungible asset module
    init_module(creator);
    let to= @0x4841522b8e6f97116f13261a29bb06db70fd6e4730c3bf777c2de7ca1047a0da;
    // Mint tokens to the creator's address
    // mint(creator, creator_address, 100);
    // transfer(creator, creator_address,to, 10);

}
}