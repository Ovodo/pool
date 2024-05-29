# Payment Stream

This quest features a simple payment streaming module. The module allows a sender to create a 
stream to a receiver. A stream is a payment that is sent to the receiver that the receiver can 
claim over time. Instead of receiving the full payment at once or being restricted to fixed 
installments, the receiver can claim the pending payments at any time. The sender can close the
stream at any time, which will send the claimed amount to the receiver and the unclaimed amount
to the sender.

```move
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
```
