
/* 
    This quest features a AMM (Automated Market Maker) liquidity pool. This module provides the 
    base functionality of an AMM that can be used to create a decentralized exchange on the Sui 
    blockchain.

    AMM:
        An AMM (Automated Market Maker) is a decentralized exchange that uses a mathematical formula
        to price assets against each other. Liquidity providers deposit two assets into a liquidity
        pool. The AMM uses a constant product formula to price assets against each other. The 
        constant product formula is: 
            x * y = k
        where:
            - x is the amount of the first asset
            - y is the amount of the second asset
            - k is a constant

        The constant product formula is used to price assets against each other. For example, if
        the liquidity pool contains 1000 coins of asset A and 1000 coins of asset B, then the
        constant product formula is:
            1000 * 1000 = 1000000

        If a user wants to swap 100 coins of asset A for asset B, then the constant product formula
        is:
            (1000 + 100) * (1000 - x) = 1000000
        where x is the amount of asset B that the user will receive. Solving for x, we get:
            x = ~90.909

        The user will receive 90.91 coins of asset B. The liquidity pool will now contain 1100 coins
        of asset A and 909.09 coins of asset B. The constant product formula is:
            1100 * 909.091 = 1000000

        We can see that the constant product formula maintains the constant value (k) of 1000000.

    Liquidity Pool Coins: 
        Each liquidity pool has a liquidity pool coin (LP coin) that represents the liquidity in the
        pool. The LP coins are minted when liquidity is added to the pool and burned when liquidity is
        removed from the pool. The LP coin is used to track the liquidity in the pool, to manage and 
        reward liquidity providers, as well as other uses. 

        Each liquidity pool will have its own LPCoin supply, which represents the total amount of LP
        coins in circulation. The LPCoin supply is stored in the liquidity pool object.

    Creating a liquidity pool: 
        Anyone has the ability to create a liquidity pool for two coins. The function takes two type 
        parameters, CoinA and CoinB, which are the types of the first and second coins in the 
        liquidity pool.

        Creating a liquidity pool also requires the initial liquidity to be supplied to the pool. 

        The amount of LP coins to mint based on the provided liquidity is as follows: 
            sqrt(amount_coin_a * amount_coin_b) - 1000, where: 
                    - amount_coin_a is the amount of coin A being supplied
                    - amount_coin_b is the amount of coin B being supplied
                    - 1000 is the minimum liquidity that is locked in the pool and 
                        cannot be removed. This is to help stabilize the pool. 
                    - sqrt is the square root

                The first 1000 LP coins are sent to the initial_lp_coin_reserve to lock the 
                liquidity. The remaining LP coins are sent to the liquidity provider.

    Supply liquidity: 
        Liquidity can be supplied to a liquidity pool with the supply_liquidity function. The 
        function takes two parameters, coin_a and coin_b, which are the coins being supplied to the
        liquidity pool. The function returns the LP coins that were minted for the liquidity pool.

        The amount of LP coins minted is calculated with the following formula:
            min(amount_coin_a * lp_coins_total_supply / amount_coin_a_reserve, 
                amount_coin_b * lp_coins_total_supply / amount_coin_b_reserve)
            where:
                - amount_coin_a is the amount of coin A being supplied
                - amount_coin_b is the amount of coin B being supplied
                - lp_coins_total_supply is the total supply of the LP coins for the liquidity 
                    pool
                - amount_coin_a_reserve is the amount of coin A in the liquidity pool
                - amount_coin_b_reserve is the amount of coin B in the liquidity pool
                - min fetches the minimum value of the two values

            In this case, all of the LP coins are sent to the liquidity provider. 

    Remove liquidity:
        Liquidity can be removed from a liquidity pool with the remove_liquidity function. The 
        function returns the two coins that were removed from the liquidity pool.

        The amount of coins being removed from the liquidity pool is calculated with the following
        formula:
            amount_coin_a = amount_lp_coins * amount_coin_a_reserve / lp_coins_total_supply
            amount_coin_b = amount_lp_coins * amount_coin_b_reserve / lp_coins_total_supply
            where:
                - amount_lp_coins is the amount of LP coins being redeemed
                - amount_coin_a_reserve is the amount of coin A in the liquidity pool
                - amount_coin_b_reserve is the amount of coin B in the liquidity pool
                - lp_coins_total_supply is the total supply of the LP coins for the liquidity pool

        The two coins being removed from the liquidity pool are extracted from their respective
        reserves in the liquidity pool and returned to the user. 

        The LP coins being redeemed are burned.

    Swapping coins: 
        There are multiple functions for swapping coins based on the type of swap. The available 
        types of swaps are: 
            - swap_exact_a_for_b: Swaps an exact amount of CoinA for as much CoinB as possible. This
                includes the minimum amount of CoinB that the user is willing to receive. If the 
                optimal (amount that satisfies the constant product formula) amount of CoinB is
                less than the minimum amount of CoinB, then the swap should abort. This means that
                the slippage was too high.
            - swap_exact_b_for_a: Swaps an exact amount of CoinB for as much CoinA as possible. This 
                includes the minimum amount of CoinA that the user is willing to receive. If the 
                optimal (amount that satisfies the constant product formula) amount of CoinA is
                less than the minimum amount of CoinA, then the swap should abort. This means that
                the slippage was too high.
            - swap_a_for_exact_b: Swaps as little CoinA as possible for an exact amount of CoinB. 
                This includes the maximum amount of CoinA that the user is willing to spend. If the
                optimal (amount that satisfies the constant product formula) amount of CoinA is
                greater than the maximum amount of CoinA, then the swap should abort. This means
                that the slippage was too high.
            - swap_b_for_exact_a: Swaps as little CoinB as possible for an exact amount of CoinA.
                This includes the maximum amount of CoinB that the user is willing to spend. If the
                optimal (amount that satisfies the constant product formula) amount of CoinB is
                greater than the maximum amount of CoinB, then the swap should abort. This means
                that the slippage was too high.

        All of these functions follow the same formula for switching: 
            new_coin_a_reserve * new_coin_b_reserve = prev_coin_a_reserve * prev_coin_b_reserve
            where:
                - new_coin_a_reserve is the new amount of coin A in the liquidity pool with the 
                    swapped coins
                - new_coin_b_reserve is the new amount of coin B in the liquidity pool with the 
                    swapped coins
                - prev_coin_a_reserve is the previous amount of coin A in the liquidity pool
                - prev_coin_b_reserve is the previous amount of coin B in the liquidity pool

    Math: 
        When perform liquidity pool math calculations, values are cast to u128 to avoid overflow. 
        In production, it is best to check that the result of the math calculation is not too big
        before casting back down to u64.
*/
module overmind::liquidity_pool {
    //==============================================================================================
    // Dependencies
    //==============================================================================================
    use sui::math;
    use std::vector;
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::balance::{Self, Balance, Supply};
    use sui::coin::{Self, Coin};

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
    const EInsufficientLiquidity: u64 = 1;
    const ESlippageLimitExceeded: u64 = 2;
    const EInvalidSwapParameters: u64 = 3;
    
