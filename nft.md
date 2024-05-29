# NFT

 This quest features a Non Fungible Token (NFT) module. The module allows the collection manager 
 to mint NFTs and withdraw NFT sales, allows users to combine two NFTs into a new NFT and burn 
 NFTs.

```move
module overmind::NonFungibleToken {

    //==============================================================================================
    // Dependencies
    //==============================================================================================
    use sui::event;
    use std::vector;
    use sui::sui::SUI;
    use sui::transfer;
    use sui::url::{Self, Url};
    use sui::coin::{Self, Coin};
    use std::string::{Self, String};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

    #[test_only]
    use sui::test_scenario;
    #[test_only]
    use sui::test_utils::assert_eq;

    //==============================================================================================
    // Constants - Add your constants here (if any)
    //==============================================================================================

    //==============================================================================================
    // Error codes - DO NOT MODIFY
    //==============================================================================================
    const EInsufficientPayment: u64 = 1;
    const ECodeForAllErrors: u64 = 2;

    //==============================================================================================
    // Module Structs - DO NOT MODIFY
    //==============================================================================================

    /* 
        The NonFungibleToken object represents an NFT. It contains the following fields:
        - `id` - the ID of the NFT
        - `name` - the name of the NFT
        - `description` - the description of the NFT
        - `image` - the image of the NFT
    */
    struct NonFungibleToken has key {
        id: UID,
        name: String,
        description: String,
        image: Url,
    }

    /* 
        The MinterCap object represents the minter cap. It contains the following fields:
        - `id` - the ID of the MinterCap object
        - `sales` - the sales balance of the MinterCap object
    */
    struct MinterCap has key {
        id: UID,
        sales: Balance<SUI>,
    }

    //==============================================================================================
    // Event structs - DO NOT MODIFY
    //==============================================================================================
    /* 
        Event emitted when an NFT is minted in mint_nft. It contains the following fields:
        - `nft_id` - the ID of the NFT
        - `recipient` - the address of the recipient
    */
    struct NonFungibleTokenMinted has copy, drop {
        nft_id: ID,
        recipient: address
    }

    /* 
        Event emitted when two NFTs are combined into a new NFT. It contains the following 
        fields:
        - `nft1_id` - the ID of the first NFT
        - `nft2_id` - the ID of the second NFT
        - `new_nft_id` - the ID of the new NFT
    */
    struct NonFungibleTokenCombined has copy, drop {
        nft1_id: ID,
        nft2_id: ID,
        new_nft_id: ID,
    }

    /* 
        Event emitted when an NFT is deleted in burn_nft. It contains the following fields:
        - `nft_id` - the ID of the NFT
    */
    struct NonFungibleTokenDeleted has copy, drop {
        nft_id: ID,
    }

    /* 
        Event emitted whenever the sales balance is withdrawn from the MinterCap object. It 
        contains the following fields:
        - `amount` - the amount withdrawn
    */
    struct SalesWithdrawn has copy, drop {
        amount: u64
    }


    //==============================================================================================
    // Functions
    //==============================================================================================
    
    /* 
        Initializes the minter cap object and transfers it to the deployer of the module. 
        This function is called only once during the deployment of the module.
        @param ctx - the transaction context
    */
    fun init(ctx: &mut TxContext) {
        // let id = object::new_uid_from_hash(tx_context::sender(ctx));

        let cap = MinterCap {
            id:object::new(ctx),
            sales:balance::zero()
        };

        transfer::transfer(cap, tx_context::sender(ctx))

    }

    /* 
        Mints a new NFT and transfers it to the recipient. This can only be called by the owner of 
        the MinterCap object. The remaining payment is returned. Abort if the payment is below the 
        price of the NFT.
        @param recipient - the address of the recipient
        @param nft_name - the name of the NFT
        @param nft_description - the description of the NFT
        @param nft_image - the image of the NFT
        @param payment_coin - the coin used to pay for the NFT
        @param minter_cap - the minter cap object
        @param ctx - the transaction context
        @return the change coin
    */
    public fun mint_nft(
        recipient: address, 
        nft_name: vector<u8>, 
        nft_description: vector<u8>, 
        nft_image: vector<u8>,
        payment_coin: &mut Coin<SUI>,
        minter_cap: &mut MinterCap,
        ctx: &mut TxContext, 
    ) {
        let all_mmoney = coin::balance(payment_coin);
        assert!(balance::value(all_mmoney) >= 1000000000,EInsufficientPayment);
        let payments = coin::split(payment_coin,1000000000,ctx);
        let coins = coin::into_balance(payments);
        balance::join(&mut minter_cap.sales, coins);
        

        let nft = NonFungibleToken {
            id:object::new(ctx),
            name:string::utf8(nft_name),
            description: string::utf8(nft_description),
            image:url::new_unsafe_from_bytes(nft_image)
        };


        event::emit(NonFungibleTokenMinted {
            nft_id:object::uid_to_inner(&nft.id),
            recipient
        });

        transfer::transfer(nft,recipient);
        
    }

    /* 
        Takes two NFTs and combines them into a new NFT. The two NFTs are deleted. This can only be
        called by the owner of the NFT objects.
        @param nft1 - the first NFT object
        @param nft2 - the second NFT object
        @param new_image_url - the image of the new NFT
        @param ctx - the transaction context
        @return the new NFT object
    */
    public fun combine_nfts(
        nft1: NonFungibleToken,
        nft2: NonFungibleToken,
        new_image_url: vector<u8>,
        ctx: &mut TxContext,
    ): NonFungibleToken {
        let  NonFungibleToken {id:nft_id1,name:nft_name,description:_,image:_} = nft1;
        let  NonFungibleToken {id:nft_id2,name:nft2_name,description:_,image:_} = nft2;

        // assert!(exists<NonFungibleToken>(tx_context::sender(ctx)),3);

        let desc  = string::utf8(b"Combined NFT of ");
        let name = string::utf8(b"");
        string::append(&mut name,nft_name);
        string::append(&mut name,string::utf8(b" + "));
        string::append(&mut name,nft2_name);
        string::append(&mut desc,nft_name);
        // string::append(&mut desc,string::utf8(b"And"));
        string::append(&mut desc,string::utf8(b" and "));
        string::append(&mut desc,nft2_name);
        let new_nft = NonFungibleToken {
            id:object::new(ctx),
            name:name,
            description:desc,
            image:url::new_unsafe_from_bytes(new_image_url)
        };
        event::emit(NonFungibleTokenCombined {
            nft1_id:object::uid_to_inner(&nft_id1),
            nft2_id:object::uid_to_inner(&nft_id2),
            new_nft_id:object::uid_to_inner(&new_nft.id)
        });
        object::delete(nft_id1);
        object::delete(nft_id2);
        new_nft



        
    }

    /* 
        Withdraws the sales balance from the MinterCap object. This can only be called by the owner 
        of the MinterCap object.
        @param minter_cap - the minter cap object
        @param ctx - the transaction context
        @return the withdrawn coin
    */
    public fun withdraw_sales(
        minter_cap: &mut MinterCap,
        ctx: &mut TxContext,
    ): Coin<SUI> {


        let withdrawn_amount = balance::value(&minter_cap.sales);
        let withdrawn_coin = balance::split(&mut minter_cap.sales, withdrawn_amount);
        let main_coin = coin::from_balance(withdrawn_coin,ctx);

        event::emit(SalesWithdrawn { amount: withdrawn_amount });

        main_coin

        
    }

    /*
        Deletes the NFT object. This can only be called by the owner of the NFT object.
        @param nft - the NFT object
    */
    public fun burn_nft(nft: NonFungibleToken) {
        let NonFungibleToken {id:id,name:_,description:_,image:_} = nft;
        let nft_id = object::uid_to_inner(&id);
        event::emit(NonFungibleTokenDeleted { nft_id });
        object::delete(id);
        
    }

    /* 
        Gets the NFT's `name`
        @param nft - the NFT object
        @return the NFT's `name`
    */
    public fun name(nft: &NonFungibleToken): String {

        nft.name
    }

    /* 
        Gets the NFT's `description`
        @param nft - the NFT object
        @return the NFT's `description`
    */
    public fun description(nft: &NonFungibleToken): String {
        nft.description

    }

    /* 
        Gets the NFT's `image`
        @param nft - the NFT object
        @return the NFT's `image`
    */
    public fun url(nft: &NonFungibleToken): Url {
        nft.image
        
    }
}
```
