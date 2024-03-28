// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        TxType txType
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired;

    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _owners.length,
            "Invalid number of confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Not a unique owner");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    enum TxType {
        payment,
        addOwner,
        removeOwner,
        changeNumConfirmation
    }

    struct Transaction {
        address to;
        uint256 value;
        bool executed;
        uint256 numConfirmations;
        TxType txType;
    }

    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    modifier validNumConfirmation(uint256 _numConfirmations, TxType _txType) {
        require(
            _txType != TxType.changeNumConfirmation ||
                isValidNumConfirmations(_numConfirmations),
            "Invalid number of confirmations"
        );
        _;
    }

    function isValidNumConfirmations(uint256 _numConfirmations)
        public
        view
        returns (bool)
    {
        return _numConfirmations <= owners.length;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(
            !transactions[_txIndex].executed,
            "Transaction already executed"
        );
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(
            !isConfirmed[_txIndex][msg.sender],
            "Transaction already confirmed"
        );
        _;
    }

    modifier addressExists(address _ownerAddress, TxType _txType) {
        require(
            _txType != TxType.removeOwner || isOwner[_ownerAddress],
            "Address not owner"
        );
        _;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        TxType _txType
    )
        public
        onlyOwner
        addressExists(_to, _txType)
        validNumConfirmation(_value, _txType)
    {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                executed: false,
                numConfirmations: 0,
                txType: _txType
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _txType);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bool executed,
            uint256 numConfirmations,
            TxType txType
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.executed,
            transaction.numConfirmations,
            transaction.txType
        );
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "Transaction not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        address txAddress = transaction.to;

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "Confirmation requirement not met"
        );

        if (transaction.txType == TxType.addOwner) {
            owners.push(txAddress);
            isOwner[txAddress] = true;
        } else if (transaction.txType == TxType.removeOwner) {
            uint256 indexToRemove;
            for (uint256 i = 0; i < owners.length; i++) {
                if (owners[i] == txAddress) {
                    indexToRemove = i;
                    break;
                }
            }
            owners[indexToRemove] = owners[owners.length - 1];
            owners.pop();
            isOwner[txAddress] = false;
            if (!isValidNumConfirmations(numConfirmationsRequired)) {
                numConfirmationsRequired = numConfirmationsRequired - 1;
            }
        } else if (transaction.txType == TxType.changeNumConfirmation) {
            require(
                isValidNumConfirmations(transaction.value),
                "Invalid number of confirmations"
            );
            numConfirmationsRequired = transaction.value;
        } else {
            (bool success, ) = txAddress.call{value: transaction.value}("");
            require(success, "Transfer failed");
        }

        transaction.executed = true;

        emit ExecuteTransaction(msg.sender, _txIndex);
    }
}
