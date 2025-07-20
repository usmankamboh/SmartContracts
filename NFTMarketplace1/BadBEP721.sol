// SPDX-License-Identifier:MIT
pragma solidity 0.8.14;
contract BadBEP721 {
    function supportsInterface(bytes4 _interface) public pure returns (bool){
        return false;
    }
}
