pragma solidity ^0.4.15;

contract MultiSignatureWallet {

    address[] public owners;
    uint256 public required;
    mapping(address => bool) public isOwner;
    uint256 public transactionCount;
    mapping (uint => Transaction) public transactions;
    mapping (uint => mapping (address => bool)) public confirmations;

    
    struct Transaction {
	    bool executed;
        address destination;
        uint value;
        bytes data;
    }

    event Submission(uint256 indexed transactionId);
    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event ConfirmationRevoked(address indexed sender, uint256 indexed transactionId);
    event ExecutionOk(uint256 indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);

    
    modifier validRequirement(uint ownerCount, uint _required) {
        if (   _required > ownerCount
            || _required == 0
            || ownerCount == 0)
            revert();
        _;
    }
    
    /// @dev Fallback function, which accepts ether when sent to contract
    function() public payable {}

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] _owners, uint _required) public 
        validRequirement(_owners.length, _required) {
                for (uint i=0; i<_owners.length; i++) {
                    isOwner[_owners[i]] = true;
                }
                owners = _owners;
                required = _required; 
        }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function submitTransaction(address destination, uint value, bytes data) 
        public returns (uint transactionId) {
            require(isOwner[msg.sender]);
            transactionId = addTransaction(destination, value, data);
            confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId) public {
        require(isOwner[msg.sender]);
        require(transactions[transactionId].destination != 0);
        require(confirmations[transactionId][msg.sender] == false);
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId) public {
        require(isOwner[msg.sender]);
        require(transactions[transactionId].destination != 0);
        require(confirmations[transactionId][msg.sender] == true);
        confirmations[transactionId][msg.sender] = false;
        emit ConfirmationRevoked(msg.sender, transactionId);
    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) public {
        require(transactions[transactionId].executed == false);
        if (isConfirmed(transactionId)){
             Transaction storage txn = transactions[transactionId];
            txn.executed = true;
            if (txn.destination.call.value(txn.value)(txn.data))
                emit ExecutionOk(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                txn.executed = false;
            }
        }
    }

		/*
		 * (Possible) Helper Functions
		 */
    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) internal constant returns (bool) {
        uint256 confirmed = 0;
        for (uint256 i=0; i < owners.length; i++){
            if (confirmations[transactionId][owners[i]]) {
                confirmed++;
            }
            if (confirmed >= required) {
                return true;
            }
        }
        return false;
    }

    /// @dev Adds a new transaction to the transaction mapping.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function addTransaction(address destination, uint value, bytes data) 
        internal returns (uint transactionId) {
            transactionId = transactionCount;
            transactions[transactionId] = Transaction({
                destination: destination,
                value: value,
                data: data,
                executed: false
            });
            transactionCount += 1;
            emit Submission(transactionId);
        }
}