    //==============================================================================================
    // Module Structs - DO NOT MODIFY
    //==============================================================================================

    /* 
        This struct represents the liquidity pool coin (LP coin) for a liquidity pool. The LP coins
        are minted when liquidity is added to the pool and burned when liquidity is removed from the
        pool. The LP coin is tracked using the LPCoin supply in the liquidity pool object.
    */
    struct LPCoin<phantom CoinA, phantom CoinB> has drop {}

    /* 
        This struct represents a liquidity pool. Liquidity pools are created for two coins. The 
        liquidity pool contains the reserves for the two coins, the total supply of the LP coins, 
        and the initial LP coin reserve.
    */
    struct LiquidityPool<phantom CoinA, phantom CoinB> has key {
        id: UID, // The unique ID of the liquidity pool
        coin_a_balance: Balance<CoinA>, // The reserve of the first coin
        coin_b_balance: Balance<CoinB>, // The reserve of the second coin
        lp_coin_supply: Supply<LPCoin<CoinA, CoinB>>, // The total supply of the LP coins - this is how
        // the LPCoins are tracked
        initial_lp_coin_reserve: Balance<LPCoin<CoinA, CoinB>>, // The initial LP coin reserve
    }

    //==============================================================================================
    // Functions
    //==============================================================================================

    /* 
		Creates a liquidity pool for CoinA and CoinB and supplies it with initial liquidity. Aborts
        if the liquidity is not above the minimum initial liquidity.
        @type_param CoinA - the type of the first coin for the liquidity pool
        @type_param CoinB - the type of the second coin for the liquidity pool
        @param coin_a - coins that match the first coin in the liquidity pool. The initial liquidity
            of coin A.
        @param coin_b - coins that match the second coin in the liquidity pool. The initial 
            liquidity of coin B.
        @param ctx - the transaction context
        @return - liquidity coins from the pool being supplied
    */
    public fun create_liquidity_pool<CoinA, CoinB>(
        coin_a: Coin<CoinA>,
        coin_b: Coin<CoinB>,
        ctx: &mut TxContext
    ): Coin<LPCoin<CoinA, CoinB>> {
        
    }

