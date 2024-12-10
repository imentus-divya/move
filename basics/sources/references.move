// & symbol is used to represent references. 
// reference is a way to access data without taking ownership of it, allowing you to read or modify values without duplicating them.

// There are 2 types of references -
// 1- Immutable : existing values cant be modified
// 2- Mutable : allow for modifications

module divyaAddress::imutable_code
{
    use std::debug::print;

    fun Receiver(ix:&u8)
    {
        let c=*ix;

        print(&c);
    }

    fun Sender()
    {
        let x:u8=5;
        Receiver(&x);

        // another approach
        let num=101;
        let copy_num=&num;
        let deref_num=*copy_num;

        print(&num);
        print(copy_num);
        print(&deref_num);


    }

    // #[test]
    // fun testing()
    // {
    //     Sender();
    // }

}

module divyaAddress::mutable_code{

    use std::debug::print;

   fun immutablity()
   {
     let num =29012000;
     print(&num);

     let reference_of_num=&mut num;
      print(reference_of_num);


      *reference_of_num=29012001;

      print(reference_of_num);
      print(&num);
   }

//    #[test]
//    fun tests()
//    {
//     immutablity()
//    }
}

