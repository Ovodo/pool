# Lending Protocol
  A lending protocol is a smart contract system that allows users to lend and borrow coins. 
  Users can lend out their coins by supplying the liquidity pools, and can borrow coins from the
  liquidity pools. 

  This module is the basis for an overcollateralized lending protocol. This means that borrowers
  need to have lended more coins than they are borrowing. This is to ensure that the lenders are
  protected. 

  ```move
module overmind::lending {
    //==============================================================================================
    // Dependencies
    //==============================================================================================
    use sui::math;
    use std::vector;
    use std::debug;
    use std::string;
    use sui::transfer;
    use overmind::dummy_oracle;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};

    #[test_only]
    use sui::test_scenario;
    #[test_only]
    use sui::test_utils::{assert_eq, destroy};
    #[test_only]
    use sui::sui::SUI;

    //==============================================================================================
    // Constants - Add your constants here (if any)
    //==============================================================================================

    //==============================================================================================
    // Error codes - DO NOT MODIFY
    //==============================================================================================
    
    //================
    }

    /*
        This is the state of the protocol. It contains the number of pools and the users of the protocol.
        This should be created and shared globally when the protocol is initialized.
    */
    struct ProtocolState has key {
        id: UID, 
        number_of_pools: u64, // The number of pools in the protocol. Default is 0.
        users: Table<address, UserData> // All user data of the protocol.
    }

    /*
        This is the pool resource. It contains the asset number of the pool, and the reserve of the pool.
        When a pool is created, it should be shared globally.
    */
    struct Pool<phantom CoinType> has key {
        id: UID, 
        /* 
            The asset number of the pool. This aligns with the index of collateral and borrow amounts in 
            the user data. This is also used to fetch the price and decimal precision of the coin from
            the price feed with the get_price_and_decimals function.
        */
        asset_number: u64, 
        /*
            The reserve of the pool. This is the total amount of the coin in the pool that are 
            available for borrowing or withdrawing.
        */
        reserve: Balance<CoinType>
    }

    /* 
        This is the user data resource. It contains the collateral and borrowed amounts of the user.
    */
    struct UserData has store {
        /* 
            The amount of collateral the user has in each pool. the index of the collateral amount
            aligns with the asset number of the pool.
        */
        collateral_amount: Table<u64, u64>, 
        /* 
            The amount of coins the user has borrowed in each pool. the index of the borrowed amount
            aligns with the asset number of the pool.
        */
        borrowed_amount: Table<u64, u64>,
    }

    //==============================================================================================
    // Functions
    //==============================================================================================

    /*
        Initializes the protocol by creating the admin capability and the protocol state.
    */
    fun init(ctx: &mut TxContext) {
        let cap = AdminCap {
            id:object::new(ctx)
        };
        transfer::transfer(cap,tx_context::sender(ctx));
        let state = ProtocolState {
            id:object::new(ctx),
            number_of_pools:0,
            users:table::new(ctx)
        };
        transfer::share_object(state)

    }

    /*
        Creates a new pool for a new coin type. This function can only be called by the admin.
    */
    public fun create_pool<CoinType>(
        _: &mut AdminCap,
        state: &mut ProtocolState,
        ctx: &mut TxContext
    ) {

            let pool = Pool{
                id:object::new(ctx),
                asset_number:state.number_of_pools,
                reserve:balance::zero<CoinType>()
            };
            transfer::share_object(pool);
      
        state.number_of_pools = state.number_of_pools +  1;

    }

    /*
        Deposits a coin to a pool. This function increases the user's collateral amount in the pool
        and adds the coin to the pool's reserve.
    */
    public fun deposit<CoinType>(
        coin_to_deposit: Coin<CoinType>,
        pool: &mut Pool<CoinType>,
        state: &mut ProtocolState,
        ctx: &mut TxContext
    ) { 
        if(table::contains(&state.users,tx_context::sender(ctx))){

        let user_data = table::borrow_mut(&mut state.users, tx_context::sender(ctx));
        if(table::contains(&user_data.collateral_amount,pool.asset_number)){
            let coll_val = table::remove(&mut user_data.collateral_amount, pool.asset_number);
            let new_val = coll_val + coin::value(&coin_to_deposit);
            table::add(&mut user_data.collateral_amount,pool.asset_number,new_val);
        }else{

            table::add(&mut user_data.collateral_amount,pool.asset_number,coin::value(&coin_to_deposit));
        };
        }else{



        let coll_table = table::new(ctx);
        table::add(&mut coll_table,pool.asset_number,coin::value(&coin_to_deposit));

        let user_data = UserData {
            collateral_amount:coll_table,
            borrowed_amount:table::new(ctx)
        };
        table::add(&mut state.users, tx_context::sender(ctx), user_data);
        };

        let coin_bal = coin::into_balance(coin_to_deposit);
        balance::join(&mut pool.reserve,coin_bal);


        
    }

    /*
        Withdraws a coin from a pool. This function decreases the user's collateral amount in the pool
        and removes the coin from the pool's reserve.
    */
    public fun withdraw<CoinType>(
        amount_to_withdraw: u64, 
        pool: &mut Pool<CoinType>,
        state: &mut ProtocolState,
        ctx: &mut TxContext
    ): Coin<CoinType> {
        
        let user_data = table::borrow_mut(&mut state.users, tx_context::sender(ctx));
        let coll_val = table::remove(&mut user_data.collateral_amount, pool.asset_number);
        let new_val = coll_val -amount_to_withdraw;
        table::add(&mut user_data.collateral_amount,pool.asset_number,new_val);
        let bal = balance::split(&mut pool.reserve,amount_to_withdraw);
        let coin = coin::from_balance(bal,ctx);
        coin
        
    }

    /*
        Borrows a coin from a pool. This function increases the user's borrowed amount in the pool
        and removes and returns the coin from the pool's reserve.
    */
    public fun borrow<CoinType>(
        amount_to_borrow: u64, 
        pool: &mut Pool<CoinType>,
        state: &mut ProtocolState,
        ctx: &mut TxContext
    ): Coin<CoinType> {

        let user_data = table::borrow_mut(&mut state.users, tx_context::sender(ctx));
        if(table::contains(&mut user_data.borrowed_amount,pool.asset_number)){

        let borr_val = table::remove(&mut user_data.borrowed_amount, pool.asset_number);
        table::add(&mut user_data.borrowed_amount,pool.asset_number,(borr_val+amount_to_borrow));
        }else table::add(&mut user_data.borrowed_amount,pool.asset_number,(amount_to_borrow));

        let balance_to_borrow = balance::split(&mut pool.reserve,amount_to_borrow);
        let coin = coin::from_balance(balance_to_borrow,ctx);
        coin
        
    }

    /*
        Repays a coin to a pool. This function decreases the user's borrowed amount in the pool
        and adds the coin to the pool's reserve.
    */
    public fun repay<CoinType>(
        coin_to_repay: Coin<CoinType>,
        pool: &mut Pool<CoinType>,
        state: &mut ProtocolState,
        ctx: &mut TxContext
    ) {
        let user_data = table::borrow_mut(&mut state.users, tx_context::sender(ctx));
        if(table::contains(&mut user_data.borrowed_amount,pool.asset_number)){

        let repay_val = table::remove(&mut user_data.borrowed_amount, pool.asset_number);
        table::add(&mut user_data.borrowed_amount,pool.asset_number,(repay_val-coin::value(&coin_to_repay)));
        };

        let bal = coin::into_balance(coin_to_repay);
        balance::join(&mut pool.reserve,bal);
        
    }

    /*  
        Calculates the health factor of a user. The health factor is the ratio of the user's collateral
        to the user's borrowed amount. The health factor is calculated with a decimal precision of 2. 
        This means that a health factor of 1.34 should be represented as 134, and a health factor of 0.34
        should be represented as 34.

        See above for more information on how to calculate the health factor.
    */
    public fun calculate_health_factor(
        user: address,
        state: &ProtocolState,
        price_feed: &dummy_oracle::PriceFeed
    ): u64 {

        let user_data = table::borrow(&state.users, user);
        
        let total_collateral_value: u64 = 0;
        let total_borrowed_value: u64 = 0;
        let i = 0;
        while(i <= table::length(&user_data.collateral_amount)-1){
            let coll_amount = *table::borrow(&user_data.collateral_amount,i);
            let (coll_price, coll_decimals) = overmind::dummy_oracle::get_price_and_decimals(i,price_feed);
            let coll_value_usd = mul_dec(coll_price, coll_decimals, coll_amount);
            total_collateral_value = total_collateral_value + coll_value_usd;
            i = i+ 1;
        };

        let i = 0;
        while(i <= table::length(&user_data.borrowed_amount)-1){
            
            let borr_amount = *table::borrow(&user_data.borrowed_amount,i);
            let (borr_price, borr_decimals) = overmind::dummy_oracle::get_price_and_decimals(i,price_feed);
            let borr_value_usd = mul_dec(borr_price, borr_decimals, borr_amount);
            total_borrowed_value = total_borrowed_value + borr_value_usd;
            i = i +1;
        };
        debug::print(&total_borrowed_value);
        debug::print(&total_collateral_value);
        let health_factor = (total_collateral_value * 80 * math::pow(10,2) ) /( total_borrowed_value * 100);
        
        health_factor
            
    }


    fun mul_dec(price: u64, decimals: u8, amount: u64) : u64 {
        let power = math::pow(10, decimals);
        let adjusted_amount = amount / power;
        let result = adjusted_amount * price;
        result
    } 
}


  ```