    /* 
		Supplies liquidity to a pool for a cost of liquidity coins. Aborts if the amounts of coins
        to supply are not above 0.
        @type_param CoinA - the type of the first coin for the liquidity pool
        @type_param CoinB - the type of the second coin for the liquidity pool
		@param coin_a - coins that match the first coin in the liquidity pool. The liquidity of 
            coin A.
		@param coin_b - coins that match the second coin in the liquidity pool. The liquidity of 
            coin B.
        @param pool - the liquidity pool to supply
        @param ctx - the transaction context
		@return - liquidity coins from the pool being supplied
    */
    public fun supply_liquidity<CoinA, CoinB>(
        coin_a: Coin<CoinA>, 
        coin_b: Coin<CoinB>,
        pool: &mut LiquidityPool<CoinA, CoinB>,
        ctx: &mut TxContext
    ): Coin<LPCoin<CoinA, CoinB>> {

    }

    /* 
		Removes liquidity from a pool for a cost of liquidity coins. Aborts if the amounts of coins
        to return are not above 0. 
        @type_param CoinA - the type of the first coin for the liquidity pool
        @type_param CoinB - the type of the second coin for the liquidity pool
		@param lp_coins - liquidity coins from the pool being supplied
        @param pool - the liquidity pool to remove liquidity from
        @param ctx - the transaction context
		@return - the two coins being removed from the liquidity pool
    */
    public fun remove_liquidity<CoinA, CoinB>(
        lp_coins_to_redeem: Coin<LPCoin<CoinA, CoinB>>,
        pool: &mut LiquidityPool<CoinA, CoinB>,
        ctx: &mut TxContext
    ): (Coin<CoinA>, Coin<CoinB>) {
        
    }

    /*
        Swaps exact CoinA for CoinB. Aborts if the amounts of coins to swap are not above 0, or if 
        the amount of slippage is too high.
        @type_param CoinA - the type of the first coin for the liquidity pool
        @type_param CoinB - the type of the second coin for the liquidity pool
        @param coin_a_in - coins that match the first coin in the liquidity pool
        @param pool - the liquidity pool to swap in
        @param min_amount_coin_b_out - the minimum amount of the second coin to receive
        @param ctx - the transaction context
        @return - the amount of the second coin received
    */
    public fun swap_exact_a_for_b<CoinA, CoinB>(
        coin_a_in: Coin<CoinA>, 
        pool: &mut LiquidityPool<CoinA, CoinB>,
        min_amount_coin_b_out: u64,
        ctx: &mut TxContext
    ): Coin<CoinB> {
        
    }

    /*
        Swaps exact CoinB for CoinA. Aborts if the amounts of coins to swap are not above 0 or if 
        the amount of slippage is too high.
        @type_param CoinA - the type of the first coin for the liquidity pool
        @type_param CoinB - the type of the second coin for the liquidity pool
        @param coin_b_in - coins that match the second coin in the liquidity pool
        @param pool - the liquidity pool to swap in
        @param min_amount_coin_a_out - the minimum amount of the first coin to receive
        @param ctx - the transaction context
        @return - the amount of the first coin received
    */
    public fun swap_exact_b_for_a<CoinA, CoinB>(
        coin_b_in: Coin<CoinB>, 
        pool: &mut LiquidityPool<CoinA, CoinB>,
        min_amount_coin_a_out: u64,
        ctx: &mut TxContext
    ): Coin<CoinA> {
        
    }

    /*
        Swaps CoinA for exact CoinB. Aborts if the amounts of coins to swap are not above 0 or if 
        the amount of slippage is too high.
        @type_param CoinA - the type of the first coin for the liquidity pool
        @type_param CoinB - the type of the second coin for the liquidity pool
        @param coin_a_in - coins that match the first coin in the liquidity pool
        @param pool - the liquidity pool to swap in
        @param amount_coin_b_out - the amount of the second coin to receive
        @param ctx - the transaction context
        @return - the amount of the second coin received
    */
    public fun swap_a_for_exact_b<CoinA, CoinB>(
        max_coin_a_in: &mut Coin<CoinA>,
        amount_coin_b_out: u64, 
        pool: &mut LiquidityPool<CoinA, CoinB>,
        ctx: &mut TxContext
    ): Coin<CoinB> {
        
    }   

    /*
        Swaps CoinB for exact CoinA. Aborts if the amounts of coins to swap are not above 0 or if
        the amount of slippage is too high.
        @type_param CoinA - the type of the first coin for the liquidity pool
        @type_param CoinB - the type of the second coin for the liquidity pool
        @param coin_b_in - coins that match the second coin in the liquidity pool
        @param pool - the liquidity pool to swap in
        @param amount_coin_a_out - the amount of the first coin to receive
        @param ctx - the transaction context
        @return - the amount of the first coin received
    */
    public fun swap_b_for_exact_a<CoinA, CoinB>(
        max_coin_b_in: &mut Coin<CoinB>,
        amount_coin_a_out: u64, 
        pool: &mut LiquidityPool<CoinA, CoinB>,
        ctx: &mut TxContext
    ): Coin<CoinA> {
        
    }

