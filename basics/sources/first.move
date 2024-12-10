// my_addrrx = account owning file
// FirstContract = name of file containing bussiness logic
module divyaAddress::FirstContract
{
    // the debug module has "print" function 
    use std::debug::print;


    // u8
    // u16
    // u64
    // u128

    fun primitive_datatype()
    {
        let b:u8=1;
        print(&b);

        let c:u64=1500;
        print(&c);


        let a:u128=592001;
        print(&a);

        let boolean:bool= false;
        print(&boolean);

        // // named address
        // let addrx_:address = @divyaAddress;
        // // print(addrx_);

        // // numerical address
        // let addrx2_:address =@0x1234;
        // // print(addrx2_);

    }

    // testcase for invoking func
    // #[test]
    // fun test_primitive_datatype()
    // {
    //     primitive_datatype();
    // }
}