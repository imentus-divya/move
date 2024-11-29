module KGen::xyz {
    use std::error;
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::signer;
    use aptos_framework::object::{Self, ConstructorRef, Object, ExtendRef};
    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;

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

    /// The KGen token collection name
    const COLLECTION_NAME: vector<u8> = b"KGen Collection";
    /// The KGen token collection description
    const COLLECTION_DESCRIPTION: vector<u8> = b"This Collection Will Be Minting the PoA-NFT.";
    /// The KGen token collection URI
    const COLLECTION_URI: vector<u8> = b"https://teal-far-lemming-411.mypinata.cloud/ipfs/QmQQWnDttXVM1KgMhwYNavAU41whekEVdQpM9xHSDAxN6W";
    /// Core seed for the signer
    const TOKEN_CORE_SEED: vector<u8> = b"Rkoranne0755";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Storage state for managing the no-code Collection.
    struct KGenPoACollection has key {
        /// Used to mutate collection fields
        mutator_ref: Option<collection::MutatorRef>,
        /// Used to mutate royalties
        // royalty_mutator_ref: Option<royalty::MutatorRef>,
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
        /// Used to control freeze.
        transfer_ref: Option<object::TransferRef>,
        /// Used to mutate fields
        mutator_ref: Option<token::MutatorRef>,
        /// Used to mutate properties
        property_mutator_ref: property_map::MutatorRef
    }

    // We need a contract signer as the creator of the bucket core and bucket stores
    // Otherwise we need admin to sign whenever a new bucket store is created which is inconvenient
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct TokenCore has key {
        // This is the extend_ref of the bucket core object, not the extend_ref of bucket store object
        // bucket core object is the creator of bucket store object
        // but owner of each bucket store(i.e. user)
        // bucket_extended_ref
        bucket_ext_ref: ExtendRef
    }

    #[view]
    public fun is_mutable_name<T: key>(token: Object<T>): bool acquires KGenPoACollection {
        is_mutable_collection_token_name(token::collection_object(token))
    }

    #[view]
    public fun are_properties_mutable<T: key>(token: Object<T>): bool acquires KGenPoACollection {
        let collection = token::collection_object(token);
        borrow_collection(&collection).mutable_token_properties
    }

    public fun get_token_owner_address(token_name: String): address acquires TokenCore {
        let collection = string::utf8(COLLECTION_NAME);
        let token_address =
            token::create_token_address(
                &signer::address_of(&get_token_signer(get_token_signer_address())),
                &collection,
                &token_name
            );
        let token = object::address_to_object<KGenToken>(token_address);

        object::owner(token)
    }

     /// Events
    /// 1. NFTMintedToPlayer
    /// 2. PlayerScoreUpdated
    /// 3. TokenNameChanged
    /// 4. TokenUriChanged
    /// 5. CustodianChanged
    /// 6. OnChainAttributeAdded
    /// 7. OnChainAttributeUpdated
    /// 8. OnChainAttributeRemoved
    /// 9. CounterIncreased

    /// View Functions
    /// 1. is_mutable_name()
    /// 2. is_mutable_uri()
    /// 3. get_property_value()
    /// 4. get_token_address()
    /// 5. .get_counter_value()
    /// 6. get_UpdatorRole()
    /// 7. get_minter_role()

    /// Function:
    /// 1. init_module() private method
    /// 2. create_collections() private method
    /// 3. mint_nft() method
    /// 4. mint_internal() private method
    /// 5. set_name() method
    /// 6. set_image_uri() method
    /// 7. add_on_chain_attributes() method
    /// 8. update_on_chain_attributes() method
    /// 9. remove_on_chain_attributes() method
    /// 10. burn() method
    /// 11. Add MinterRoleAddresses() method
    /// 12. Removes MinterRoleAddresses() method
    /// 13. Add UpdatorRoleAddresses() method
    /// 14. Remove UpdatorRoleAddresses() method
    /// 15. VerifyMinter() method
    /// 16. VerifyUpdator() method
    /// 17. Change_admin_role() method

    /// Inline methods
    /// 1. borrow() method to borrow mutalble token Object
    /// 2. collection_object() method to return collection address
    /// 3. borrow_collection() method to return token Collection
    /// 4. authorized_borrow() method to return Object<Token>
    /// 5. get_object_signer_address()
    /// 6. get_object_signer()

    #[view]
    /// Returns the on chain attribute of the token for the given key
    public fun get_property_value(token_name: String, key: String): String acquires TokenCore {

        let collection_name = string::utf8(COLLECTION_NAME);
        let token_address =
            token::create_token_address(
                &signer::address_of(&get_token_signer(get_token_signer_address())),
                &collection_name,
                &token_name
            );
        let token = object::address_to_object<KGenToken>(token_address);

        property_map::read_string(&token, &key)
    }

    // To get signer address e.g. module is a signer now for the token core
    fun get_token_signer_address(): address {
        object::create_object_address(&@KGen, TOKEN_CORE_SEED)
    }

    // To get signer sign e.g. module is a signer now for the bucket core
    fun get_token_signer(bucket_signer_address: address): signer acquires TokenCore {
        object::generate_signer_for_extending(
            &borrow_global<TokenCore>(bucket_signer_address).bucket_ext_ref
        )
    }

    fun init_module(admin: &signer) {
        // Init the bucket core
        // We are creating a separate object for the bucket core collection, which helps in stores and creating multiple bucket stores
        // What happens in Aptos is, we can only stores the structs or values in a object only once at the time of initialization
        // Later we can only update the storage like adding or subtracting the FAs,
        // But in our case we need an object where we can stores multiple multiple bucket stores, later also at the time of mint for every user
        // For this purpose we uses this extendref, and crated a separate object for it
        let bucket_constructor_ref = &object::create_named_object(
            admin, TOKEN_CORE_SEED
        );

        // use later this extendref to implement new bucketstores
        let bucket_ext_ref = object::generate_extend_ref(bucket_constructor_ref);
        let bucket_signer = object::generate_signer(bucket_constructor_ref);
        // we need a signer to stores the bucket store globally,
        move_to(&bucket_signer, TokenCore { bucket_ext_ref });

        create_collection_object(
            &bucket_signer,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true
        );
    }

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
        object::object_from_constructor_ref(&constructor_ref)
    }

    public entry fun mint_soul_bound(
        _creator: &signer,
        collection: String,
        description: String,
        name: String,
        uri: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
        soul_bound_to: address
    ) acquires KGenPoACollection, TokenCore {
        let constructor_ref =
            mint_internal(
                &get_token_signer(get_token_signer_address()),
                collection,
                description,
                name,
                uri,
                property_keys,
                property_types,
                property_values
            );

        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        // Transfers the token to the `soul_bound_to` address
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, soul_bound_to);
        // Disables ungated transfer, thus making the token soulbound and non-transferable
        object::disable_ungated_transfer(&transfer_ref);

        // object::object_from_constructor_ref(&constructor_ref);
    }

    fun mint_internal(
        creator: &signer,
        collection: String,
        description: String,
        name: String,
        uri: String,
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

    public entry fun set_name(
        creator: &signer, token_name: String, name: String
    ) acquires KGenPoACollection, KGenToken {

        let collection = string::utf8(COLLECTION_NAME);
        let token_address =
            token::create_token_address(
                &signer::address_of(creator),
                &collection,
                &token_name
            );
        let token = object::address_to_object<KGenToken>(token_address);

        assert!(
            is_mutable_name(token),
            error::permission_denied(EFIELD_NOT_MUTABLE)
        );
        let aptos_token = authorized_borrow(&token, creator);
        token::set_name(option::borrow(&aptos_token.mutator_ref), name);
    }

    public entry fun add_property(
        creator: &signer,
        token_name: String,
        key: String,
        // type: String,
        value: String
    ) acquires KGenPoACollection, KGenToken {

        let collection = string::utf8(COLLECTION_NAME);
        let token_address =
            token::create_token_address(
                &signer::address_of(creator),
                &collection,
                &token_name
            );
        let token = object::address_to_object<KGenToken>(token_address);

        let aptos_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE)
        );

        property_map::add_typed(&aptos_token.property_mutator_ref, key, value);
    }

    public entry fun remove_property(
        creator: &signer, token_name: String, key: String
    ) acquires KGenPoACollection, KGenToken {

        let collection = string::utf8(COLLECTION_NAME);
        let token_address =
            token::create_token_address(
                &signer::address_of(creator),
                &collection,
                &token_name
            );
        let token = object::address_to_object<KGenToken>(token_address);

        let aptos_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE)
        );

        property_map::remove(&aptos_token.property_mutator_ref, &key);
    }

    public entry fun update_property(
        creator: &signer,
        token_name: String,
        key: String,
        value: String
    ) acquires KGenPoACollection, KGenToken {

        let collection = string::utf8(COLLECTION_NAME);
        let token_address =
            token::create_token_address(
                &signer::address_of(creator),
                &collection,
                &token_name
            );
        let token = object::address_to_object<KGenToken>(token_address);

        let aptos_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE)
        );

        property_map::update_typed(&aptos_token.property_mutator_ref, &key, value);
    }

    inline fun collection_object(creator: &signer, name: &String): Object<KGenPoACollection> {
        let collection_addr =
            collection::create_collection_address(&signer::address_of(creator), name);
        object::address_to_object<KGenPoACollection>(collection_addr)
    }

    inline fun borrow_collection<T: key>(token: &Object<T>): &KGenPoACollection {
        let collection_address = object::object_address(token);
        assert!(
            exists<KGenPoACollection>(collection_address),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST)
        );
        borrow_global<KGenPoACollection>(collection_address)
    }

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

    public fun is_mutable_collection_token_name<T: key>(
        collection: Object<T>
    ): bool acquires KGenPoACollection {
        borrow_collection(&collection).mutable_token_name
    }

    #[test(admin = @KGen, acc1 = @0x1)]
    public fun test(admin: &signer, acc1: &signer) acquires TokenCore, KGenPoACollection, KGenToken {
        // let description = string::utf8(COLLECTION_DESCRIPTION);
        // let name = string::utf8(COLLECTION_NAME);
        // let uri = string::utf8(COLLECTION_URI);
        // create_collection_object(
        //     &get_token_signer(get_token_signer_address()),
        //     true,
        //     true,
        //     true,
        //     true,
        //     true,
        //     true,
        //     true,
        //     true
        // );

        let collection = string::utf8(COLLECTION_NAME);
        init_module(admin);

        std::debug::print(&string::utf8(b"Bucket Signer Address"));
        std::debug::print(
            &signer::address_of(&get_token_signer(get_token_signer_address()))
        );

        let token_name = string::utf8(b"My SBT #1");
        let token_description = string::utf8(b"A unique soulbound token");
        let token_uri = string::utf8(b"https://example.com/metadata.json");
        let soul_bound_to = signer::address_of(acc1); // Replace with actual address

        mint_soul_bound(
            admin,
            collection,
            token_description,
            token_name,
            token_uri,
            vector[],
            vector[],
            vector[],
            soul_bound_to
        );

        assert!(get_token_owner_address(token_name) == soul_bound_to, 1);

        let token_address =
            token::create_token_address(
                &signer::address_of(&get_token_signer(get_token_signer_address())),
                &collection,
                &token_name
            );
        let token = object::address_to_object<KGenToken>(token_address);

        std::debug::print(&string::utf8(b""));
        std::debug::print(&string::utf8(b"Token Description"));
        std::debug::print(&token::creator(token));
        std::debug::print(&token::name(token));
        std::debug::print(&token::uri(token));
        std::debug::print(&token::description(token));
        std::debug::print(&token::collection_name(token));
        // Asserts that the owner of the token is User1.

        std::debug::print(&string::utf8(b""));
        std::debug::print(&string::utf8(b"On Chain Attribute"));
        add_property(
            &get_token_signer(get_token_signer_address()),
            token_name,
            string::utf8(b"Level"),
            string::utf8(b"10")
        );
        add_property(
            &get_token_signer(get_token_signer_address()),
            token_name,
            string::utf8(b"Rank"),
            string::utf8(b"Gold")
        );
        std::debug::print(&get_property_value(token_name, string::utf8(b"Level")));
        std::debug::print(
            &get_property_value(token_name, string::utf8(b"Rank"))
        );
    }
}