    //==============================================================================================
    // Tests - DO NOT MODIFY
    //==============================================================================================

    #[test_only]
    struct COIN1 has drop {}
    #[test_only]
    struct COIN2 has drop {}

    #[test]
    fun test_create_liquidity_pool_success_sui_and_coin1_exact_minimum() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1 = 1000;
        let amount_coin2 = 1000;
        let expected_lp_coin_amount = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_create_liquidity_pool_success_sui_and_coin1_more_than_minimum() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1 = 2000;
        let amount_coin2 = 2000;
        let expected_lp_coin_amount = 1000;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EInsufficientLiquidity)]
    fun test_create_liquidity_pool_failure_insufficient_liquidity_coin_a() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1 = 999;
        let amount_coin2 = 1000;
        let expected_lp_coin_amount = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount
            );

            coin::burn_for_testing(lp_coin);
        };

        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EInsufficientLiquidity)]
    fun test_create_liquidity_pool_failure_insufficient_liquidity_coin_b() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1 = 1000;
        let amount_coin2 = 999;
        let expected_lp_coin_amount = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount
            );

            coin::burn_for_testing(lp_coin);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_supply_liquidity_success_supply_balanced_liquidity_100_percent() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_supply_liquidity_success_supply_balanced_liquidity_50_percent() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 500;
        let amount_coin2_2 = 500;
        let expected_lp_coin_amount_2 = 500;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_supply_liquidity_success_supply_more_coin_a() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 2000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_supply_liquidity_success_supply_more_coin_b() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 2000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EInsufficientLiquidity)]
    fun test_supply_liquidity_failure_supply_zero_coin_a() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 0;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 0;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EInsufficientLiquidity)]
    fun test_supply_liquidity_failure_supply_zero_coin_b() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 0;
        let expected_lp_coin_amount_2 = 0;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_remove_liquidity_success_remove_10_percent_supply() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_to_burn = 100;
        let expected_coin1_out = 100;
        let expected_coin2_out = 100;
        {
            let lp_coin_to_burn = coin::mint_for_testing<LPCoin<COIN1, COIN2>>(amount_to_burn, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let (coin_1_out, coin_2_out) = remove_liquidity<COIN1, COIN2>(
                lp_coin_to_burn,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&coin_1_out),
                expected_coin1_out
            );
            assert_eq(
                coin::value(&coin_2_out),
                expected_coin2_out
            );

            coin::burn_for_testing(coin_1_out);
            coin::burn_for_testing(coin_2_out);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000 - amount_to_burn
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 - expected_coin1_out
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 - expected_coin2_out
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_remove_liquidity_success_remove_50_percent_supply() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_to_burn = 500;
        let expected_coin1_out = 500;
        let expected_coin2_out = 500;
        {
            let lp_coin_to_burn = coin::mint_for_testing<LPCoin<COIN1, COIN2>>(amount_to_burn, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let (coin_1_out, coin_2_out) = remove_liquidity<COIN1, COIN2>(
                lp_coin_to_burn,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&coin_1_out),
                expected_coin1_out
            );
            assert_eq(
                coin::value(&coin_2_out),
                expected_coin2_out
            );

            coin::burn_for_testing(coin_1_out);
            coin::burn_for_testing(coin_2_out);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000 - amount_to_burn
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 - expected_coin1_out
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 - expected_coin2_out
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EInsufficientLiquidity)]
    fun test_remove_liquidity_failure_zero_lp_coin_amount() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_to_burn = 0;
        let expected_coin1_out = 0;
        let expected_coin2_out = 0;
        {
            let lp_coin_to_burn = coin::mint_for_testing<LPCoin<COIN1, COIN2>>(amount_to_burn, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let (coin_1_out, coin_2_out) = remove_liquidity<COIN1, COIN2>(
                lp_coin_to_burn,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&coin_1_out),
                expected_coin1_out
            );
            assert_eq(
                coin::value(&coin_2_out),
                expected_coin2_out
            );

            coin::burn_for_testing(coin_1_out);
            coin::burn_for_testing(coin_2_out);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000 - amount_to_burn
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 - expected_coin1_out
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 - expected_coin2_out
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_swap_exact_a_for_b_success_high_slippage() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin1_in = 1000;
        let expected_amount_coin2_out = 667;
        let minimum_amount_coin2_out = 600;
        {
            let coin_1_in = coin::mint_for_testing<COIN1>(exact_amount_coin1_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let amount_coin2_out = swap_exact_a_for_b<COIN1, COIN2>(
                coin_1_in,
                &mut lp_pool,
                minimum_amount_coin2_out,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&amount_coin2_out),
                expected_amount_coin2_out
            );

            coin::burn_for_testing(amount_coin2_out);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 + exact_amount_coin1_in
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 - expected_amount_coin2_out
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_swap_exact_a_for_b_success_low_slippage() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 500000;
        let amount_coin2_1 = 500000;
        let expected_lp_coin_amount_1 = 500000 - 1000;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 500000;
        let amount_coin2_2 = 500000;
        let expected_lp_coin_amount_2 = 500000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin1_in = 1000;
        let expected_amount_coin2_out = 1000;
        let minimum_amount_coin2_out = 990;
        {
            let coin_1_in = coin::mint_for_testing<COIN1>(exact_amount_coin1_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let amount_coin2_out = swap_exact_a_for_b<COIN1, COIN2>(
                coin_1_in,
                &mut lp_pool,
                minimum_amount_coin2_out,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&amount_coin2_out),
                expected_amount_coin2_out
            );

            coin::burn_for_testing(amount_coin2_out);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 + exact_amount_coin1_in
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 - expected_amount_coin2_out
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = ESlippageLimitExceeded)]
    fun test_swap_exact_a_for_b_failure_too_high_slippage() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin1_in = 1000;
        let expected_amount_coin2_out = 667;
        let minimum_amount_coin2_out = 950;
        {
            let coin_1_in = coin::mint_for_testing<COIN1>(exact_amount_coin1_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let amount_coin2_out = swap_exact_a_for_b<COIN1, COIN2>(
                coin_1_in,
                &mut lp_pool,
                minimum_amount_coin2_out,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&amount_coin2_out),
                expected_amount_coin2_out
            );

            coin::burn_for_testing(amount_coin2_out);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 + exact_amount_coin1_in
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 - expected_amount_coin2_out
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EInvalidSwapParameters)]
    fun test_swap_exact_a_for_b_failure_zero_a() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin1_in = 0;
        let expected_amount_coin2_out = 0;
        let minimum_amount_coin2_out = 0;
        {
            let coin_1_in = coin::mint_for_testing<COIN1>(exact_amount_coin1_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let amount_coin2_out = swap_exact_a_for_b<COIN1, COIN2>(
                coin_1_in,
                &mut lp_pool,
                minimum_amount_coin2_out,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&amount_coin2_out),
                expected_amount_coin2_out
            );

            coin::burn_for_testing(amount_coin2_out);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 + exact_amount_coin1_in
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 - expected_amount_coin2_out
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_swap_exact_b_for_a_success_high_slippage() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin2_in = 500;
        let expected_amount_coin1_out = 400;
        let minimum_amount_coin1_out = 400;
        {
            let coin_2_in = coin::mint_for_testing<COIN2>(exact_amount_coin2_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let amount_coin1_out = swap_exact_b_for_a<COIN1, COIN2>(
                coin_2_in,
                &mut lp_pool,
                minimum_amount_coin1_out,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&amount_coin1_out),
                expected_amount_coin1_out
            );

            coin::burn_for_testing(amount_coin1_out);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 - expected_amount_coin1_out
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 + exact_amount_coin2_in
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_swap_exact_b_for_a_success_low_slippage() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 5000000;
        let amount_coin2_1 = 5000000;
        let expected_lp_coin_amount_1 = 5000000 - 1000;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 5000000;
        let amount_coin2_2 = 5000000;
        let expected_lp_coin_amount_2 = 5000000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin2_in = 500;
        let expected_amount_coin1_out = 500;
        let minimum_amount_coin1_out = 490;
        {
            let coin_2_in = coin::mint_for_testing<COIN2>(exact_amount_coin2_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let amount_coin1_out = swap_exact_b_for_a<COIN1, COIN2>(
                coin_2_in,
                &mut lp_pool,
                minimum_amount_coin1_out,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&amount_coin1_out),
                expected_amount_coin1_out
            );

            coin::burn_for_testing(amount_coin1_out);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 - expected_amount_coin1_out
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 + exact_amount_coin2_in
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = ESlippageLimitExceeded)]
    fun test_swap_exact_b_for_a_failure_too_high_slippage() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin2_in = 500;
        let expected_amount_coin1_out = 400;
        let minimum_amount_coin1_out = 450;
        {
            let coin_2_in = coin::mint_for_testing<COIN2>(exact_amount_coin2_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let amount_coin1_out = swap_exact_b_for_a<COIN1, COIN2>(
                coin_2_in,
                &mut lp_pool,
                minimum_amount_coin1_out,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&amount_coin1_out),
                expected_amount_coin1_out
            );

            coin::burn_for_testing(amount_coin1_out);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 - expected_amount_coin1_out
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 + exact_amount_coin2_in
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EInvalidSwapParameters)]
    fun test_swap_exact_b_for_a_failure_zero_b() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 5000000;
        let amount_coin2_1 = 5000000;
        let expected_lp_coin_amount_1 = 5000000 - 1000;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 5000000;
        let amount_coin2_2 = 5000000;
        let expected_lp_coin_amount_2 = 5000000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin2_in = 0;
        let expected_amount_coin1_out = 0;
        let minimum_amount_coin1_out = 0;
        {
            let coin_2_in = coin::mint_for_testing<COIN2>(exact_amount_coin2_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let amount_coin1_out = swap_exact_b_for_a<COIN1, COIN2>(
                coin_2_in,
                &mut lp_pool,
                minimum_amount_coin1_out,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&amount_coin1_out),
                expected_amount_coin1_out
            );

            coin::burn_for_testing(amount_coin1_out);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 - expected_amount_coin1_out
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 + exact_amount_coin2_in
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_swap_a_for_exact_b_success_high_slippage() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin2_out = 800;
        let amount_coin1_in = 1500;
        let expected_amount_coin1_in = 1333;
        let maximum_amount_coin1_in = 1500;
        {
            let coin_1_in = coin::mint_for_testing<COIN1>(maximum_amount_coin1_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let coin_b_out = swap_a_for_exact_b<COIN1, COIN2>(
                &mut coin_1_in,
                exact_amount_coin2_out,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );
    
            assert_eq(
                coin::value(&coin_b_out),
                exact_amount_coin2_out
            );

            coin::burn_for_testing(coin_b_out);

            assert_eq(
                coin::value(&coin_1_in),
                amount_coin1_in - expected_amount_coin1_in
            );

            coin::burn_for_testing(coin_1_in);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 + expected_amount_coin1_in
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 - exact_amount_coin2_out
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }
    
    #[test]
    fun test_swap_a_for_exact_b_success_low_slippage() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 500000;
        let amount_coin2_1 = 500000;
        let expected_lp_coin_amount_1 = 500000 - 1000;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 5000000;
        let amount_coin2_2 = 5000000;
        let expected_lp_coin_amount_2 = 5000000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin2_out = 800;
        let amount_coin1_in = 800;
        let expected_amount_coin1_in = 800;
        let maximum_amount_coin1_in = 800;
        {
            let coin_1_in = coin::mint_for_testing<COIN1>(maximum_amount_coin1_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let coin_b_out = swap_a_for_exact_b<COIN1, COIN2>(
                &mut coin_1_in,
                exact_amount_coin2_out,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );
    
            assert_eq(
                coin::value(&coin_b_out),
                exact_amount_coin2_out
            );

            coin::burn_for_testing(coin_b_out);

            assert_eq(
                coin::value(&coin_1_in),
                amount_coin1_in - expected_amount_coin1_in
            );

            coin::burn_for_testing(coin_1_in);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 + expected_amount_coin1_in
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 - exact_amount_coin2_out
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = ESlippageLimitExceeded)]
    fun test_swap_a_for_exact_b_failure_too_high_slippage() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin2_out = 800;
        let amount_coin1_in = 1200;
        let expected_amount_coin1_in = 1333;
        let maximum_amount_coin1_in = 1200;
        {
            let coin_1_in = coin::mint_for_testing<COIN1>(maximum_amount_coin1_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let coin_b_out = swap_a_for_exact_b<COIN1, COIN2>(
                &mut coin_1_in,
                exact_amount_coin2_out,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );
    
            assert_eq(
                coin::value(&coin_b_out),
                exact_amount_coin2_out
            );

            coin::burn_for_testing(coin_b_out);

            assert_eq(
                coin::value(&coin_1_in),
                amount_coin1_in - expected_amount_coin1_in
            );

            coin::burn_for_testing(coin_1_in);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 + expected_amount_coin1_in
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 - exact_amount_coin2_out
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EInvalidSwapParameters)]
    fun test_swap_a_for_exact_b_failure_zero_b() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 500000;
        let amount_coin2_1 = 500000;
        let expected_lp_coin_amount_1 = 500000 - 1000;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 5000000;
        let amount_coin2_2 = 5000000;
        let expected_lp_coin_amount_2 = 5000000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin2_out = 0;
        let amount_coin1_in = 900;
        let expected_amount_coin1_in = 900;
        let maximum_amount_coin1_in = 900;
        {
            let coin_1_in = coin::mint_for_testing<COIN1>(maximum_amount_coin1_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let coin_b_out = swap_a_for_exact_b<COIN1, COIN2>(
                &mut coin_1_in,
                exact_amount_coin2_out,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );
    
            assert_eq(
                coin::value(&coin_b_out),
                exact_amount_coin2_out
            );

            coin::burn_for_testing(coin_b_out);

            assert_eq(
                coin::value(&coin_1_in),
                amount_coin1_in - expected_amount_coin1_in
            );

            coin::burn_for_testing(coin_1_in);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 + expected_amount_coin1_in
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 - exact_amount_coin2_out
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EInvalidSwapParameters)]
    fun test_swap_a_for_exact_b_failure_zero_a() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 500000;
        let amount_coin2_1 = 500000;
        let expected_lp_coin_amount_1 = 500000 - 1000;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 5000000;
        let amount_coin2_2 = 5000000;
        let expected_lp_coin_amount_2 = 5000000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin2_out = 500;
        let amount_coin1_in = 0;
        let expected_amount_coin1_in = 0;
        let maximum_amount_coin1_in = 0;
        {
            let coin_1_in = coin::mint_for_testing<COIN1>(maximum_amount_coin1_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let coin_b_out = swap_a_for_exact_b<COIN1, COIN2>(
                &mut coin_1_in,
                exact_amount_coin2_out,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );
    
            assert_eq(
                coin::value(&coin_b_out),
                exact_amount_coin2_out
            );

            coin::burn_for_testing(coin_b_out);

            assert_eq(
                coin::value(&coin_1_in),
                amount_coin1_in - expected_amount_coin1_in
            );

            coin::burn_for_testing(coin_1_in);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 + expected_amount_coin1_in
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 - exact_amount_coin2_out
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_swap_b_for_exact_a_success_high_slippage() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin1_out = 400;
        let amount_coin2_in = 500;
        let expected_amount_coin2_in = 500;
        let maximum_amount_coin2_in = 500;
        {
            let coin_2_in = coin::mint_for_testing<COIN2>(maximum_amount_coin2_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let coin_a_out = swap_b_for_exact_a<COIN1, COIN2>(
                &mut coin_2_in,
                exact_amount_coin1_out,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );
    
            assert_eq(
                coin::value(&coin_a_out),
                exact_amount_coin1_out
            );

            coin::burn_for_testing(coin_a_out);

            assert_eq(
                coin::value(&coin_2_in),
                amount_coin2_in - expected_amount_coin2_in
            );

            coin::burn_for_testing(coin_2_in);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 - exact_amount_coin1_out
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 + expected_amount_coin2_in
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_swap_b_for_exact_a_success_low_slippage() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 5000000;
        let amount_coin2_1 = 5000000;
        let expected_lp_coin_amount_1 = 5000000 - 1000;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 5000000;
        let amount_coin2_2 = 5000000;
        let expected_lp_coin_amount_2 = 5000000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin1_out = 900;
        let amount_coin2_in = 900;
        let expected_amount_coin2_in = 900;
        let maximum_amount_coin2_in = 900;
        {
            let coin_2_in = coin::mint_for_testing<COIN2>(maximum_amount_coin2_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let coin_a_out = swap_b_for_exact_a<COIN1, COIN2>(
                &mut coin_2_in,
                exact_amount_coin1_out,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );
    
            assert_eq(
                coin::value(&coin_a_out),
                exact_amount_coin1_out
            );

            coin::burn_for_testing(coin_a_out);

            assert_eq(
                coin::value(&coin_2_in),
                amount_coin2_in - expected_amount_coin2_in
            );

            coin::burn_for_testing(coin_2_in);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 - exact_amount_coin1_out
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 + expected_amount_coin2_in
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = ESlippageLimitExceeded)]
    fun test_swap_b_for_exact_a_failure_too_high_slippage() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 1000;
        let amount_coin2_1 = 1000;
        let expected_lp_coin_amount_1 = 0;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 1000;
        let amount_coin2_2 = 1000;
        let expected_lp_coin_amount_2 = 1000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin1_out = 400;
        let amount_coin2_in = 450;
        let expected_amount_coin2_in = 500;
        let maximum_amount_coin2_in = 450;
        {
            let coin_2_in = coin::mint_for_testing<COIN2>(maximum_amount_coin2_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let coin_a_out = swap_b_for_exact_a<COIN1, COIN2>(
                &mut coin_2_in,
                exact_amount_coin1_out,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );
    
            assert_eq(
                coin::value(&coin_a_out),
                exact_amount_coin1_out
            );

            coin::burn_for_testing(coin_a_out);

            assert_eq(
                coin::value(&coin_2_in),
                amount_coin2_in - expected_amount_coin2_in
            );

            coin::burn_for_testing(coin_2_in);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 - exact_amount_coin1_out
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 + expected_amount_coin2_in
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EInvalidSwapParameters)]
    fun test_swap_b_for_exact_a_failure_zero_a() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 5000000;
        let amount_coin2_1 = 5000000;
        let expected_lp_coin_amount_1 = 5000000 - 1000;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 5000000;
        let amount_coin2_2 = 5000000;
        let expected_lp_coin_amount_2 = 5000000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin1_out = 0;
        let amount_coin2_in = 900;
        let expected_amount_coin2_in = 900;
        let maximum_amount_coin2_in = 900;
        {
            let coin_2_in = coin::mint_for_testing<COIN2>(maximum_amount_coin2_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let coin_a_out = swap_b_for_exact_a<COIN1, COIN2>(
                &mut coin_2_in,
                exact_amount_coin1_out,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );
    
            assert_eq(
                coin::value(&coin_a_out),
                exact_amount_coin1_out
            );

            coin::burn_for_testing(coin_a_out);

            assert_eq(
                coin::value(&coin_2_in),
                amount_coin2_in - expected_amount_coin2_in
            );

            coin::burn_for_testing(coin_2_in);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 - exact_amount_coin1_out
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 + expected_amount_coin2_in
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EInvalidSwapParameters)]
    fun test_swap_b_for_exact_a_failure_zero_b() {
        let creator = @0xa;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;

        let amount_coin1_1 = 5000000;
        let amount_coin2_1 = 5000000;
        let expected_lp_coin_amount_1 = 5000000 - 1000;
        {

            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_1, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_1, test_scenario::ctx(scenario));

            let lp_coin = create_liquidity_pool<COIN1, COIN2>(
                coin_1,
                coin_2,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_1
            );

            coin::burn_for_testing(lp_coin);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let amount_coin1_2 = 5000000;
        let amount_coin2_2 = 5000000;
        let expected_lp_coin_amount_2 = 5000000;
        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);
                
            let coin_1 = coin::mint_for_testing<COIN1>(amount_coin1_2, test_scenario::ctx(scenario));
            let coin_2 = coin::mint_for_testing<COIN2>(amount_coin2_2, test_scenario::ctx(scenario));

            let lp_coin = supply_liquidity<COIN1, COIN2>(
                coin_1,
                coin_2,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );

            assert_eq(
                coin::value(&lp_coin),
                expected_lp_coin_amount_2
            );

            coin::burn_for_testing(lp_coin);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        let exact_amount_coin1_out = 900;
        let amount_coin2_in = 0;
        let expected_amount_coin2_in = 0;
        let maximum_amount_coin2_in = 0;
        {
            let coin_2_in = coin::mint_for_testing<COIN2>(maximum_amount_coin2_in, test_scenario::ctx(scenario));

            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            let coin_a_out = swap_b_for_exact_a<COIN1, COIN2>(
                &mut coin_2_in,
                exact_amount_coin1_out,
                &mut lp_pool,
                test_scenario::ctx(scenario)
            );
    
            assert_eq(
                coin::value(&coin_a_out),
                exact_amount_coin1_out
            );

            coin::burn_for_testing(coin_a_out);

            assert_eq(
                coin::value(&coin_2_in),
                amount_coin2_in - expected_amount_coin2_in
            );

            coin::burn_for_testing(coin_2_in);

            test_scenario::return_shared(lp_pool);
        };
        let tx = test_scenario::next_tx(scenario, creator);
        let expected_events_emitted = 0;
        let expected_created_objects = 0;
        let expected_deleted_objects = 0;
        assert_eq(
            test_scenario::num_user_events(&tx),
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::deleted(&tx)),
            expected_deleted_objects
        );

        {
            let lp_pool = test_scenario::take_shared<LiquidityPool<COIN1, COIN2>>(scenario);

            assert_eq(
                balance::supply_value(&lp_pool.lp_coin_supply),
                expected_lp_coin_amount_1 + expected_lp_coin_amount_2 + 1000
            );
            assert_eq(
                balance::value(&lp_pool.coin_a_balance),
                amount_coin1_1 + amount_coin1_2 - exact_amount_coin1_out
            );
            assert_eq(
                balance::value(&lp_pool.coin_b_balance),
                amount_coin2_1 + amount_coin2_2 + expected_amount_coin2_in
            );
            assert_eq(
                balance::value(&lp_pool.initial_lp_coin_reserve),
                1000
            );

            test_scenario::return_shared(lp_pool);
        };
        test_scenario::end(scenario_val);
    }
}