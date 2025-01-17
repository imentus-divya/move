module KGen::pog
{
    use std::error;
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::signer;
    use std::vector;
    use aptos_framework::object::{Self, ConstructorRef, Object, ExtendRef};
    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;
    use aptos_framework::event;
    use aptos_std::string_utils::{to_string};
    use std::fixed_point32;


// -------------------------------

    /// The collection does not exist
    const ECOLLECTION_DOES_NOT_EXIST: u64 = 1;
    /// The token does not exist
    const ETOKEN_DOES_NOT_EXIST: u64 = 2;
    /// The provided signer is not the creator
    const ENOT_CREATOR: u64 = 3;
    /// The field being changed is not mutable
    const EFIELD_NOT_MUTABLE: u64 = 4;
    /// The token being burned is not burnable
    const ETOKEN_NOT_BURNABLE: u64 = 5;
    /// The property map being mutated is not mutable
    const EPROPERTIES_NOT_MUTABLE: u64 = 6;
    /// If the Property Attribute is not per the constraints
    const EINVALID_ATTRIBUTE_VALUE: u64 = 7;
    /// Caller of the function is not Admin.
    const ECALLER_NOT_ADMIN: u64 = 8;
    /// Error while emitting the event.
    const EEMITTING_EVENT: u64 = 9;
    /// Invalid Token name
    const EINVALID_TOKEN_NAME: u64 = 10;
    /// Address is not token owner
    const ENOT_OWNER: u64 = 11;
    /// Token data did't change
    const ENOT_CHANGE: u64 = 12;


    /// The KGen token collection name
    const COLLECTION_NAME: vector<u8> = b"PoG-NFT Collection";
    /// The KGen token collection description
    const COLLECTION_DESCRIPTION: vector<u8> = b"This Collection Will Be Minting the PoG-NFT for Players.";
    /// The KGen token collection URI
    const COLLECTION_URI: vector<u8> = b"www.collection.uri.com/";
    /// Core seed used to create the signer.
    const TOKEN_CORE_SEED: vector<u8> = b"iM3.123!";

   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Storage refenrences/state for managing KGenToken.
    struct KGenPoACollection has key {
        /// Used to mutate collection fields
        mutator_ref: Option<collection::MutatorRef>,
        /// Determines if the creator can mutate the collection's description
        mutable_description: bool,
        /// Determines if the creator can mutate the collection's uri
        mutable_uri: bool,
        /// Determines if the creator can mutate token descriptions
        mutable_token_description: bool,
        /// Determines if the creator can mutate token names
        mutable_token_name: bool,
        /// Determines if the creator can mutate token properties
        mutable_token_properties: bool,
        /// Determines if the creator can mutate token uris
        mutable_token_uri: bool,
        /// Determines if the creator can burn tokens
        tokens_burnable_by_creator: bool,
        /// Determines if the creator can freeze tokens
        tokens_freezable_by_creator: bool
    }

    struct KGenToken has key {
        /// Used to burn.
        burn_ref: Option<token::BurnRef>,
        /// Used to transer freeze.
        transfer_ref: Option<object::TransferRef>,
        /// Used to mutate fields
        mutator_ref: Option<token::MutatorRef>,
        /// Used to mutate properties
        property_mutator_ref: property_map::MutatorRef
    }

    /// Global Storages

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// ModuleAdmin: stores the module admin address.
    struct ModuleAdmin has key {
        /// Stores the address of the module admin
        admin: address
    }

    /// TokenCore: stores the token_extended_ref
    /// We need a contract signer as the creator of the token core
    /// Otherwise we need admin to sign whenever a new token is created
    /// and mutated which is inconvenient
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct TokenCore has key {
        // This is the extend_ref of the token core object,
        // token core object is the creator of token object
        // but owner of each token (i.e. user)
        // token_extended_ref
        token_ext_ref: ExtendRef
    }

    // setting base uri
    struct BaseUri has key{
        base_uri:String
    }

    /// NFT-Counter: variables to store the NFT counter.
    struct Counter has key {
        /// It stores the number of NFT Created and used to concatenate in the name of the NFT too
        count: u128
    }

    /// Events

    #[event]
    /// 1. NFTMintedToPlayer: Emitted when the NFT is minted for Player.
    struct NFTMintedToPlayerEvent has store, drop {
        token_name: String,
        to: address,
        counter: u128
    }

    #[event]
    /// 2. PlayerScoreUpdated: Emitted when the Players Score is updated.
    struct PlayerScoreUpdatedEvent has store, drop {
        token_name: String,
        owner: address,
        pog_score: vector<u8>
    }

    #[event]
    /// 3. TokenNameChanged: Emitted when the Name is mutated.
    struct NFTNameChangedEvent has store, drop {
        old_name: String,
        new_name: String,
        owner: address
    }

    #[event]
    /// 4. TokenUriChanged
    struct TokenUriChangedEvent has store, drop {
        owner: address,
        token_name: String
    }

    #[event]
    /// 5. CustodianChanged: Emmitted when the user changes the custodian.
    struct CustodianChangedEvent has store, drop {
        token_name: String,
        owner: address,
        by: address
    }

    #[event]
    /// 9. CounterIncreased: Emitted whenever the counter is increased.
    struct CounterIncrementedEvent has store, drop {
        value: u128
    }

    #[event]
    struct CollectionCreatedEvent has store, drop {
        name: String,
        creator: address
    }

    /// View Functions
    /// 1. is_mutable_name()
    /// 2. is_mutable_uri()
    /// 3. get_property_value()
    /// 4. get_token_address()
    /// 5. get_counter_value()
    /// 6. get_UpdatorRole()
    /// 7. get_minter_role()

    #[view]
    /// 8. get_admin_address()
    public fun get_admin_address(): address acquires ModuleAdmin {
        borrow_global<ModuleAdmin>(@KGen).admin
    }

    #[view]
    /// 9. get_counter_value()
    public fun get_counter_value(): u128 acquires Counter {
        borrow_global<Counter>(@KGen).count
    }

    #[view]
    /// 8. get_player_score()
    public fun get_player_score(token_name: String): vector<String> acquires TokenCore {
        let collection_name = string::utf8(COLLECTION_NAME);
        let object_signer = get_token_signer(get_token_signer_address());
        let result = vector::empty<String>();

        let token_address =
            token::create_token_address(
                &signer::address_of(&object_signer),
                &collection_name,
                &token_name
            );

        let token = object::address_to_object<KGenToken>(token_address);

        let poh_score = property_map::read_string(&token, &string::utf8(b"PoH Score"));
        vector::push_back(&mut result, poh_score);

        let pop_score = property_map::read_string(&token, &string::utf8(b"PoP Score"));
        vector::push_back(&mut result, pop_score);

        let posk_score = property_map::read_string(&token, &string::utf8(b"PoSk Score"));
        vector::push_back(&mut result, posk_score);

        let poc_score = property_map::read_string(&token, &string::utf8(b"PoC Score"));
        vector::push_back(&mut result, poc_score);

        let pos_score = property_map::read_string(&token, &string::utf8(b"PoS Score"));
        vector::push_back(&mut result, pos_score);

        let pog_score = property_map::read_string(&token, &string::utf8(b"PoG Score"));
        vector::push_back(&mut result, pog_score);

        result
    }
    // 9. get_token_base_uri
    public fun get_base_uri():String acquires BaseUri
    {
        borrow_global<BaseUri>(@KGen).base_uri
    }
 
    /// Function:

    /// 1. init_module(): called once when the module is initialized/deployed.
    fun init_module(admin: &signer) {

        let base_uri=BaseUri{base_uri: string::utf8(b"https://indigo-central-gibbon-526.mypinata.cloud/ipfs/")};
        move_to(admin,base_uri);

        let token_constructor_ref = &object::create_named_object(admin, TOKEN_CORE_SEED);
        let token_ext_ref = object::generate_extend_ref(token_constructor_ref);
        let token_signer = object::generate_signer(token_constructor_ref);
        move_to(&token_signer, TokenCore { token_ext_ref });

        create_collection_object(
            &token_signer,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true
        );

        let admin_address = signer::address_of(admin);
        move_to(admin, ModuleAdmin { admin: admin_address });

        let counter_value = 1;
        move_to(admin, Counter { count: counter_value });

        let counter_event = CounterIncrementedEvent { value: counter_value };
        event::emit(counter_event);
    }

    /// 2. create_collections(): create a collection of objects from where we'll be minting our token objects.
    fun create_collection_object(
        creator: &signer,
        mutable_description: bool,
        mutable_uri: bool,
        mutable_token_description: bool,
        mutable_token_name: bool,
        mutable_token_properties: bool,
        mutable_token_uri: bool,
        tokens_burnable_by_creator: bool,
        tokens_freezable_by_creator: bool
    ): Object<KGenPoACollection> {

        let description = string::utf8(COLLECTION_DESCRIPTION);
        let name = string::utf8(COLLECTION_NAME);
        let uri = string::utf8(COLLECTION_URI);
        let _creator_addr = signer::address_of(creator);

        let constructor_ref =
            collection::create_unlimited_collection(
                creator, description, name, option::none(), uri
            );

        let object_signer = object::generate_signer(&constructor_ref);
        let mutator_ref =
            if (mutable_description || mutable_uri) {
                option::some(collection::generate_mutator_ref(&constructor_ref))
            } else {
                option::none()
            };

        let aptos_collection = KGenPoACollection {
            mutator_ref,
            // royalty_mutator_ref,
            mutable_description,
            mutable_uri,
            mutable_token_description,
            mutable_token_name,
            mutable_token_properties,
            mutable_token_uri,
            tokens_burnable_by_creator,
            tokens_freezable_by_creator
        };
        move_to(&object_signer, aptos_collection);

        let creator_address = signer::address_of(creator);

        let event = CollectionCreatedEvent { name, creator: creator_address };

        event::emit(event);

        object::object_from_constructor_ref(&constructor_ref)
    }

    public entry fun change_admin(admin: &signer, new_admin: address) acquires ModuleAdmin {
        assert!(
            signer::address_of(admin) == get_admin_address(),
            error::permission_denied(ECALLER_NOT_ADMIN)
        );

        let admin_addr = borrow_global_mut<ModuleAdmin>(@KGen);
        admin_addr.admin = new_admin;
    }

    /// 10. burn() method
    /// 11. Add MinterRoleAddresses() method
    /// 12. Removes MinterRoleAddresses() method
    /// 13. Add UpdatorRoleAddresses() method
    /// 14. Remove UpdatorRoleAddresses() method
    /// 15. VerifyMinter() method
    /// 16. VerifyUpdator() method
    /// 17. Change_admin_role() method
    

 

     /// 3. mint_player_nft(): Mints the soulbound NFT for the PLayer.
    public entry fun mint_player_nft(
        user:&signer,
        admin:&signer,
        player_username:String,
        image_cid:String,
        kgen_community_badge:bool,

        poh_badge: u8,
        pop_badge: u8,
        posk_badge: u8,
        poc_badge: u8,
        pos_badge: u8,

        // score - encryped hash /data
        // badge - level

        poh_score:vector<u8>,
        pop_score:vector<u8>,
        posk_score:vector<u8>,
        poc_score:vector<u8>,
        pos_score:vector<u8>,

        pog_score:vector<u8>,

       

    ) acquires Counter, KGenPoACollection, TokenCore, KGenToken, ModuleAdmin,BaseUri {

        assert!(
            signer::address_of(admin) == get_admin_address(),
            error::permission_denied(ECALLER_NOT_ADMIN)
        );

        /// Collection name of the token.
        let collection_name = string::utf8(COLLECTION_NAME);

        /// Storing the counter value in a variable.
        let counter_value = borrow_global_mut<Counter>(@KGen);
        // string::utf8(counter_value);

        /// Creating the Token name.
        let token_name = player_username;
        string::append(&mut token_name, string::utf8(b".kgen.io-#"));
        string::append(&mut token_name, to_string(&counter_value.count));


        let avatar_uri = get_base_uri();  // Create an empty mutable string
        string::append(&mut avatar_uri,image_cid);
        

        // receipent address
        let to_address = signer::address_of(user);

        let token_description = string::utf8(b"This Token named as ");
        string::append(&mut token_description, token_name);
        string::append(&mut token_description, string::utf8(b"is owned as"));
        string::append(&mut token_description, to_string(&to_address));

        let constructor_ref =
            mint_internal(
                &get_token_signer(get_token_signer_address()),
                collection_name,
                token_description,
                token_name,
                avatar_uri,
                vector[],
                vector[],
                vector[]
            );

        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        // Transfers the token to the `soul_bound_to` address
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, to_address);
        // Disables ungated transfer, thus making the token soulbound and non-transferable
        object::disable_ungated_transfer(&transfer_ref);

        /// Emmiting the mint event

        let mint_event = NFTMintedToPlayerEvent {
            token_name,
            to: to_address,
            counter: counter_value.count
        };

        event::emit(mint_event);

        /// Adding the on-chain properties.

        /// Value Verifiacation
        assert!(
            poh_badge >= 0 && poh_badge <= 2,
            error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
        );
        assert!(
            pop_badge >= 0 && pop_badge <= 10,
            error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
        );
        assert!(
            posk_badge >= 0 && posk_badge <= 10,
            error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
        );
        assert!(
            poc_badge >= 0 && poc_badge <= 10,
            error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
        );
        assert!(
            pos_badge >= 0 && pos_badge <= 10,
            error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
        );

        add_property(token_name, string::utf8(b"PoH Score"), to_string(&poh_score));
        add_property(token_name, string::utf8(b"PoP Score"), to_string(&pop_score));
        add_property(token_name, string::utf8(b"PoSk Score"), to_string(&posk_score));
        add_property(token_name, string::utf8(b"PoC Score"), to_string(&poc_score));
        add_property(token_name, string::utf8(b"PoS Score"), to_string(&pos_score));
        add_property(token_name, string::utf8(b"PoG Score"), to_string(&pog_score));

        let score_event = PlayerScoreUpdatedEvent {
            token_name,
            owner: to_address,
            pog_score
        };

        event::emit(score_event);

        counter_value.count = counter_value.count + 1;

        let counter_event = CounterIncrementedEvent { value: counter_value.count };

        event::emit(counter_event);
    }

    /// 4. mint_internal() Internal method that mints the PoG-NFT and return the constructor_ref.
    fun mint_internal(
        creator: &signer, //object address
        collection: String,
        description: String,
        name: String, // token_name
        uri: String, // avatar/token uri
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>
    ): ConstructorRef acquires KGenPoACollection {
        let constructor_ref =
            token::create_named_token(
                creator,
                collection,
                description,
                name,
                option::none(),
                uri
            );

        // Generates the object signer and the refs. The object signer is used to publish a resource
        // (e.g., AmbassadorLevel) under the token object address. The refs are used to manage the token.

        let object_signer = object::generate_signer(&constructor_ref);

        let collection_obj = collection_object(creator, &collection);
        let collection = borrow_collection(&collection_obj);

        let mutator_ref =
            if (collection.mutable_token_description
                || collection.mutable_token_name
                || collection.mutable_token_uri) {
                option::some(token::generate_mutator_ref(&constructor_ref))
            } else {
                option::none()
            };

        let burn_ref =
            if (collection.tokens_burnable_by_creator) {
                option::some(token::generate_burn_ref(&constructor_ref))
            } else {
                option::none()
            };

        let properties =
            property_map::prepare_input(property_keys, property_types, property_values);
        property_map::init(&constructor_ref, properties);

        let aptos_token = KGenToken {
            burn_ref,
            transfer_ref: option::none(),
            mutator_ref,
            property_mutator_ref: property_map::generate_mutator_ref(&constructor_ref)
        };
        move_to(&object_signer, aptos_token);

        constructor_ref
    }



    // // / 5. set_name(): Mutate the name of the Object<KGenToken> using the token_name and extended_ref.
    // public entry fun change_token_name(
    //     admin: &signer, token_name: String, name: String
    // ) acquires KGenToken, TokenCore, ModuleAdmin, {
    //     assert!(
    //         signer::address_of(admin) == get_admin_address(),
    //         error::permission_denied(ECALLER_NOT_ADMIN)
    //     );

    //     let creator = get_token_signer(get_token_signer_address());
    //     let collection = string::utf8(COLLECTION_NAME);
    //     let token_address =
    //         token::create_token_address(
    //             &signer::address_of(&creator),
    //             &collection,
    //             &token_name
    //         );
    //     let token = object::address_to_object<KGenToken>(token_address);

    //     let old_name = token::name(token);

    //     let aptos_token = authorized_borrow(&token, &creator);
    //     token::set_name(option::borrow(&aptos_token.mutator_ref), name);

    //     let event = NFTNameChangedEvent {
    //         old_name,
    //         new_name: name,
    //         owner: object::owner(token)
    //     };

    //     event::emit(event);
    // }

    // /// 6. change_token_avatar_uri():
    // public entry fun change_token_avatar_uri(
    //     admin: &signer, token_name: String, avatar_uri: String
    // ) acquires KGenToken, TokenCore, ModuleAdmin {
    //     assert!(
    //         signer::address_of(admin) == get_admin_address(),
    //         error::permission_denied(ECALLER_NOT_ADMIN)
    //     );

    //     let creator = get_token_signer(get_token_signer_address());
    //     let collection = string::utf8(COLLECTION_NAME);
    //     let token_address =
    //         token::create_token_address(
    //             &signer::address_of(&creator),
    //             &collection,
    //             &token_name
    //         );
    //     let token = object::address_to_object<KGenToken>(token_address);

    //     let aptos_token = authorized_borrow(&token, &creator);
    //     token::set_uri(option::borrow(&aptos_token.mutator_ref), avatar_uri);

    //     let event = TokenUriChangedEvent { owner: object::owner(token), token_name };

    //     event::emit(event);
    // }

    /// 7. add_on_chain_attributes(): Adds the attributes to the Token Object.
    fun add_property(token_name: String, key: String, value: String) acquires KGenToken, TokenCore {

        let collection_name = string::utf8(COLLECTION_NAME);
        let creator = get_token_signer(get_token_signer_address());
        let token_address =
            token::create_token_address(
                &signer::address_of(&creator),
                &collection_name,
                &token_name
            );
        let token = object::address_to_object<KGenToken>(token_address);

        let aptos_token = authorized_borrow(&token, &creator);
        property_map::add_typed(&aptos_token.property_mutator_ref, key, value);
    }

    // public entry fun update_player_score(
    //     admin: &signer,
    //     token_name: String,
    //     poh_badge: u8,
    //     pop_badge: u8,
    //     posk_badge: u8,
    //     poc_badge: u8,
    //     pos_badge: u8,
    //     poh_score: Option<vector<u8>>,
    //     pop_score: Option<vector<u8>>,
    //     posk_score: Option<vector<u8>>,
    //     poc_score: Option<vector<u8>>,
    //     pos_score: Option<vector<u8>>,
    //     pog_score: Option<vector<u8>>
    // ) acquires TokenCore, KGenToken, ModuleAdmin {
    //     assert!(
    //         signer::address_of(admin) == get_admin_address(),
    //         error::permission_denied(ECALLER_NOT_ADMIN)
    //     );

    //     let creator = get_token_signer(get_token_signer_address());
    //     let collection = string::utf8(COLLECTION_NAME);
    //     let token_address =
    //         token::create_token_address(
    //             &signer::address_of(&creator),
    //             &collection,
    //             &token_name
    //         );
    //     let token = object::address_to_object<KGenToken>(token_address);
    //     let aptos_token = authorized_borrow(&token, &creator);

    //     /// Checking whether the poh_badge has to be updated or not.
    //     if (option::is_some<u8>(&poh_badge)) {

    //         let score = option::extract<u8>(&mut poh_badge);

    //         assert!(
    //             score >= 0 && score <= 2,
    //             error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
    //         );

    //         property_map::update_typed(
    //             &aptos_token.property_mutator_ref,
    //             &string::utf8(b"PoH Badge"),
    //             to_string(&score)
    //         );
    //     };

    //     /// Checking whether the pop_badge has to be updated or not.
    //     if (option::is_some<u8>(&pop_badge)) {

    //         let score = option::extract<u8>(&mut pop_badge);

    //         assert!(
    //             score >= 0 && score <= 10,
    //             error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
    //         );

    //         property_map::update_typed(
    //             &aptos_token.property_mutator_ref,
    //             &string::utf8(b"PoP Badge"),
    //             to_string(&score)
    //         );

    //     };

    //     /// Checking whether the posk_badge has to be updated or not.
    //     if (option::is_some<u8>(&posk_badge)) {

    //         let score = option::extract<u8>(&mut posk_badge);

    //         assert!(
    //             score >= 0 && score <= 10,
    //             error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
    //         );

    //         property_map::update_typed(
    //             &aptos_token.property_mutator_ref,
    //             &string::utf8(b"PoSk Badge"),
    //             // to_string(&option::some(posk_score))
    //             to_string(&score)
    //         );
    //     };

    //     /// Checking whether the poc_badge has to be updated or not.
    //     if (option::is_some<u8>(&poc_badge)) {

    //         let score = option::extract<u8>(&mut poc_badge);
    //         assert!(
    //             score >= 0 && score <= 10,
    //             error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
    //         );

    //         property_map::update_typed(
    //             &aptos_token.property_mutator_ref,
    //             &string::utf8(b"PoC Badge"),
    //             to_string(&score)
    //         );
    //     };

    //     /// Checking whether the pos_badge has to be updated or not.
    //     if (option::is_some<u8>(&pos_badge)) {

    //         let score = option::extract<u8>(&mut pos_badge);
    //         assert!(
    //             score >= 0 && score <= 10,
    //             error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
    //         );

    //         property_map::update_typed(
    //             &aptos_token.property_mutator_ref,
    //             &string::utf8(b"PoS Badge"),
    //             to_string(&score)
    //         );
    //     };
    //     /// Checking whether the pog_score has to be updated or not.
        
    //     let score = 0;
    //     if (option::is_some<vector<u8>>(&pog_score)) {
    //         score = option::extract<vector<u8>>(&mut pog_score);
    //         assert!(
    //             score >= 0,
    //             error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
    //         );

    //         property_map::update_typed(
    //             &aptos_token.property_mutator_ref,
    //             &string::utf8(b"PoG Score"),
    //             to_string(&score)
    //         );

    //     };












    //     let event = PlayerScoreUpdatedEvent {
    //         token_name,
    //         owner: object::owner(token),
    //         pog_score: score
    //     };

    //     event::emit(event);

    // }

    // // /// burn token
    // public entry fun burn(admin: &signer, token_name: String) acquires KGenToken, TokenCore, ModuleAdmin {
    //     assert!(
    //         signer::address_of(admin) == get_admin_address(),
    //         error::permission_denied(ECALLER_NOT_ADMIN)
    //     );

    //     let collection = string::utf8(COLLECTION_NAME);
    //     let object_signer = get_token_signer(get_token_signer_address());
    //     let token_address =
    //         token::create_token_address(
    //             &signer::address_of(&object_signer), &collection, &token_name
    //         );
    //     let token = object::address_to_object<KGenToken>(token_address);

    //     let player_token = authorized_borrow(&token, &object_signer);
    //     assert!(
    //         option::is_some(&player_token.burn_ref),
    //         error::permission_denied(ETOKEN_NOT_BURNABLE)
    //     );
    //     move player_token;
    //     let aptos_token = move_from<KGenToken>(object::object_address(&token));
    //     let KGenToken { burn_ref, transfer_ref: _, mutator_ref: _, property_mutator_ref } =
    //         aptos_token;
    //     property_map::burn(property_mutator_ref);
    //     token::burn(option::extract(&mut burn_ref));
    // }

    // /// 8. update_on_chain_attributes() method
    // fun update_property(token_name: String, key: String, value: String) acquires KGenToken, TokenCore {

    //     let collection_name = string::utf8(COLLECTION_NAME);
    //     let creator = get_token_signer(get_token_signer_address());
    //     let token_address =
    //         token::create_token_address(
    //             &signer::address_of(&creator),
    //             &collection_name,
    //             &token_name
    //         );
    //     let token = object::address_to_object<KGenToken>(token_address);

    //     let aptos_token = authorized_borrow(&token, &creator);
    //     property_map::update_typed(&aptos_token.property_mutator_ref, &key, value);
    // }

    // /// 9. remove_on_chain_attributes() method
    // fun remove_property(token_name: String, key: String) acquires KGenToken, TokenCore {

    //     let collection_name = string::utf8(COLLECTION_NAME);
    //     let creator = get_token_signer(get_token_signer_address());

    //     let token_address =
    //         token::create_token_address(
    //             &signer::address_of(&creator),
    //             &collection_name,
    //             &token_name
    //         );

    //     let token = object::address_to_object<KGenToken>(token_address);

    //     let aptos_token = authorized_borrow(&token, &creator);
    //     property_map::remove(&aptos_token.property_mutator_ref, &key);
    // }

    /// Returns the on chain attribute of the token for the given key
    fun get_property_value(
        creator: address, token_name: String, key: String
    ): String {

        let collection_name = string::utf8(COLLECTION_NAME);
        let token_address =
            token::create_token_address(&creator, &collection_name, &token_name);
        let token = object::address_to_object<KGenToken>(token_address);

        property_map::read_string(&token, &key)
    }

    // /// Inline methods

    /// 2. collection_object(): Returns the collection objection from creater address and collection name.
    inline fun collection_object(creator: &signer, name: &String): Object<KGenPoACollection> {
        let collection_addr =
            collection::create_collection_address(&signer::address_of(creator), name);
        object::address_to_object<KGenPoACollection>(collection_addr)
    }

    /// 3. borrow_collection(): Return the referenece to collection object from the token object
    inline fun borrow_collection<T: key>(token: &Object<T>): &KGenPoACollection {
        let collection_address = object::object_address(token);
        assert!(
            exists<KGenPoACollection>(collection_address),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST)
        );
        borrow_global<KGenPoACollection>(collection_address)
    }

    /// 4. authorized_borrow() method to return Object<Token> only KGenPoACollection, TokenCore,
    inline fun authorized_borrow<T: key>(
        token: &Object<T>, creator: &signer
    ): &KGenToken {
        let token_address = object::object_address(token);
        assert!(
            exists<KGenToken>(token_address),
            error::not_found(ETOKEN_DOES_NOT_EXIST)
        );

        assert!(
            token::creator(*token) == signer::address_of(creator),
            error::permission_denied(ENOT_CREATOR)
        );
        borrow_global<KGenToken>(token_address)
    }

    /// 5. get_token_signer_address(): To get signer address e.g. module is a signer now for the token core
    fun get_token_signer_address(): address {
        object::create_object_address(&@KGen, TOKEN_CORE_SEED)
    }

    /// 6. get_token_signer(): To get signer sign e.g. module is a signer now for the bucket core
    fun get_token_signer(token_signer_address: address): signer acquires TokenCore {
        object::generate_signer_for_extending(
            &borrow_global<TokenCore>(token_signer_address).token_ext_ref
        )
    }

    /// 7. are_properties_mutable(): To check whether that property is mutable or not
    fun are_properties_mutable<T: key>(token: Object<T>): bool acquires KGenPoACollection {
        let collection = token::collection_object(token);
        borrow_collection(&collection).mutable_token_properties
    }













    // / Testing create_collection_object() and init_module()
    #[test(admin = @KGen)]
    public fun test_init_module(admin: &signer) acquires TokenCore, ModuleAdmin, Counter {

        let collection_name = string::utf8(COLLECTION_NAME);

        init_module(admin);
        let object_signer = get_token_signer(get_token_signer_address());

        assert!(
            exists<TokenCore>(signer::address_of(&object_signer)),
            1003
        );

        assert!(
            exists<ModuleAdmin>(signer::address_of(admin)),
            1003
        );

        let collection_event = CollectionCreatedEvent {
            name: collection_name,
            creator: signer::address_of(&object_signer)
        };

        let counter_event = CounterIncrementedEvent { value: 1 };

        assert!(
            event::was_event_emitted<CollectionCreatedEvent>(&collection_event),
            error::not_implemented(EEMITTING_EVENT)
        );

        assert!(
            event::was_event_emitted<CounterIncrementedEvent>(&counter_event),
            error::not_implemented(EEMITTING_EVENT)
        );

        assert!(
            @KGen == get_admin_address(),
            error::unauthenticated(ECALLER_NOT_ADMIN)
        );

        let collection_object = collection_object(&object_signer, &collection_name);

        assert!(
            object::owner(collection_object) == signer::address_of(&object_signer),
            1004
        );

        assert!(exists<Counter>(@KGen), 1005);

        assert!(borrow_global<Counter>(@KGen).count == 1, 1006);

    }

    // / tesing the mint nft method()
    #[test(admin = @KGen, user = @0x1)]
    public fun test_mint_nft(
        admin: &signer, user: &signer
    ) acquires KGenPoACollection, KGenToken, TokenCore, ModuleAdmin, Counter,BaseUri {
        init_module(admin);

        assert!(get_counter_value() == 1, 10001);

        let collection_name = string::utf8(COLLECTION_NAME);
        let object_signer = get_token_signer(get_token_signer_address());

        mint_player_nft(
            user,
            admin,
            string::utf8(b"user_1"),
            string::utf8(b"QmRa9FiP3uruiT5Q6r4n6dL8oUcUwVh4NUzEmcwE2mWFqY"),
            true,
             1,
            2,
            3,
            4,
            5,
            string::utf8(b"QmRa9FiP3uruiT5Q6r4n6dL8oUcUwVh4NUzEmcwE2mWFqY-1"),
            string::utf8(b"QmRa9FiP3uruiT5Q6r4n6dL8oUcUwVh4NUzEmcwE2mWFqY-2"),
            string::utf8(b"QmRa9FiP3uruiT5Q6r4n6dL8oUcUwVh4NUzEmcwE2mWFqY-3"),
            string::utf8(b"QmRa9FiP3uruiT5Q6r4n6dL8oUcUwVh4NUzEmcwE2mWFqY-4"),
            string::utf8(b"QmRa9FiP3uruiT5Q6r4n6dL8oUcUwVh4NUzEmcwE2mWFqY-5"),
            string::utf8(b"QmRa9FiP3uruiT5Q6r4n6dL8oUcUwVh4NUzEmcwE2mWFqY-5"),           
        );

    

        let token_name = string::utf8(b"iMentus.kgen.io#1");

        let token_address =
            token::create_token_address(
                &signer::address_of(&object_signer),
                &collection_name,
                &token_name
            );

        let token = object::address_to_object<KGenToken>(token_address);

        assert!(
            token::name(token) == token_name,
            error::invalid_argument(EINVALID_TOKEN_NAME)
        );

        assert!(
            object::owner(token) == signer::address_of(user),
            error::unauthenticated(ENOT_OWNER)
        );

        assert!(
            token::creator(token) == signer::address_of(&object_signer),
            error::unauthenticated(ENOT_CREATOR)
        );

        let mint_event = NFTMintedToPlayerEvent {
            token_name,
            to: signer::address_of(user),
            counter: 1
        };

        assert!(
            event::was_event_emitted<NFTMintedToPlayerEvent>(&mint_event),
            error::not_implemented(EEMITTING_EVENT)
        );

        let pog_score_vector = string::utf8(b"pog_score_value");
        
        let score_event = PlayerScoreUpdatedEvent {
            token_name,
            owner: signer::address_of(user),
            pog_score: b"Pog encryped scores"
        };

        assert!(
            event::was_event_emitted<PlayerScoreUpdatedEvent>(&score_event),
            error::not_implemented(EEMITTING_EVENT)
        );

        let counter_event = CounterIncrementedEvent { value: 1 };

        assert!(
            event::was_event_emitted<CounterIncrementedEvent>(&counter_event),
            error::not_implemented(EEMITTING_EVENT)
        );

        assert!(get_counter_value() == 2, 10001);
    }

    // #[test(admin = @KGen, user = @0x1)]
    // public fun test_update_score(
    //     admin: &signer, user: &signer
    // ) acquires KGenPoACollection, KGenToken, TokenCore, ModuleAdmin, Counter {
    //     init_module(admin);

    //     assert!(get_counter_value() == 1, 10001);

    //     let collection_name = string::utf8(COLLECTION_NAME);
    //     let object_signer = get_token_signer(get_token_signer_address());

    //     mint_player_nft(
    //         admin,
    //         string::utf8(b"iMentus"),
    //         string::utf8(b"www.uri-to-avatar.com"),
    //         signer::address_of(user),
    //         0,
    //         0,
    //         0,
    //         0,
    //         0,
    //         0
    //     );

    //     let token_name = string::utf8(b"iMentus.kgen.io#1");

    //     let token_address =
    //         token::create_token_address(
    //             &signer::address_of(&object_signer),
    //             &collection_name,
    //             &token_name
    //         );

    //     let token = object::address_to_object<KGenToken>(token_address);

    //     let score_vector: vector<String> = get_player_score(token_name);

    //     let event = PlayerScoreUpdatedEvent {
    //         token_name,
    //         owner: object::owner(token),
    //         pog_score: b"pog score-1"
    //     };

    //     assert!(
    //         event::was_event_emitted<PlayerScoreUpdatedEvent>(&event),
    //         error::not_implemented(EEMITTING_EVENT)
    //     );

    //     assert!(
    //         score_vector[0] == string::utf8(b"0")
    //             && score_vector[1] == string::utf8(b"0")
    //             && score_vector[2] == string::utf8(b"0")
    //             && score_vector[3] == string::utf8(b"0")
    //             && score_vector[4] == string::utf8(b"0")
    //             && score_vector[5] == string::utf8(b"0"),
    //         error::invalid_state(EINVALID_ATTRIBUTE_VALUE)
    //     );

    //     update_player_score(
    //         admin,
    //         token_name,
    //         option::some(1),
    //         option::some(1),
    //         option::some(2),
    //         option::some(2),
    //         option::some(2),
    //         option::some(10)
    //     );

    //     score_vector = get_player_score(token_name);

    //     assert!(
    //         score_vector[0] == string::utf8(b"1")
    //             && score_vector[1] == string::utf8(b"1")
    //             && score_vector[2] == string::utf8(b"2")
    //             && score_vector[3] == string::utf8(b"2")
    //             && score_vector[4] == string::utf8(b"2")
    //             && score_vector[5] == string::utf8(b"10"),
    //         error::invalid_state(EINVALID_ATTRIBUTE_VALUE)
    //     );

    //     let event2 = PlayerScoreUpdatedEvent {
    //         token_name,
    //         owner: object::owner(token),
    //         pog_score: b"pog score-2"
    //     };

    //     assert!(
    //         event::was_event_emitted<PlayerScoreUpdatedEvent>(&event2),
    //         error::not_implemented(EEMITTING_EVENT)
    //     );
    // }

    // #[test(admin = @KGen, user = @0x321)]
    // public fun test_set_uri_and_name(
    //     admin: &signer, user: &signer
    // ) acquires KGenPoACollection, KGenToken, TokenCore, ModuleAdmin, Counter {
    //     init_module(admin);

    //     assert!(get_counter_value() == 1, 10001);

    //     let collection_name = string::utf8(COLLECTION_NAME);
    //     let object_signer = get_token_signer(get_token_signer_address());

    //     mint_player_nft(
    //         admin,
    //         string::utf8(b"iMentus"),
    //         string::utf8(b"www.uri-to-avatar.com"),
    //         signer::address_of(user),
    //         0,
    //         0,
    //         0,
    //         0,
    //         0,
    //         0
    //     );

    //     let token_name = string::utf8(b"iMentus.kgen.io#1");

    //     let token_address =
    //         token::create_token_address(
    //             &signer::address_of(&object_signer),
    //             &collection_name,
    //             &token_name
    //         );

    //     let token = object::address_to_object<KGenToken>(token_address);

    //     let new_name = string::utf8(b"Token_New_Name");
    //     change_token_name(admin, token_name, new_name);

    //     let event = NFTNameChangedEvent {
    //         old_name: token_name,
    //         new_name,
    //         owner: object::owner(token)
    //     };

    //     assert!(
    //         event::was_event_emitted<NFTNameChangedEvent>(&event),
    //         error::not_implemented(EEMITTING_EVENT)
    //     );

    //     assert!(
    //         token::name(token) == new_name,
    //         error::not_implemented(ENOT_CHANGE)
    //     );

    //     let new_uri = string::utf8(b"www.new-uri.com");
    //     change_token_avatar_uri(admin, token_name, new_uri);

    //     let event2 = TokenUriChangedEvent { owner: object::owner(token), token_name };

    //     assert!(
    //         token::uri(token) == new_uri,
    //         error::not_implemented(ENOT_CHANGE)
    //     );

    //     assert!(
    //         event::was_event_emitted<TokenUriChangedEvent>(&event2),
    //         error::not_implemented(EEMITTING_EVENT)
    //     );

    // }

    // #[test(owner = @KGen, admin = @0x1, user = @0x2)]
    // #[expected_failure]
    // public fun test_change_admin(
    //     owner: &signer, admin: &signer, user: &signer
    // ) acquires KGenPoACollection, KGenToken, TokenCore, ModuleAdmin, Counter {
    //     init_module(owner);

    //     assert!(get_counter_value() == 1, 10001);

    //     let collection_name = string::utf8(COLLECTION_NAME);
    //     let object_signer = get_token_signer(get_token_signer_address());

    //     change_admin(owner, signer::address_of(admin));

    //     mint_player_nft(
    //         owner,
    //         string::utf8(b"iMentus"),
    //         string::utf8(b"www.uri-to-avatar.com"),
    //         signer::address_of(user),
    //         0,
    //         0,
    //         0,
    //         0,
    //         0,
    //         0
    //     );
    // }

    // #[test(admin = @KGen, user = @0x321)]
    // public fun test_burn(
    //     admin: &signer, user: &signer
    // ) acquires KGenPoACollection, KGenToken, TokenCore, ModuleAdmin, Counter {
    //     init_module(admin);

    //     assert!(get_counter_value() == 1, 10001);

    //     let collection_name = string::utf8(COLLECTION_NAME);
    //     let object_signer = get_token_signer(get_token_signer_address());

    //     mint_player_nft(
    //         admin,
    //         string::utf8(b"iMentus"),
    //         string::utf8(b"www.uri-to-avatar.com"),
    //         signer::address_of(user),
    //         0,
    //         0,
    //         0,
    //         0,
    //         0,
    //         0
    //     );

    //     let token_name = string::utf8(b"iMentus.kgen.io#1");

    //     let token_address =
    //         token::create_token_address(
    //             &signer::address_of(&object_signer),
    //             &collection_name,
    //             &token_name
    //         );

    //     let token = object::address_to_object<KGenToken>(token_address);
    //     assert!(exists<KGenToken>(token_address), 99);
    //     burn(admin, token_name);
    //     assert!(!exists<KGenToken>(token_address), 99);

    // }





}