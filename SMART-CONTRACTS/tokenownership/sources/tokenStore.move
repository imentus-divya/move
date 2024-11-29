// object storing fungible "tokens"



module tokenStoreAddr::fungibleAsset
{
use std::string::{Self, utf8,String};
use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset,FungibleStore};
use aptos_framework::object::{Self, Object,ExtendRef};
use std::debug::print;
use std::vector;
use std::signer;
use aptos_framework::primary_fungible_store;
use std::option;
use aptos_framework::account;
use aptos_framework::function_info;

  /// Core seed used to create the signer.
const TOKEN_CORE_SEED: vector<u8> = b"iM3.123!";
const ASSET_SYMBOL : vector<u8> = b"POP";



//  storage of refs to control mint,transfer and burn

#[resource_group_member(group = aptos_framework::object::ObjectGroup)]
struct ManageFungibleAsset has key
{
    mint_ref:MintRef,
    transfer_ref:TransferRef,
    burn_ref:BurnRef,
} 
struct TokenStorageCore has key
{
        // This is the extend_ref of the token core object,
        // token core object is the creator of token object
        // but owner of each token (i.e. user)
        // token_extended_ref
        token_ext_ref: ExtendRef
}

 struct Config has key
{
        /// Whitelist of guild masters.
        whitelistSenders: vector<address>,
        whitelistReceivers: vector<address>,
        /// `extend_ref` of the guild collection manager object. Used to obtain its signer.
        extend_ref: object::ExtendRef,
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
            utf8(b"POP TOKEN"), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            8, /* decimals */
            utf8(b"https://indigo-central-gibbon-526.mypinata.cloud/ipfs/QmRa9FiP3uruiT5Q6r4n6dL8oUcUwVh4NUzEmcwE2mWFqY"),
            utf8(b"https://indigo-central-gibbon-526.mypinata.cloud/ipfs/QmSuPB4jkXvh7viFCZDWDMRTN53fZzGcKvjGyQs31RRbyi"), /* project */

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




    // // =================================TOKEN STORAGE OBJECT REF=========================================
    let token_storage_ref = &object::create_named_object(admin, TOKEN_CORE_SEED);
    let token_ext_ref = object::generate_extend_ref(token_storage_ref);
    let token_signer = object::generate_signer(token_storage_ref);
    //     // we need a signer to stores the bucket store globally,
     move_to(&token_signer, TokenStorageCore { token_ext_ref });



    // //   ================

}

#[view]
public fun get_metadata():Object<Metadata>
{
    // Return the address of the managed fungible asset that's created when this module is deployed.
    let asset_address = object::create_object_address(&@tokenStoreAddr, ASSET_SYMBOL);
    return object::address_to_object<Metadata>(asset_address)
}
// Get the address of the primary store for the given account.
#[view]
public fun primary_store<T: key>(owner: address, metadata: Object<T>): Object<FungibleStore> {
    let metadata = get_metadata();  

    let store = primary_store_address(owner, metadata);
    object::address_to_object<FungibleStore>(store)
}
// Get the primary store object for the given account.
#[view]
public fun primary_store_address<T: key>(owner: address, metadata: Object<T>): address {
    let metadata = get_metadata();  
    let metadata_addr = object::object_address(&metadata);
    object::create_user_derived_object_address(owner, metadata_addr)
}
// Return whether the given account primary store exists.
#[view]
public fun primary_store_exists<T: key>(account: address, metadata: Object<T>): bool {
    let metadata = get_metadata();  
    fungible_asset::store_exists(primary_store_address(account, metadata))
}
#[view]
public fun balance(account: address): u64 {
    let metadata = get_metadata();  
    if (primary_store_exists(account, metadata)) {
        fungible_asset::balance(primary_store(account, metadata))
    } else {
        0
    }
}

#[view]
public fun get_token_object_signer(): address {
        object::create_object_address(&@tokenStoreAddr, TOKEN_CORE_SEED)
     
    }


fun get_token_storage_signer(token_object_signer_address: address): signer acquires TokenStorageCore {
        object::generate_signer_for_extending(
            &borrow_global<TokenStorageCore>(token_object_signer_address).token_ext_ref
        )
}

public entry fun mint(admin: &signer , to: address , amount:u64) acquires ManageFungibleAsset  
{

    let asset = get_metadata();
    let manager=borrow_global<ManageFungibleAsset>(object::object_address(&asset));

    let to_wallet=primary_fungible_store::ensure_primary_store_exists(to, asset);


    let myAsset=fungible_asset::mint(&manager.mint_ref,amount);
    fungible_asset::deposit_with_ref(&manager.transfer_ref,to_wallet,myAsset);
}

public fun deposit<T: key>( store: Object<T>, fa: FungibleAsset, transfer_ref: &TransferRef,)
{
    fungible_asset::deposit_with_ref(transfer_ref, store, fa);
}

public fun withdraw<T: key>(store: Object<T>,amount: u64,transfer_ref: &TransferRef): FungibleAsset 
{
    fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
}

public fun  withdraw_asset_and_transfer_asset (asset:object::Object<fungible_asset::Metadata>, from:address , to:object::Object<fungible_asset::FungibleStore> )
{
    

}

public entry fun transfer(
        admin: &signer, to: address, from: address, amount: u64
    ) acquires ManageFungibleAsset 
{
        let asset = get_metadata();
        let manager = borrow_global<ManageFungibleAsset>(object::object_address(&asset));

        let from_wallet = primary_fungible_store::primary_store(from, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);

        // let myAsset = withdraw(from_wallet, amount, &manager.transfer_ref);
        // deposit(to_wallet, myAsset, &manager.transfer_ref);

        withdraw_asset_and_transfer_asset(asset , from , to_wallet);

}

public entry fun add_whitelistSenders()
{
        let whitelisted_senders = vector::empty<address>(); 

        vector::push_back(&mut whitelisted_senders,@0x2a0abf2355b42068acea7a8b5862785bf3656f9225872e2020480ca2eaa3e66c);
        vector::push_back(&mut whitelisted_senders,@0x6916bc69a6523a0770132ac46d3c3357f5c15c499f5773ada9fa2ca673a4f211);

}
public entry fun add_whitelistedReceivers()
{
//  0x7bb9d6ca22703cbfa939c28908b123227073f60ddb1b889d813cf17222e22536 

         let whitelisted_receivers = vector::empty<address>(); 
        vector::push_back(&mut whitelisted_receivers,@0x7bb9d6ca22703cbfa939c28908b123227073f60ddb1b889d813cf17222e22536);


}


#[test(creator = @tokenStoreAddr)]
fun test_paused(creator: &signer)  {
    let creator_address = signer::address_of(creator);
     
    // Initialize the fungible asset module
    // init_module(creator);
    // let to= @0x4841522b8e6f97116f13261a29bb06db70fd6e4730c3bf777c2de7ca1047a0da;


     let object = get_token_object_signer();
     print(&object);


     add_whitelistSenders();
     add_whitelistedReceivers();


    // mint(creator,to,5555);
    // transfer(creator, to, creator_address,100);

    // balance(creator_address);

    
    // let treasury_address= @x2a0abf2355b42068acea7a8b5862785bf3656f9225872e2020480ca2eaa3e66c;
    // transfer_tokens_to_tokenStorage(treasury_address);

}
}