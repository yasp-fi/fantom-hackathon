pragma solidity ^0.8.0;

// Importing zkSync contract interface
// import '@matterlabs/zksync-contracts/l1/contracts/zksync/interfaces/IZkSync.sol';

// abstract contract ZkSyncConnector is Ownable {
//     address public zkSyncAddress;

//     mapping(uint32 => mapping(uint256 => bool)) public isL2ToL1MessageProcessed;

//     constructor(address owner, address zkSyncAddress_) Ownable(owner) {
//         zkSyncAddress = zkSyncAddress_;
//     }

//     function setZkSyncAddress(address newZkSyncAddress) external ownerOnly {
//       require(newZkSyncAddress != address(0));
//       zkSyncAddress = newZkSyncAddress;
//     }

//     function consumeMessageFromL2(
//         address _zkSyncAddress,
//         uint32 _l2BlockNumber,
//         uint256 _index,
//         bytes calldata _message,
//         bytes32[] calldata _proof
//     ) external returns (bytes32 messageHash) {
//         // check that the message has not been processed yet
//         require(!isL2ToL1MessageProcessed(_l2BlockNumber, _index));

//         IZkSync zksync = IZkSync(zkSyncAddress);
//         L2Message message = L2Message({sender: owner, data: _message});

//         bool success = zksync.proveL2MessageInclusion(
//             _l2BlockNumber,
//             _index,
//             message,
//             _proof
//         );
//         require(success, 'Failed to prove message inclusion');

//         // handle message from L2
//         handle(message);

//         // Mark message as processed
//         isL2ToL1MessageProcessed(_l2BlockNumber, _index) = true;
//     }

//     function handle(L2Message memory msg) internal virtual;
// }
