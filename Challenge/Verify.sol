// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;


abstract contract Verify {
    /** @dev verifyMessage keep track and reject double secure message.
    */
    mapping(string => bool) public verifyMessage;

    /** @dev securityAddress address to verify app signature.
    */
    address constant private securityAddress = 0x4a6f4FFd8e7164235E5aA7Db2B8425D3E3a7a165;

    /**
     * @dev verify app signature.
     */
    modifier verifySignature(string memory message, uint8 v, bytes32 r, bytes32 s) {
        require(securityAddress == verifyString(message, v, r, s), "Cant send");
        _;
    }

    /**
     * @dev verify double sending message.
     */
    modifier rejectDoubleMessage(string memory message) {
        require(!verifyMessage[message], "Cant send");
        _;
    }

    /**
     * @dev private funtion for verify message and singer.
     */
    function verifyString(string memory message, uint8 v, bytes32 r, bytes32 s) private pure returns(address signer)
    {
        string memory header = "\x19Ethereum Signed Message:\n000000";
        uint256 lengthOffset;
        uint256 length;
        assembly {
            length:= mload(message)
            lengthOffset:= add(header, 57)
        }
        require(length <= 999999, "Not provided");
        uint256 lengthLength = 0;
        uint256 divisor = 100000;
        while (divisor != 0) {
            uint256 digit = length / divisor;
            if (digit == 0) {
                if (lengthLength == 0) {
                    divisor /= 10;
                    continue;
                }
            }
            lengthLength++;
            length -= digit * divisor;
            divisor /= 10;
            digit += 0x30;
            lengthOffset++;
            assembly {
                mstore8(lengthOffset, digit)
            }
        }
        if (lengthLength == 0) {
            lengthLength = 1 + 0x19 + 1;
        } else {
            lengthLength += 1 + 0x19;
        }
        assembly {
            mstore(header, lengthLength)
        }
        bytes32 check = keccak256(abi.encodePacked(header, message));
        return ecrecover(check, v, r, s);
    }
}