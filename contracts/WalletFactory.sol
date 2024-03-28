// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

import "./MultiSigWallet.sol";

contract WalletFactory {
    MultiSigWallet[] public multiSigWallets;
    mapping(address => address[]) ownerWallets;

    function createNewWallet(
        address[] memory _owners,
        uint256 _numConfirmationsRequired
    ) public {
        MultiSigWallet multiSigWallet = new MultiSigWallet(
            _owners,
            _numConfirmationsRequired
        );
        multiSigWallets.push(multiSigWallet);

        for (uint256 i = 0; i < _owners.length; i++) {
            ownerWallets[_owners[i]].push(address(multiSigWallet));
        }
    }

    function getWallets() public view returns (address[] memory) {
        return ownerWallets[msg.sender];
    }
}
