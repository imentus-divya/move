module divyaAddress::Structs
{
    use std::debug::print;
    use std::vector;

    struct SDE has key, store ,drop
    {
        name:vector<u8>,
        experience:u8,
    }

    struct Team has key, store, drop
    {
        sde_present:vector<SDE>
    }

    public fun add_sde(new_name:vector<u8>,new_experience:u8 ):SDE
    {
        let sde = SDE {name:new_name , experience:new_experience};
        return sde
    }
    
    public fun add_sdes(sde:SDE , team:Team)
    {

    }
    
    #[test]
    fun test_salary()
    {
        // "b" -- byte encoded vector
       let divya=add_sde(b"Divya",1 );
       print(&std::string::utf8(divya.name));



       let tina=add_sde(b"Tina",2 );
       print(&tina);



    } 

}
