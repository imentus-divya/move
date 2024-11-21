module local_counters_addr::local_counters
{
    use std::string::{Self, String};
    use std::vector;
    use std::debug::print;
    use std::signer;
    use aptos_framework::account;





    struct UsersList has key,drop
    {
        users:vector<User>,
        user_counter:u64
    }
    struct User has drop,store,copy
    {
        id:u64,
        name:String,
        count:u64,
        modified_by:String
    }
    public fun create_user(account :&signer)
    {
        // let mut users_created = vector::empty<User>() ;
        let users_created = vector::empty<User>(); 

        let user1=User{id:0, name:string::utf8(b"User1"), count:0 , modified_by:string::utf8(b"none")}; 
        let user2=User{id:1, name:string::utf8(b"User2"), count:0 , modified_by:string::utf8(b"none")}; 
        let user3=User{id:2, name:string::utf8(b"User3"), count:0 , modified_by:string::utf8(b"none")}; 

        // vector::push_back(&mut vector, element);
        vector::push_back(&mut users_created, user1);
        vector::push_back(&mut users_created,user2);
        vector::push_back(&mut users_created,user3);

        add_user_to_userlist(users_created,account);
    }
    public fun add_user_to_userlist(users : vector<User> , account:&signer)
    {
        let initial_userlist=UsersList
        {
            users:users,
            user_counter:vector::length(&users)
        };
        move_to(account,initial_userlist);

    }
    public entry fun increment_user_count(account:&signer,modified_by:String,user_id:u64) acquires UsersList
    {
        let signer_address=signer::address_of(account);

        // read userlist
         let userlist=borrow_global_mut<UsersList>(signer_address);

        // find user with user_id exist
        let user_details=vector::borrow_mut(&mut userlist.users, user_id);


        let new_user_count=user_details.count+1;
        let modified_by=modified_by;

        user_details.count=new_user_count;
        user_details.modified_by=modified_by;


    }

    #[test(owner = @local_counters_addr)]
    public fun test_flow(owner:signer) acquires UsersList
    {
        account::create_account_for_test(signer::address_of(&owner));

        create_user(&owner);

        // let modifier=string::utf8(b"modifier1");
        // let modifier2=string::utf8(b"modifier13");


        // increment_user_count(&owner,modifier,1);
        // increment_user_count(&owner,modifier,1);



        let read_user_list=borrow_global<UsersList>(signer::address_of(&owner));
        print(read_user_list);

    }


}