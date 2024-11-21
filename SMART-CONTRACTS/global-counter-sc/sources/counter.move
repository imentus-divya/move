module global_counter_addr::counter
{
  
    use std::signer;
    use std::string::{Self, String};
    use std::debug::print;
    use aptos_framework::account;


   struct Counter has key
   {
    count:u64,
    message:String
   }

   public fun create_counter(account: &signer)
   {
     let initial_msg=string::utf8(b"This is initial counter message !");
     let initial_counter=Counter {
        count:0,
        message:initial_msg
     };
     move_to(account,initial_counter);
   }

   public fun increment_counter(account: &signer, message:String) acquires Counter
   {
   
    let signer_address=signer::address_of(account);
    

    // first, we will fetch the counter for reading properties
    let counter=borrow_global_mut<Counter>(signer_address);

    //counter increment 
    let new_count=counter.count+1;

    // let counter_increment=Counter
    // {
    //     count:new_count,
    //     message:message
    // };

    counter.count = new_count;
    counter.message=message;

   }

   #[test(owner=@global_counter_addr)]
   fun test_flow(owner :signer) acquires Counter
   {

    account::create_account_for_test(signer::address_of(&owner));

    // creation of counter
    create_counter(&owner);

    // update
    increment_counter(&owner,string::utf8(b"Hi, I am incrementing count !!"));

    increment_counter(&owner,string::utf8(b"Hi, I am incrementing count twice!!"));
    // print(&count_two);

    let counter_records=borrow_global<Counter>(signer::address_of(&owner));
    print(counter_records);

    // let task_record= table::borrow(&todo_list.tasks,todo_list.task_counter);



   }
}