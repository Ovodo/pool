/* 
    This quest features a simple payment streaming module. The module allows a sender to create a 
    stream to a receiver. A stream is a payment that is sent to the receiver that the receiver can 
    claim over time. Instead of receiving the full payment at once or being restricted to fixed 
    installments, the receiver can claim the pending payments at any time. The sender can close the
    stream at any time, which will send the claimed amount to the receiver and the unclaimed amount
    to the sender.

    Creating a stream
        Anyone can create a stream to anyone else with any coin. The sender specifies the receiver,
        the payment, and the duration of the stream. The duration is specified in seconds. The 
        receiver can start claiming the stream immediately after it is created. 

    Claiming a stream
        The receiver can claim the stream at any time. The amount claimed is calculated based on the
        time since the last claim. If the stream duration has passed, the receiver will receive the 
        full amount and the stream will be closed (deleted).

    Closing a stream
        The receiver can close the stream at any time. The amount to send to the receiver and the 
        amount of to send back to the sender is calculated based on the time since the last claim.
        If the stream duration has passed, the receiver will receive the full amount and the sender
        will receive nothing. When a stream is closed, it should be deleted.
*/
module overmind::streams {
    //==============================================================================================
    // Dependencies
    //==============================================================================================
    use sui::event;
    use std::vector;
    use std::debug;
    use sui::sui::SUI;
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
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
    const ESenderCannotBeReceiver: u64 = 0;
    const EPaymentMustBeGreaterThanZero: u64 = 1;
    const EDurationMustBeGreaterThanZero: u64 = 2;

    //==============================================================================================
    // Module structs - DO NOT MODIFY
    //==============================================================================================

    /* 
        A stream is a payment where the receiver can claim the payment over time. The stream has the 
        following properties:
            - id: The unique id of the stream.
            - sender: The address of the sender.
            - duration_in_seconds: The duration of the stream in seconds.
            - last_timestamp_claimed_seconds: The timestamp of the last claim.
            - amount: The amount of the stream.
    */
    struct Stream<phantom PaymentCoin> has key {
        id: UID, 
        sender: address, 
        duration_in_seconds: u64,
        last_timestamp_claimed_seconds: u64,
        amount: Balance<PaymentCoin>,
    }

    //==============================================================================================
    // Event structs - DO NOT MODIFY
    //==============================================================================================

    /* 
        Event emitted when a stream is created. 
            - stream_id: The id of the stream.
            - sender: The address of the sender.
            - receiver: The address of the receiver.
            - duration_in_seconds: The duration of the stream in seconds.
            - amount: The amount of the stream.
    */
    struct StreamCreatedEvent has copy, drop {
        stream_id: ID, 
        sender: address, 
        receiver: address, 
        duration_in_seconds: u64, 
        amount: u64
    }

    /* 
        Event emitted when a stream is claimed. 
            - stream_id: The id of the stream.
            - receiver: The address of the receiver.
            - amount: The amount claimed.
    */
    struct StreamClaimedEvent has copy, drop {
        stream_id: ID, 
        receiver: address, 
        amount: u64
    }

    /* 
        Event emitted when a stream is closed. 
            - stream_id: The id of the stream.
            - receiver: The address of the receiver.
            - sender: The address of the sender.
            - amount_to_receiver: The amount claimed by the receiver.
            - amount_to_sender: The amount claimed by the sender.
    */
    struct StreamClosedEvent has copy, drop {
        stream_id: ID, 
        receiver: address, 
        sender: address, 
        amount_to_receiver: u64,
        amount_to_sender: u64
    }

    //==============================================================================================
    // Functions
    //==============================================================================================

    /* 
        Creates a new stream from the sender and sends it to the receiver. Abort if the sender is 
        the same as the receiver, if the payment is zero, or if the duration is zero. 
        @type-param PaymentCoin: The type of coin to use for the payment.
        @param receiver: The address of the receiver.
        @param payment: The payment to be streamed.
        @param duration_in_seconds: The duration of the stream in seconds.
        @param clock: The clock to use for the stream.
        @param ctx: The transaction context.
    */
	public fun create_stream<PaymentCoin>(
        receiver: address, 
        payment: Coin<PaymentCoin>,
        duration_in_seconds: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&payment);
        assert!(tx_context::sender(ctx) != receiver,ESenderCannotBeReceiver );
        assert!(duration_in_seconds > 0,EDurationMustBeGreaterThanZero);
        assert!( amount!= 0,EPaymentMustBeGreaterThanZero);
        let time = ((clock::timestamp_ms(clock))/1000);
        
