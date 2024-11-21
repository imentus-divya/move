// private -  by default the functions in move are private (they can only be accessed within same module and cannot be
//  accessed outside the same module or script)

// public - can be called by any function in any module or script

// public (friend) - can be called by any function in same module & by the function of module which are explicitly defined in friends list

module divyaAddress::A
{
  
    friend divyaAddress::B;
    use std::debug::print;

     public fun A_func():u16
    {
        return 100
    }



    fun A_func2():u16
    {
        let a= A_func();
        return a
        // return A_func()
    }

    public(friend) fun A_func3():u64
    {
        return 115511
    }

//  #[test]
 
// fun testing() 
// {
//     let a=A_func2();
//     print(&a);
// }

}

module divyaAddress::B

{
    use std::debug::print;

    fun B_func():u16
    {
        return divyaAddress::A::A_func()
    }

//  #[test]
// fun testing()
// {
//     let a=B_func();
//     print(&a);


//     let another_A_func= divyaAddress::A::A_func3();
//     print(&another_A_func);
// }

}

