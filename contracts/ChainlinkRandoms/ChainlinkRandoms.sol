// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "./AccessControl.sol";
import "./IERC20.sol";
import "./IRandoms.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract ChainlinkRandoms is AccessControl, IRandoms, VRFConsumerBase {

    bytes32 public constant RANDOMNESS_REQUESTER = keccak256("RANDOMNESS_REQUESTER");

    bytes32 public keyHash;
    uint256 public fee;

    uint256 public seed;

    // BSC testnet details:
    // LINK token: 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06
    // VRF Coordinator: 0xa555fC018435bef5A13C6c6870a9d4C11DEC329C
    // Key Hash: 0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186
    // Fee: 0.1 * 10 ** 18 // 0.1 LINK

    // BSC mainnet details:
    // LINK token: 0x404460C6A5EdE2D891e8297795264fDe62ADBB75
    // VRF Coordinator: 0x747973a5A2a4Ae1D3a8fDF5479f1514F65Db9C31
    // Key Hash: 0xc251acd21ec4fb7f31bb8868288bfdbaeb4fbfec2df3735ddbd4f7dc8d60103c
    // Fee: 0.2 * 10 ** 18 // 0.1 LINK

    constructor(address _vrfCoordinator, address _link, bytes32 _keyHash, uint256 _fee)
        VRFConsumerBase(
            _vrfCoordinator, // VRF Coordinator
            _link  // LINK Token
        )
    {
        keyHash = _keyHash;
        fee = _fee;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Views
    function getRandomSeed(address user) external override view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(user, seed, block.timestamp, block.difficulty)));
    }

    // Mutative
    /**
     * Requests randomness from a user-provided seed
     */
    function requestRandomNumber() external {
        require(hasRole(RANDOMNESS_REQUESTER, msg.sender), "Sender cannot request seed");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");

        // the user-provided seed is not necessary, as per the docs
        // hence we set it to an arbitrary constant
        requestRandomness(keyHash, fee);
    }

    function setSeed(uint256 seedNumber) external {
        require(hasRole(RANDOMNESS_REQUESTER, msg.sender), "Sender cannot request seed");
        seed = seedNumber;
    }
    
    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 /* requestId */, uint256 randomness) internal override {
        seed = randomness;
    }

    function withdrawLink(uint256 tokenAmount) external onlyOwner {
        // very awkward - but should be safe given that the LINK token is ERC20-compatible
        IERC20(address(LINK)).transfer(msg.sender, tokenAmount);
    }

    // Modifiers
    modifier onlyOwner() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        _;
    }
}