        let stream = Stream {
            id:object::new(ctx),
            sender:tx_context::sender(ctx),
            duration_in_seconds,
            amount:coin::into_balance(payment),
            last_timestamp_claimed_seconds:time
        };

        event::emit(StreamCreatedEvent{
            stream_id:object::uid_to_inner(&stream.id),
            sender:tx_context::sender(ctx),
            receiver,
            amount:amount,
            duration_in_seconds
        });
        transfer::transfer(stream,receiver);
        
        
    }

    /* 
        Claims the stream. If the stream is still active, the amount claimed is calculated based on 
        the time since the last claim. If the stream is closed, the remaining amount is claimed. The
        claimed amount is sent to the receiver.  
        @type-param PaymentCoin: The type of coin to use for the payment.
        @param stream: The stream to claim.
        @param clock: The clock to use for the stream.
        @param ctx: The transaction context.
        @return: The coin claimed.
    */
    public fun claim_stream<PaymentCoin>(
        stream: Stream<PaymentCoin>, 
        clock: &Clock, 
        ctx: &mut TxContext
    ): Coin<PaymentCoin> {
            let now = ((clock::timestamp_ms(clock))/1000);
            let time_elapsed = now - stream.last_timestamp_claimed_seconds;

            

            if (time_elapsed >= stream.duration_in_seconds)
             {
                // Stream duration has passed, close the stream
                event::emit(StreamClosedEvent{
                    stream_id: object::uid_to_inner(&stream.id),
                    receiver: tx_context::sender(ctx),
                    sender:stream.sender,
                    amount_to_receiver: balance::value(&stream.amount),
                    amount_to_sender: 0
                });
                let Stream {id,amount:amount,sender:_,duration_in_seconds:_,last_timestamp_claimed_seconds:_} = stream;
                let coin = coin::from_balance(amount,ctx);
                object::delete(id);
                return coin
            };

            let claimed_amount = (time_elapsed * balance::value(&stream.amount) / stream.duration_in_seconds);
            event::emit(StreamClaimedEvent{
                stream_id: object::uid_to_inner(&stream.id),
                receiver: tx_context::sender(ctx),
                amount: claimed_amount
            });
            stream.last_timestamp_claimed_seconds = now;
            let duration = stream.duration_in_seconds;
            stream.duration_in_seconds = duration - time_elapsed;
            let coin = coin::from_balance(balance::split(&mut stream.amount, claimed_amount),ctx);
            transfer::transfer(stream, tx_context::sender(ctx));
            coin
        
    }

    /* 
        Closes the stream. If the stream is still active, the amount claimed is calculated based on 
        the time since the last claim. If the stream is closed, the remaining amount is claimed. The
        claimed amount is sent to the receiver. The remaining amount is sent to the sender of the 
        stream.
        @type-param PaymentCoin: The type of coin to use for the payment.
        @param stream: The stream to close.
        @param clock: The clock to use for the stream.
        @param ctx: The transaction context.
        @return: The coin claimed.
    */
    public fun close_stream<PaymentCoin>(
        stream: Stream<PaymentCoin>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<PaymentCoin> {

            let now = ((clock::timestamp_ms(clock))/1000);
            let time_elapsed = now - stream.last_timestamp_claimed_seconds;
            let claimed_amount = (time_elapsed * balance::value(&stream.amount) / stream.duration_in_seconds);


            stream.last_timestamp_claimed_seconds = now;

            if (time_elapsed >= stream.duration_in_seconds ){
                // Stream duration has passed, close the stream
                event::emit(StreamClosedEvent{
                    stream_id: object::uid_to_inner(&stream.id),
                    receiver: tx_context::sender(ctx),
                    sender: stream.sender,
                    amount_to_receiver: balance::value(&stream.amount),
                    amount_to_sender: 0
                });
                let Stream {id,amount,sender:_,duration_in_seconds:_,last_timestamp_claimed_seconds:_} = stream;
                let coin2 = coin::from_balance(amount,ctx);
                object::delete(id);
                return coin2
            };
            let amount_to_receiver = balance::value(&stream.amount) - claimed_amount;
            let amount_to_sender = claimed_amount;
            event::emit(StreamClosedEvent{
                stream_id: object::uid_to_inner(&stream.id),
                receiver: stream.sender,
                sender: stream.sender,
                amount_to_receiver,
                amount_to_sender
            });

            let Stream {id,amount,sender:sender,duration_in_seconds:_,last_timestamp_claimed_seconds:_} = stream;
            let coin = coin::from_balance(balance::split(&mut amount, claimed_amount),ctx);
            let coin2 = coin::from_balance(amount,ctx);
            transfer::public_transfer(coin2, sender);
            

            object::delete(id);
            return coin

        
    }

    //==============================================================================================
    // Helper functions - Add your helper functions here (if any)
    //==============================================================================================

    //==============================================================================================
    // Validation functions - Add your validation functions here (if any)
    //==============================================================================================

    //==============================================================================================
    // Tests - DO NOT MODIFY
    //==============================================================================================
    
    #[test]
    fun test_create_stream_success_one_sui_stream() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        assert_eq(
            test_scenario::num_user_events(&tx), 
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );

        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                stream.sender, 
                stream_creator
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration
            );
            assert_eq(
                balance::value(&stream.amount), 
                stream_amount
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_create_stream_success_many_sui_streams() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        assert_eq(
            test_scenario::num_user_events(&tx), 
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );

        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                stream.sender, 
                stream_creator
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration
            );
            assert_eq(
                balance::value(&stream.amount), 
                stream_amount
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };

        let stream_amount = 100000000;
        let stream_duration = 100000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        assert_eq(
            test_scenario::num_user_events(&tx), 
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );

        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                stream.sender, 
                stream_creator
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration
            );
            assert_eq(
                balance::value(&stream.amount), 
                stream_amount
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };

        let stream_amount = 1;
        let stream_duration = 1;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        assert_eq(
            test_scenario::num_user_events(&tx), 
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );

        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                stream.sender, 
                stream_creator
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration
            );
            assert_eq(
                balance::value(&stream.amount), 
                stream_amount
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };

        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = ESenderCannotBeReceiver)]
    fun test_create_stream_failure_sender_is_receiver() {
        let stream_creator = @0xa;
        let stream_receiver = stream_creator;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        assert_eq(
            test_scenario::num_user_events(&tx), 
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );

        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                stream.sender, 
                stream_creator
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration
            );
            assert_eq(
                balance::value(&stream.amount), 
                stream_amount
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };

        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EPaymentMustBeGreaterThanZero)]
    fun test_create_stream_failure_zero_coin() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 0;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        assert_eq(
            test_scenario::num_user_events(&tx), 
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );

        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                stream.sender, 
                stream_creator
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration
            );
            assert_eq(
                balance::value(&stream.amount), 
                stream_amount
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };

        test_scenario::end(scenario_val);
    }

    #[test, expected_failure(abort_code = EDurationMustBeGreaterThanZero)]
    fun test_create_stream_failure_zero_duration() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10;
        let stream_duration = 0;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        assert_eq(
            test_scenario::num_user_events(&tx), 
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );

        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                stream.sender, 
                stream_creator
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration
            );
            assert_eq(
                balance::value(&stream.amount), 
                stream_amount
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_claim_stream_success_claim_0_percent() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward = 0;
        let expected_claim_amount = 0;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward);

            let claimed_coin = claim_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);

            assert_eq(
                coin::value(&claimed_coin), 
                expected_claim_amount
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_receiver);
        let expected_events_emitted = 1;
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
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                balance::value(&stream.amount), 
                stream_amount - expected_claim_amount
            );
            assert_eq(
                stream.last_timestamp_claimed_seconds, 
                time_forward
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration - time_forward
            );
            assert_eq(
                stream.sender, 
                stream_creator
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };
        test_scenario::end(scenario_val);

    }

    #[test]
    fun test_claim_stream_success_claim_10_percent() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds = stream_duration / 10;
        let expected_claim_amount = stream_amount / 10;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds * 1000);

            let claimed_coin = claim_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);

            assert_eq(
                coin::value(&claimed_coin), 
                expected_claim_amount
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_receiver);
        let expected_events_emitted = 1;
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
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                balance::value(&stream.amount), 
                stream_amount - expected_claim_amount
            );
            assert_eq(
                stream.last_timestamp_claimed_seconds, 
                time_forward_seconds
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration - time_forward_seconds
            );
            assert_eq(
                stream.sender, 
                stream_creator
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };
        test_scenario::end(scenario_val);

    }

    #[test]
    fun test_claim_stream_success_claim_50_percent() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds = stream_duration / 2;
        let expected_claim_amount = stream_amount / 2;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds * 1000);

            let claimed_coin = claim_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);

            assert_eq(
                coin::value(&claimed_coin), 
                expected_claim_amount
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_receiver);
        let expected_events_emitted = 1;
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
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                balance::value(&stream.amount), 
                stream_amount - expected_claim_amount
            );
            assert_eq(
                stream.last_timestamp_claimed_seconds, 
                time_forward_seconds
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration - time_forward_seconds
            );
            assert_eq(
                stream.sender, 
                stream_creator
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };
        test_scenario::end(scenario_val);

    }

    #[test]
    fun test_claim_stream_success_claim_75_percent() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds = stream_duration * 3 / 4;
        let expected_claim_amount = stream_amount * 3 / 4;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds * 1000);

            let claimed_coin = claim_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);

            assert_eq(
                coin::value(&claimed_coin), 
                expected_claim_amount
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_receiver);
        let expected_events_emitted = 1;
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
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                balance::value(&stream.amount), 
                stream_amount - expected_claim_amount
            );
            assert_eq(
                stream.last_timestamp_claimed_seconds, 
                time_forward_seconds
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration - time_forward_seconds
            );
            assert_eq(
                stream.sender, 
                stream_creator
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };
        test_scenario::end(scenario_val);

    }

    #[test]
    fun test_claim_stream_success_claim_100_percent() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds = stream_duration;
        let expected_claim_amount = stream_amount;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds * 1000);

            let claimed_coin = claim_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);

            assert_eq(
                coin::value(&claimed_coin), 
                expected_claim_amount
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::end(scenario_val);
        let expected_events_emitted = 1;
        let expected_created_objects = 0;
        let expected_deleted_objects = 1;
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
    }

    #[test]
    fun test_claim_stream_success_claim_101_percent() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds = stream_duration * 101 / 100;
        let expected_claim_amount = stream_amount;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds * 1000);

            let claimed_coin = claim_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);

            assert_eq(
                coin::value(&claimed_coin), 
                expected_claim_amount
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::end(scenario_val);
        let expected_events_emitted = 1;
        let expected_created_objects = 0;
        let expected_deleted_objects = 1;
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
    }

    #[test]
    fun test_close_stream_success_claim_25_percent_after_50_claimed() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds_1 = stream_duration / 2;
        let expected_claim_amount_1 = stream_amount / 2;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds_1 * 1000);

            let claimed_coin = claim_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);

            assert_eq(
                coin::value(&claimed_coin), 
                expected_claim_amount_1
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_receiver);
        let expected_events_emitted = 1;
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
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                balance::value(&stream.amount), 
                stream_amount - expected_claim_amount_1
            );
            assert_eq(
                stream.last_timestamp_claimed_seconds, 
                time_forward_seconds_1
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration - time_forward_seconds_1
            );
            assert_eq(
                stream.sender, 
                stream_creator
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds_2 = stream_duration / 4;
        let expected_claim_amount_2 = stream_amount / 4;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds_2 * 1000);

            let claimed_coin = claim_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);

            assert_eq(
                coin::value(&claimed_coin), 
                expected_claim_amount_2
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_receiver);
        let expected_events_emitted = 1;
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
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                balance::value(&stream.amount), 
                stream_amount - expected_claim_amount_1 - expected_claim_amount_2
            );
            assert_eq(
                stream.last_timestamp_claimed_seconds, 
                time_forward_seconds_1 + time_forward_seconds_2
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration - time_forward_seconds_1 - time_forward_seconds_2
            );
            assert_eq(
                stream.sender, 
                stream_creator
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };
        test_scenario::end(scenario_val);


        
    }

    #[test]
    fun test_close_stream_success_close_at_0_percent() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;

        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);
            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds = 0;
        let expected_amount_to_sender = stream_amount;
        let expected_amount_to_receiver = 0;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds * 1000);
            let claimed_coin = close_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(clock);
            assert_eq(
                coin::value(&claimed_coin), 
                expected_amount_to_receiver
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        let expected_deleted_objects = 1;
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
            let stream_coin = test_scenario::take_from_address<Coin<SUI>>(scenario, stream_creator);

            assert_eq(
                coin::value(&stream_coin), 
                expected_amount_to_sender
            );

            test_scenario::return_to_address(stream_creator, stream_coin);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_close_stream_success_close_at_10_percent() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;

        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);
            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds = stream_duration / 10;
        let expected_amount_to_sender = stream_amount * 9 / 10;
        let expected_amount_to_receiver = stream_amount / 10;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds * 1000);
            let claimed_coin = close_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(clock);
            assert_eq(
                coin::value(&claimed_coin), 
                expected_amount_to_receiver
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        let expected_deleted_objects = 1;
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
            let stream_coin = test_scenario::take_from_address<Coin<SUI>>(scenario, stream_creator);

            assert_eq(
                coin::value(&stream_coin), 
                expected_amount_to_sender
            );

            test_scenario::return_to_address(stream_creator, stream_coin);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_close_stream_success_close_at_50_percent() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;

        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);
            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds = stream_duration / 2;
        let expected_amount_to_sender = stream_amount / 2;
        let expected_amount_to_receiver = stream_amount / 2;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds * 1000);
            let claimed_coin = close_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(clock);
            assert_eq(
                coin::value(&claimed_coin), 
                expected_amount_to_receiver
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        let expected_deleted_objects = 1;
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
            let stream_coin = test_scenario::take_from_address<Coin<SUI>>(scenario, stream_creator);

            assert_eq(
                coin::value(&stream_coin), 
                expected_amount_to_sender
            );

            test_scenario::return_to_address(stream_creator, stream_coin);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_close_stream_success_close_at_75_percent() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;

        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);
            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds = stream_duration * 3 / 4;
        let expected_amount_to_sender = stream_amount / 4;
        let expected_amount_to_receiver = stream_amount * 3 / 4;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds * 1000);
            let claimed_coin = close_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(clock);
            assert_eq(
                coin::value(&claimed_coin), 
                expected_amount_to_receiver
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        let expected_deleted_objects = 1;
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
            let stream_coin = test_scenario::take_from_address<Coin<SUI>>(scenario, stream_creator);

            assert_eq(
                coin::value(&stream_coin), 
                expected_amount_to_sender
            );

            test_scenario::return_to_address(stream_creator, stream_coin);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_close_stream_success_close_at_100_percent() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;

        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);
            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds = stream_duration;
        let expected_amount_to_receiver = stream_amount;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds * 1000);
            let claimed_coin = close_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(clock);
            assert_eq(
                coin::value(&claimed_coin), 
                expected_amount_to_receiver
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::end(scenario_val);
        let expected_events_emitted = 1;
        let expected_created_objects = 0;
        let expected_deleted_objects = 1;
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
    }

    #[test]
    fun test_close_stream_success_close_at_101_percent() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;

        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);
            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds = stream_duration * 101 / 100;
        let expected_amount_to_receiver = stream_amount;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds * 1000);
            let claimed_coin = close_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(clock);
            assert_eq(
                coin::value(&claimed_coin), 
                expected_amount_to_receiver
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::end(scenario_val);
        let expected_events_emitted = 1;
        let expected_created_objects = 0;
        let expected_deleted_objects = 1;
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
    }

    #[test]
    fun test_close_stream_success_close_0_percent_after_50_claimed() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds_1 = stream_duration / 2;
        let expected_claim_amount_1 = stream_amount / 2;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds_1 * 1000);

            let claimed_coin = claim_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);

            assert_eq(
                coin::value(&claimed_coin), 
                expected_claim_amount_1
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_receiver);
        let expected_events_emitted = 1;
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
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                balance::value(&stream.amount), 
                stream_amount - expected_claim_amount_1
            );
            assert_eq(
                stream.last_timestamp_claimed_seconds, 
                time_forward_seconds_1
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration - time_forward_seconds_1
            );
            assert_eq(
                stream.sender, 
                stream_creator
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds_2 = 0;
        let expected_amount_to_sender = stream_amount / 2;
        let expected_amount_to_receiver = 0;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds_2 * 1000);

            let claimed_coin = close_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);

            assert_eq(
                coin::value(&claimed_coin), 
                expected_amount_to_receiver
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        let expected_deleted_objects = 1;
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
            let coin = test_scenario::take_from_address<Coin<SUI>>(scenario, stream_creator);

            assert_eq(
                coin::value(&coin), 
                expected_amount_to_sender
            );

            test_scenario::return_to_address(stream_creator, coin);
        };
        test_scenario::end(scenario_val);        
    }

    #[test]
    fun test_close_stream_success_close_25_percent_after_50_claimed() {
        let stream_creator = @0xa;
        let stream_receiver = @0xb;

        let scenario_val = test_scenario::begin(stream_creator);
        let scenario = &mut scenario_val;
        {
            clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        };
        test_scenario::next_tx(scenario, stream_creator);

        let stream_amount = 10000000000;
        let stream_duration = 1000;
        {
            let payment_coin = coin::mint_for_testing<SUI>(stream_amount, test_scenario::ctx(scenario));
            let clock = test_scenario::take_shared<Clock>(scenario);

            create_stream<SUI>(
                stream_receiver, 
                payment_coin, 
                stream_duration, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds_1 = stream_duration / 2;
        let expected_claim_amount_1 = stream_amount / 2;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds_1 * 1000);

            let claimed_coin = claim_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);

            assert_eq(
                coin::value(&claimed_coin), 
                expected_claim_amount_1
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_receiver);
        let expected_events_emitted = 1;
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
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);

            assert_eq(
                balance::value(&stream.amount), 
                stream_amount - expected_claim_amount_1
            );
            assert_eq(
                stream.last_timestamp_claimed_seconds, 
                time_forward_seconds_1
            );
            assert_eq(
                stream.duration_in_seconds, 
                stream_duration - time_forward_seconds_1
            );
            assert_eq(
                stream.sender, 
                stream_creator
            );

            test_scenario::return_to_address(stream_receiver, stream);
        };
        test_scenario::next_tx(scenario, stream_receiver);

        let time_forward_seconds_2 = stream_duration / 4;
        let expected_amount_to_sender = stream_amount / 4;
        let expected_amount_to_receiver = stream_amount / 4;
        {
            let stream = test_scenario::take_from_address<Stream<SUI>>(scenario, stream_receiver);
            let clock = test_scenario::take_shared<Clock>(scenario);
            clock::increment_for_testing(&mut clock, time_forward_seconds_2 * 1000);

            let claimed_coin = close_stream<SUI>(
                stream, 
                &clock, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(clock);

            assert_eq(
                coin::value(&claimed_coin), 
                expected_amount_to_receiver
            );
            coin::burn_for_testing(claimed_coin);
        };
        let tx = test_scenario::next_tx(scenario, stream_creator);
        let expected_events_emitted = 1;
        let expected_created_objects = 1;
        let expected_deleted_objects = 1;
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
            let coin = test_scenario::take_from_address<Coin<SUI>>(scenario, stream_creator);

            assert_eq(
                coin::value(&coin), 
                expected_amount_to_sender
            );

            test_scenario::return_to_address(stream_creator, coin);
        };
        test_scenario::end(scenario_val);        
    }
}
