module div_todo_list_addr::todolist
{
    
    use aptos_framework::event;
    use aptos_std::table::{Self, Table}; 
    use std::string::{Self, String};
    use aptos_framework::account;
    use std::signer;
    use std::debug::print;


        // Errors
    const E_NOT_INITIALIZED: u64 = 1;
    const ETASK_DOESNT_EXIST: u64 = 2;
    const ETASK_IS_COMPLETED: u64 = 3;


    struct TodoList has key
    {
        tasks:Table<u64,Task>,
        set_task_event:event::EventHandle<Task>,
        task_counter:u64
    }

    struct Task has drop,store,copy
    {
        task_id:u64,
        address:address,
        content:String,
        completed:bool
    }

    public fun create_list(account : &signer)
    {
        // List creation
            let task_holder=TodoList{
                tasks:table::new(),
                set_task_event:account::new_event_handle<Task>(account),
                task_counter:0,
            };
            print(&task_holder);


            // attach resource (task)to an account
            move_to(account,task_holder)

    }
    // acquires keyword is used to indicate that a function may borrow or modify specific resource types from the global storage
    public entry fun create_task(account:&signer , content:String) acquires TodoList
    {
        let signer_address = signer::address_of(account);


        // CHECK TO ENSURE THAT SIGNER HAS CREATED A LIST
        assert!(exists<TodoList>(signer_address),1);

        // fetch todo lits resource
        let todo_list=borrow_global_mut<TodoList>(signer_address);

        let counter=todo_list.task_counter+1;

        // ------------new task creation
         let new_task = Task
        {
             task_id : counter,
             address:signer_address,
             content,
             completed:false
        };
        // adding task into task table
        table::upsert(&mut todo_list.tasks, counter, new_task);

        // set task counter to be incremeneted counter
        todo_list.task_counter=counter;

        // trigger a new event
        event::emit_event<Task>(&mut borrow_global_mut<TodoList>(signer_address).set_task_event,new_task);   
    
    }

    // option to mark the task as completed
    public fun task_completed(account :&signer, task_id:u64) acquires TodoList
    {
        let signer_address=signer::address_of(account);

        // check signer has created a list
        assert!(exists<TodoList>(signer_address),1);

        // read todo list's properties
        let todo_list= borrow_global_mut<TodoList>(signer_address);

        // check if task exists
        assert!(table::contains(&todo_list.tasks,task_id),2);

        // read task from from table of todolist
        let task_record=table::borrow_mut(&mut todo_list.tasks,task_id);

        // check if task is not completed
        assert!(task_record.completed==false,3);


        // marrk task completed
        task_record.completed=true; 


    }


    #[test(admin = @div_todo_list_addr)]
    // need to use  'entry' because we are testing entry function
    public entry fun test_flow(admin: signer) acquires TodoList
    {
        // create list -

        //  creates admin tododlist_adress for test
        account::create_account_for_test(signer::address_of(&admin));
        // initialization of contract with admin account
        create_list(&admin);

        // create task
        // creates a task by the admin account
        create_task(&admin , string::utf8(b"Hi, This is Divya and I have created a new task for writing contracts in move"));

        let task_count= event::counter(&borrow_global<TodoList>(signer::address_of(&admin)).set_task_event);
        assert!(task_count == 1, 4);

        let todo_list = borrow_global<TodoList>(signer::address_of(&admin));
        assert!(todo_list.task_counter == 1, 5);

        let task_record= table::borrow(&todo_list.tasks,todo_list.task_counter);
        print(task_record);
        assert!(task_record.task_id ==1,6);

        assert!(task_record.completed == false, 7);

        // complete task

    }

}