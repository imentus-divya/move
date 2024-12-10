module nft_addr::NFT {
    use std::error;
    use std::option;
    use std::string::{Self, String};
    use std::signer;
    use std::debug::print;

    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use aptos_token_objects::property_map;
    use aptos_framework::event;
    use aptos_std::string_utils::{to_string};

    const COLLECTION_NAME: vector<u8> = b"BLACK NFT COLLECTION";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Hi, This collection is created by Divya for testing !";
    const COLLECTION_URI: vector<u8> = b"https://indigo-central-gibbon-526.mypinata.cloud/ipfs/QmVUWUrDen8gcLCoSCFpc5WyAdfN96wq7xqRoWSSjyGjkR";
    const COLOR_RED: vector<u8> = b"Red";
    const COLOR_BLUE: vector<u8> = b"Blue";
    const COLOR_GREEN: vector<u8> = b"Green";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct DTokenRef has key {
        mutator_ref: token::MutatorRef,
        burn_ref: token::BurnRef,
        property_mutator_ref: property_map::MutatorRef,
        base_uri: String,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct DTokenColor has key {
        DToken_color: String,
    }


    
    #[event]
    struct ColorChange has drop, store {
        token: Object<DTokenRef>,
        old_color: String,
        new_color: String,
    }

    fun init_module(sender: &signer) {
        create_dtoken_collection(sender);
    }

    fun create_dtoken_collection(creator: &signer) 
    {
        let description = string::utf8(COLLECTION_DESCRIPTION);

        let name = string::utf8(COLLECTION_NAME);

        let uri = string::utf8(COLLECTION_URI);

        collection::create_unlimited_collection(
            creator,
            description,
            name,
            option::none(),
            uri,
        );
    }
     public entry fun mint_ambassador_token_by_user(
        user: &signer,
        creator: &signer,
        description: String,
        uri: String,
    ) {
        let user_addr = signer::address_of(user);
         mint_dtoken(creator, description, to_string<address>(&user_addr), uri, user_addr);
    }


    public entry fun mint_dtoken(
        creator: &signer,
        description: String,
        name: String,
        base_uri: String,
        recipient_addr: address,
    ) {
        mint_dtoken_impl(creator, description, name, base_uri, recipient_addr);
    }

    fun mint_dtoken_impl(
        creator: &signer,
        description: String,
        name: String,
        base_uri: String,
        recipient_addr: address,
    ) {
        let collection = string::utf8(COLLECTION_NAME);

        // Construct the URI
        let  uri = base_uri;
        string::append(&mut uri, string::utf8(COLOR_GREEN));

        let constructor_ref = token::create_named_token(
            creator,
            collection,
            description,
            name,
            option::none(),
            base_uri    ,
        );

        let object_signer = object::generate_signer(&constructor_ref);
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let mutator_ref = token::generate_mutator_ref(&constructor_ref);
        let burn_ref = token::generate_burn_ref(&constructor_ref);
        let property_mutator_ref = property_map::generate_mutator_ref(&constructor_ref);

        // Transfer the token
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, recipient_addr);

        // Initialize token color
        move_to(
            &object_signer,
            DTokenColor {
                DToken_color: string::utf8(COLOR_RED),
            },
        );

        // Initialize the property map
        let properties = property_map::prepare_input(vector[], vector[], vector[]);
        property_map::init(&constructor_ref, properties);

        property_map::add_typed(
            &property_mutator_ref,
            string::utf8(b"Color"),
            string::utf8(COLOR_BLUE),
        );

        // Publish DToken
        let dtoken = DTokenRef {
            mutator_ref,
            burn_ref,
            property_mutator_ref,
            base_uri,
        };

        move_to(&object_signer, dtoken);
    }



    // UPDATION
    // set color of token ->only admin can set
    public fun fetch_token_details_for_updation(creator:&signer,collection_name:String,token_name:String) : object::Object<DTokenRef>
    {


        let token_address=token::create_token_address(
            &signer::address_of(creator),&collection_name,&token_name
        );

        let token=object::address_to_object<DTokenRef>(token_address);
        print(&token);

        return token
    }

    // public entry fun set_color(creator:&signer, token: Object<DTokenRef> , new_color:String) acquires DTokenColor , DTokenRef
    public entry fun set_color_of_token(creator:&signer, collection_name:String, token_name:String, new_color:String) acquires DTokenColor , DTokenRef
    {
       let token=fetch_token_details_for_updation(creator,collection_name,token_name);
          // Asserts that `creator` is the creator of the token.
        authorize_creator(creator,&token);

        //   fetch token and its existing color
       let token_address: address = object::object_address(&token);
       let token_details = borrow_global_mut<DTokenColor>(token_address);
        print(token_details);


        // emit ColorChange event
        event::emit(
            ColorChange{
                token,
                old_color:token_details.DToken_color,
                new_color:new_color
            }
        );

        //update color
        token_details.DToken_color=new_color;
        update_color_of_token(token,new_color);
    }

    public fun  update_color_of_token(token:Object<DTokenRef>,new_color:String) acquires DTokenRef
    {
        let token_address=object::object_address(&token);
        let dtoken_details = borrow_global_mut<DTokenRef>(token_address);

        // Gets `property_mutator_ref` to update the rank in the property map.
        let dtoken_property_mutator_ref=&dtoken_details.property_mutator_ref;
        property_map::update_typed(dtoken_property_mutator_ref,
        &string::utf8(b"Color"),new_color);


    }

     public entry fun set_color(creator:&signer, token: Object<DTokenRef> , new_color:String) 
    {
        // by mistake, it was created!

    }
     

  

    public fun burn_token(creator:&signer, collection_name:String, token_name:String) acquires DTokenRef
    {
         let token=fetch_token_details_for_updation(creator,collection_name,token_name);
          // Asserts that `creator` is the creator of the token.
          authorize_creator(creator,&token);
         let token_ref=move_from<DTokenRef>(object::object_address(&token));

         let DTokenRef  
         {
            mutator_ref: _,
            burn_ref,
            property_mutator_ref,
            base_uri: _
         }=token_ref;


    //      let token_color = move_from<DTokenColor>(object::object_address(token));

    // // Destructure the DTokenColor
    // let DTokenColor {
    //     DToken_color: _,
    // } = token_color; 

    //      property_map::burn(property_mutator_ref);
    //      token::burn(burn_ref);
    }


    inline fun authorize_creator<T:key>(creator:&signer , token:&Object<T>)
    {
        let token_address=object::object_address(token);
        assert!(exists<T>(token_address),error::not_found(1));

        assert!(
           token::creator(*token) == signer::address_of(creator),
           error::permission_denied(2)
        );
    }

    #[test(
        creator = @nft_addr,
        recipient_addr = @0x4841522b8e6f97116f13261a29bb06db70fd6e4730c3bf777c2de7ca1047a0da
    )]
    fun test_mint(creator: &signer, recipient_addr: address) acquires DTokenColor,DTokenRef
    {
        create_dtoken_collection(creator);
     
        let token_description = string::utf8(b"8");
        let collection_name = string::utf8(COLLECTION_NAME);
        let token_uri = string::utf8(b"https://indigo-central-gibbon-526.mypinata.cloud/files/bafkreif5vl5puj7f7o45xqg22b7fe5ofdioe4kbqdmutoov5ecgnzevgoy?X-Algorithm=PINATA1&X-Date=1732614725&X-Expires=30&X-Method=GET&X-Signature=a754d606dbc85f0cb17cf8e8df75695b67f2b0bb51edfd03d55468ee30659896");
        let token_name=string::utf8(b"8");

        mint_dtoken(creator, token_description, token_name, token_uri, recipient_addr);

        // updation
        let new_color=string::utf8(b"purple");

        let token_address=token::create_token_address(
            &signer::address_of(creator),&collection_name,&token_name
        );
        let token=object::address_to_object<DTokenRef>(token_address);

        set_color(creator, token, new_color);
        set_color_of_token(creator, collection_name, token_name, new_color);
        fetch_token_details_for_updation(creator,collection_name,token_name);

        burn_token(creator, string::utf8(b"D Collection Name"), string::utf8(b"D token#6"));

    }
}

