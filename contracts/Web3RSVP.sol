// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Web3RSVP {
    /* All the events must be at the top of all the code */
    event NewEventCreated(
        bytes32 eventId,
        address creatorAddress,
        uint256 eventTimestamp,
        uint256 maxCapacity,
        uint256 deposit,
        string eventDataCID
    );

    event NewRSVP(bytes32 eventId, address attendeeAddress);

    event ConfirmedAttendee(bytes32 eventId, address attendeeAddress);

    event DepositsPaidOut(bytes32 eventId);

    struct CreateEvent {
        bytes32 eventId;
        /* To store the IPFS reference of the event information inside the variable evebtDataCID, like description and name. */
        string eventDataCID;
        address eventOwner;
        uint256 eventTimestamp;
        uint256 deposit;
        uint256 maxCapacity;
        address[] confirmedRSVPs;
        address[] claimedRSVPs;
        bool paidOut;
    }
    // Mapping to track events via a unique eventID.
    mapping(bytes32 => CreateEvent) public idToEvent;

    function createNewIdEvent(
        /* These are the parameters the creator of the event will input on the front-end, so its
        setted as external in order to save gas. */
        uint256 eventTimestamp,
        uint256 deposit,
        uint256 maxCapacity,
        string calldata eventDataCID
    ) external {
        /* generate a new eventID based on the parameters passed onto a hash function. It's important to look out this kind of data, and avoid any collisions. For that reason is suggested to use a hash function. */
        bytes32 eventId = keccak256(
            abi.encodePacked(
                msg.sender,
                address(this),
                eventTimestamp,
                deposit,
                maxCapacity
            )
        );

        /* Initialize both arrays to actually have a space ready to receive the events created every time the function is called. */
        address[] memory claimedRSVPs;
        address[] memory confirmedRSVPs;

        /*  This creates a new CreateEvent struct and adds it to the idToEvent mapping. This could mean as adding a brand new ID for each new event is being created, which is at the same time added to the directory of events managed by the smart contract. */
        idToEvent[eventId] = CreateEvent(
            eventId,
            eventDataCID,
            msg.sender,
            eventTimestamp,
            deposit,
            maxCapacity,
            confirmedRSVPs,
            claimedRSVPs,
            false
        );

        // Pass in the args with right value according to the stablished inside the event.
        emit NewEventCreated(
            eventId,
            msg.sender,
            eventTimestamp,
            maxCapacity,
            deposit,
            eventDataCID
        );
    }

    /*  Function for the user to enter the eventId to attend, so it registers a new RVSP item inside the corresponding array. The requirements must to be met in order to continue with the execution flow all the way to the bottom. */
    function createNewRSVP(bytes32 eventId) external payable {
        /* Look up event from the mapping creating a
        dedicated variable called myEvent. */
        CreateEvent storage myEvent = idToEvent[eventId];

        /* Transfer deposit to our contact / require that they send in enough ETH to cover the deposit requirement of this specific event. */
        require(
            msg.value == myEvent.deposit,
            "Not quite the right amount of ETH"
        );

        // Require that the event hasn't already happened(<eventTimestamp).
        require(
            block.timestamp <= myEvent.eventTimestamp,
            "This event has already finished. So sorry :/"
        );

        // Make sure the event is under max capacity.
        require(
            myEvent.confirmedRSVPs.length < myEvent.maxCapacity,
            "This event has reached its maximum capacity. We expect to see you in the next one ;)"
        );

        // Require that msg.sender isn't already in myEvent.confirmedRSVPs AKA hasn't already RSVP'd.
        for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++) {
            require(
                myEvent.confirmedRSVPs[i] != msg.sender,
                "Already confirmed for this event"
            );
        }

        // If the caller isn't confirmed, then the address is pushed into the corresponding array.
        myEvent.confirmedRSVPs.push(payable(msg.sender));

        // Event:
        emit NewRSVP(eventId, msg.sender);
    }

    // Checks in the users when they arrive to the event and returns their deposit.
    function confirmAttendee(bytes32 eventId, address attendee) public {
        // Look up event from our struct using the eventId.
        CreateEvent storage myEvent = idToEvent[eventId];

        /* Require that msg.sender is the owner of the event. Only the host should be able to check people in.*/
        require(msg.sender == myEvent.eventOwner, "NOT AUTHORIZED");

        // Require that attendee trying to check in actually RSVP'd.
        address rsvpConfirm;

        for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++) {
            if (myEvent.confirmedRSVPs[i] == attendee) {
                rsvpConfirm = myEvent.confirmedRSVPs[i];
            }
        }

        require(rsvpConfirm == attendee, "NO RSVP TO CONFIRM");

        // Require that attendee is NOT already in the claimedRSVPs list AKA. Make sure they haven't already checked in.
        for (uint8 i = 0; i < myEvent.claimedRSVPs.length; i++) {
            require(myEvent.claimedRSVPs[i] != attendee, "ALREADY CLAIMED");
        }

        // Require that deposits are not already claimed by the event owner.
        require(myEvent.paidOut == false, "ALREADY PAID OUT");

        // Add the attendee to the claimedRSVPs list.
        myEvent.claimedRSVPs.push(attendee);

        // Sending eth back to the staker `https://solidity-by-example.org/sending-ether`.
        (bool sent, ) = attendee.call{value: myEvent.deposit}("");

        // If this fails, remove the user from the array of claimed RSVPs.
        if (!sent) {
            myEvent.claimedRSVPs.pop();
        }

        require(sent, "Failed to send Ether");

        // Event:
        emit ConfirmedAttendee(eventId, attendee);
    }

    function confirmAllAttendees(bytes32 eventId) external {
        // Look up event from our struct with the eventId.
        CreateEvent memory myEvent = idToEvent[eventId];

        // Make sure you require that msg.sender is the owner of the event.
        require(msg.sender == myEvent.eventOwner, "NOT AUTHORIZED");

        // Confirm each attendee in the rsvp array.
        for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++) {
            confirmAttendee(eventId, myEvent.confirmedRSVPs[i]);
        }
    }

    function withdrawUnclaimedDeposits(bytes32 eventId) external {
        // Look up event.
        CreateEvent memory myEvent = idToEvent[eventId];

        // Check that the paidOut boolean still equals false AKA the money hasn't already been paid out.
        require(!myEvent.paidOut, "ALREADY PAID");

        // Check if it's been 7 days past myEvent.eventTimestamp.
        require(
            block.timestamp >= (myEvent.eventTimestamp + 7 days),
            "TOO EARLY"
        );

        // Only the event owner can withdraw.
        require(msg.sender == myEvent.eventOwner, "MUST BE EVENT OWNER");

        // Calculate how many people didn't claim by comparing.
        uint256 unclaimed = myEvent.confirmedRSVPs.length -
            myEvent.claimedRSVPs.length;

        uint256 payout = unclaimed * myEvent.deposit;

        // Mark as paid before sending to avoid reentrancy attack.
        myEvent.paidOut = true;

        // Send the payout to the owner.
        (bool sent, ) = msg.sender.call{value: payout}("");

        // If this fails...
        if (!sent) {
            myEvent.paidOut == false;
        }

        require(sent, "Failed to send Ether");

        // Event:
        emit DepositsPaidOut(eventId);
    }
}
