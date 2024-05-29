# Lottery / Jackpot

This quest features a NFT lottery where users can create their own lotteries with an NFT as the 
prize. Each Lottery is a shared object in which the creator receives a `WithdrawalCapability` 
which can be used to withdraw the ticket sales once the lottery has been run and a winner has 
been announced.

```move
module overmind::nft_lottery {
    //==============================================================================================
    // Dependencies - DO NOT MODIFY
    //==============================================================================================
    use sui::event;
    use sui::sui::SUI;
    use sui::transfer::{Self};
    use sui::object::{Self, UID, ID};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::tx_context::TxContext;
    use std::option::{Self, Option};
    use sui::vec_set::{Self, VecSet};
    use sui::balance::{Self, Balance};
    
    
    //==============================================================================================
    // Constants - Add your constants here (if any)
    //==============================================================================================

    //==============================================================================================
    // Error codes - DO NOT MODIFY
    //==============================================================================================
    /// No LotteryCapability
    const ENoWithdrawalCapability: u64 = 1;
    /// Invalid range
    const EInvalidRange: u64 = 2;
    /// In the past
    const EStartOrEndTimeInThePast: u64 = 3;
    /// Lottery has already run
    const ELotteryHasAlreadyRun: u64 = 4;
    /// Insufficient funds
    const EInsufficientFunds: u64 = 5;
    /// Ticket Already Gone
    const ETicketAlreadyGone: u64 = 6;
    /// No prize available
    const ENoPrizeAvailable: u64 = 7;
    /// Not winning number
    const ENotWinningNumber: u64 = 8;
    /// Ticket Not Available
    const ETicketNotAvailable: u64 = 9;
    /// Not withing conditions to abort
    const ENotCancelled: u64 = 10;
    /// Invalid number of participants
    const EInvalidNumberOfParticipants: u64 = 11;
    /// Ticket not found
    const ETicketNotFound: u64 = 12;
    /// Lottery cancelled
    const ELotteryCancelled: u64 = 13;
    /// Lottery has no winning number
    const ELotteryHasNoWinningNumber: u64 = 14;
    /// Invalid lottery
    const EInvalidLottery: u64 = 15;

    //==============================================================================================
    // Module Structs - DO NOT MODIFY
    //==============================================================================================

    /*
        The `Lottery` represents a lottery to be run.  A `Lottery` is a Sui shared object which can be created
        by anyone and the prize is an NFT which is moved to the Lottery shared object.  
        The creator would receive a `LotteryWithdrawal` object that would give them the capability to
        make a withdrawal from the Lottery when it has completed.
        @param id - The object id of the Lottery object.
        @param nft - The NFT as a prize for the lottery, this will `none` when the prize has been won.
        @param participants - The minimum required number of participants for the Lottery. The 
        minimum is 1.
        @param price - The price per ticket of the lottery
        @param balance - The balance available from the sale of tickets
        @param range - The upper limit for the lottery numbers. The minimum range is 1000.
        @param winning_number - The winning number for the lottery. This will be `none` until the lottery has been run.
        @param start_time - The time in ms since Epoch for when the lottery would accept purchase of tickets
        @param end_time - The time in ms since Epoch when the lottery will end
        @param tickets - A set of ticket numbers that have been bought
        @param cancelled - If the lottery has been cancelled
    */
    struct Lottery<T: key + store> has key {
        id: UID,
        nft: Option<T>,
        participants: u64, 
        price: u64,
        balance: Balance<SUI>,
        range: u64,
        winning_number: Option<u64>,
        start_time: u64,
        end_time: u64,
        tickets: VecSet<u64>,
        cancelled: bool,
    }

    /*
        The withdrawal capability struct represents the capability to withdrawal funds from a Lottery. This is 
        created and transferred to the creator of the lottery.
        @param id - The object id of the withdrawal capability object.
        @param lottery - The id of the Lottery object.
    */
    struct WithdrawalCapability has key {
        id: UID,
        lottery: ID, 
    }

    /*
        The lottery ticket bought by a player
        @param id - The object id of the withdrawal capability object.
        @param lottery - The id of the Lottery object.
        @param ticket_number - The ticket number bought
    */
    struct LotteryTicket has key {
        id: UID,
        lottery: ID,
        ticket_number: u64,
    }

    //==============================================================================================
    // Event structs - DO NOT MODIFY
    //==============================================================================================

    /*
        Event emitted when a Lottery is created.
        @param lottery - The id of the Lottery object.
    */
    struct LotteryCreated has copy, drop {
        lottery: ID,
    }

    /*
        Event emitted when a withdrawal is made from the Lottery
        @param lottery_id - The id of the Lottery object.
        @param amount - The amount withdrawn in MIST
        @param recipient - The recipient of the withdrawal
    */
    struct LotteryWithdrawal has copy, drop {
        lottery: ID,
        amount: u64,
        recipient: address,
    }

    /*
        Event emitted a ticket is bought for the lottery
        @param ticket_number - The ticket number bought
        @param lottery_id - The id of the Lottery object.
    */
    struct LotteryTicketBought has copy, drop {
        ticket_number: u64,
        lottery: ID,
    }

    /*
        Event emitted when there is a winner for the lottery
        @param winning_number - The winning number
        @param lottery_id - The id of the Lottery object.
    */
    struct LotteryWinner has copy, drop {
        winning_number: u64,
        lottery: ID,
    }

    //==============================================================================================
    // Functions
    //==============================================================================================

    /*
        Create a Lottery for the given NFT and recipient. Abort if the number of participants is 
        less than the minimum participant number, the range is less than the minimum range, the 
        start time is in the past, or the end time is before the start time. 
        @param nft - NFT prize for the lottery created
        @param participants - Minimum number of participants
        @param price - Price per ticket in lottery
        @param range - Upper limit for lottery numbers
        @param clock - Clock object
        @param start_time - Start time for lottery
        @param end_time - End time for lottery
        @param recipient - Address of recipient of WithdrawalCapability object minted
        @param ctx - Transaction context.
	*/
    public fun create<T: key + store>(
        nft: T, 
        participants: u64, 
        price: u64, 
        range: u64, 
        clock: &Clock, 
        start_time: u64, 
        end_time: u64, 
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(participants >= 1,EInvalidNumberOfParticipants);
        assert!(range > 100,EInvalidRange);
        assert!(start_time < end_time,EStartOrEndTimeInThePast);
        assert!(start_time >= clock::timestamp_ms(clock),EStartOrEndTimeInThePast);

        let lottery = Lottery {
            id: object::new(ctx),
            nft: option::some(nft),
            participants,
            price,
            balance: balance::zero<SUI>(),
            range,
            winning_number: option::none(),
            start_time,
            end_time,
            tickets: vec_set::empty(), 
            cancelled: false
        };

        event::emit(LotteryCreated{
            lottery: object::id(&lottery)
        });  

        transfer::transfer( WithdrawalCapability {
            id: object::new(ctx),
            lottery: object::id(&lottery),
        }, recipient);
        
        transfer::share_object(lottery);


        
    }

    /*
        Withdraw the current balance from the lottery to the recipient. Abort if the lottery_cap 
        does not match the lottery, the lottery has been cancelled, or the lottery has not been run.
        @param lottery_cap - WithdrawalCapability object
        @param lottery - Lottery object
        @param recipient - Address of recipient for the withdrawal
        @param ctx - Transaction context.
	*/
    public fun withdraw<T: key + store>(
        lottery_cap: &WithdrawalCapability, 
        lottery: &mut Lottery<T>, 
        recipient: address, 
        ctx: &mut TxContext
    ) {
        let WithdrawalCapability {id:_ , lottery:lottery_id} = lottery_cap;

        assert!(object::uid_as_inner(&lottery.id) == lottery_id ,ENoWithdrawalCapability);  
        assert!(!lottery.cancelled,ELotteryCancelled);
        assert!(option::is_some(&lottery.winning_number),ELotteryHasNoWinningNumber);

        let bal = coin::take(&mut lottery.balance,10,ctx);

        event::emit(LotteryWithdrawal{
            lottery:  object::uid_to_inner(&lottery.id),
            amount: coin::value(&bal),
            recipient,
        });

        transfer::public_transfer(bal,recipient);}

    /*
        Buy a lottery ticket for the recipient. Anyone can buy a ticket number of their choosing. 
        Abort if the lottery has been cancelled, the lottery has already been run, the payment is 
        less than the price per ticket, the ticket number is greater than the range, or the ticket 
        number has already been bought. 
        @param ticket_number - The ticket number we wish to buy
        @param lottery - Lottery object
        @param payment - Payment in SUI for the ticket
        @param recipient - Address of recipient for the withdrawal
        @param ctx - Transaction context.
	*/
    public fun buy<T: key + store>(
        ticket_number: u64, 
        lottery: &mut Lottery<T>, 
        payment: &mut Coin<SUI>, 
        recipient: address, 
        ctx: &mut TxContext
    ) {
        assert!(!lottery.cancelled,ELotteryCancelled);
        assert!(!option::is_some(&lottery.winning_number),EStartOrEndTimeInThePast);
        assert!(coin::value(payment) >= lottery.price ,EInsufficientFunds);
        assert!(ticket_number <= lottery.range,EInvalidRange);
        assert!(!vec_set::contains(&lottery.tickets,&ticket_number),ETicketAlreadyGone);

        let ticket_bal = coin::balance_mut<SUI>(payment);
        let bal = balance::withdraw_all(ticket_bal);
        balance::join(&mut lottery.balance , bal);

        let ticket = LotteryTicket {
        id: object::new(ctx) ,
        lottery: object::uid_to_inner(&lottery.id),
        ticket_number,
        };

        vec_set::insert(&mut lottery.tickets, ticket.ticket_number);
        transfer::transfer(ticket,recipient);

        event::emit( LotteryTicketBought {
            ticket_number,
            lottery: object::uid_to_inner(&lottery.id),
        });
    }

    /*
        Generates the random number and ends the lottery with it. (DON'T MODIFY)
        @param lottery - Lottery object
        @param clock - Clock object
        @param ctx - Transaction context.
	*/
    public fun run<T: key + store>(
        lottery: &mut Lottery<T>, 
        clock: &Clock, 
        ctx: &mut TxContext
    ) {
        let winning_number = overmind::random::generate_number(lottery.range, ctx);
        run_internal(lottery, clock, winning_number)
    }

    /*
        Updates the lottery if a winner is found. Abort if the lottery has already been run, the lottery 
        has been cancelled, the lottery has not yet ended, or the lottery has not yet reached the 
        minimum number of participants.
        @param lottery - Lottery object
        @param clock - Clock object
	*/
    fun run_internal<T: key + store>(
        lottery: &mut Lottery<T>, 
        clock: &Clock,
        winning_number: u64
    ) {
        // assert!(option::is_some(&lottery.winning_number),ENotWinningNumber);
        assert!(!lottery.cancelled,ELotteryCancelled);
        assert!(lottery.end_time < clock::timestamp_ms(clock), EStartOrEndTimeInThePast);
        // assert!(vec_set::size(&lottery.tickets) >= 1, EInvalidNumberOfParticipants);

        event::emit( LotteryWinner {
            lottery: object::uid_to_inner(&lottery.id),
            winning_number,
        });

        lottery.winning_number = option::some(winning_number);




    }
    
    /*
        Claim prize for the winning ticket. Abort if the lottery has not been run, the lottery 
        ticket does not match the lottery, the lottery has no NFT prize, or the lottery ticket is
        not the winning number.
        @param lottery - Lottery object
        @param ticket - Winning lottery ticket
        @param recipient - Recipient to receive the prize
	*/
    public fun claim_prize<T: key + store>(
        lottery: &mut Lottery<T>, 
        ticket: &LotteryTicket, 
        recipient: address
    ) {
        assert!(option::is_some(&lottery.nft),ENoPrizeAvailable);
        assert!(option::is_some(&lottery.winning_number), ELotteryHasNoWinningNumber);
        assert!(ticket.lottery == object::uid_to_inner(&lottery.id),EInvalidLottery);
        assert!(ticket.ticket_number == option::extract(&mut lottery.winning_number) ,ENotWinningNumber);

        transfer::public_transfer(option::extract(&mut lottery.nft),recipient);


        
    } 

    /*
        Cancels the lottery if it has not been cancelled already. Send the ticket cost back to the 
        recipient. Abort if the lottery cannot be cancelled, or if the ticket has already been 
        refunded. 
        @param lottery - Lottery object
        @param clock - Clock object
        @param ticket - Lottery ticket object
        @param recipient - Recipient to receive refund
        @param ctx - Transaction context.
	*/
    public fun refund<T: key + store>(
        lottery: &mut Lottery<T>, 
        clock: &Clock, 
        ticket: &LotteryTicket, 
        recipient: address, 
        ctx: &mut TxContext
    ) {

        if (!lottery.cancelled){
            lottery.cancelled = true;
        };

        
        let seven_days_in_milliseconds:u64 = 7*24*60*60*1000;
        assert!(lottery.end_time + seven_days_in_milliseconds < clock::timestamp_ms(clock),ENotCancelled);
        assert!(option::is_none(&lottery.winning_number),ELotteryHasAlreadyRun);
        

        assert!(vec_set::contains(&lottery.tickets,&ticket.ticket_number),ETicketNotAvailable);
        

        let bal = balance::split(&mut lottery.balance,lottery.price);
        let refund_coin = coin::from_balance(bal,ctx);
        transfer::public_transfer(refund_coin,recipient);

        vec_set::remove(&mut lottery.tickets , &ticket.ticket_number)

        
        
        
    }

    /*
        Cancels the lottery if it has not been cancelled already. Send the NFT to the recipient. 
        Abort if the lottery cannot be canceled, or if there is no NFT prize.
        @param lottery - Lottery object
        @param clock - Clock object
        @param recipient - Recipient to receive refund
        @param withdrawal_cap - WithdrawalCapability object
	*/
    public fun return_nft<T: key + store>(
        lottery: &mut Lottery<T>, 
        clock: &Clock, 
        recipient: address, 
        withdrawal_cap: WithdrawalCapability
    ) {
            let WithdrawalCapability {id:id,lottery:_} = withdrawal_cap;
        if (!lottery.cancelled){
            lottery.cancelled = true;
        };
        let seven_days_in_milliseconds:u64 = 7*24*60*60*1000;
        assert!(lottery.end_time + seven_days_in_milliseconds < clock::timestamp_ms(clock),ENotCancelled);
        assert!(option::is_none(&lottery.winning_number),ELotteryHasAlreadyRun);

        assert!(option::is_some(&lottery.nft),ENoPrizeAvailable);

        transfer::public_transfer(option::extract(&mut lottery.nft),recipient);
        object::delete(id)


    }

    /*
        Destroy the given ticket and remove it from the lottery. Abort if the ticket is not found in 
        the lottery.
        @param lottery - Lottery the ticket was bought for
        @param ticket - Ticket to be burnt
	*/
    public fun burn_ticket<T: key + store>(
        lottery: &mut Lottery<T>,
        ticket: LotteryTicket
    ) {
        assert!(vec_set::contains(&lottery.tickets, &ticket.ticket_number),ETicketNotFound);
        let LotteryTicket { id:id , lottery:_, ticket_number:_ } = ticket;
        object::delete(id)

        
    }

    //==============================================================================================
    // Helper functions - Add your helper functions here (if any)
    //==============================================================================================

    //==============================================================================================
    // Validation functions - Add your validation functions here (if any)
    //==============================================================================================

    // inline fun abort_if_cancelled (lottery:&Lottery){
    //     assert!(!lottery.canceled,ELotteryCancelled);
    // };
    // inline fun abort_if_not_cancelled (lottery:&Lottery){
    //     assert!(lottery.canceled,ENotCancelled);
    // }
  
}
```
