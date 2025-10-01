// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

struct Bidders {
    address bidder;
    uint256 bidAmount;
    string fid;
}

struct AuctionMeta {
    address caInUse;
    string tokenName;
    uint256 deadline;
    uint256 auctionId;
    address auctionOwner;
}

contract LNOBAuction {
    IERC20 public erc20;               
    IERC20Permit public tokenPermit;   

    address public highestBidder;
    uint256 public highestBid;

    uint256 public auctionId = 1;

    mapping(uint256 => mapping(address => uint256)) public bids;
    mapping(uint256 => Bidders[]) public biddersByAuctionId;
    mapping(uint256 => string) public currencyUsed;
    mapping(uint256 => address) public caInUse;
    mapping(uint256 => mapping(address => bool)) private hasBid;
    mapping(uint256 => uint256) public auctionDeadline;
    mapping(uint256 => address) public auctionOwner;   // <--- new mapping

    event BidPlaced(address indexed bidder, uint256 amount, string fid);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 amount, address auctionOwner);

    /// @notice Start a new auction for a token
    function startAuction(
        address _token,
        string calldata _tokenName,
        uint256 durationHours
    ) external {
        uint256 currentAuctionId = auctionId;

        currencyUsed[currentAuctionId] = _tokenName;
        caInUse[currentAuctionId] = _token;
        erc20 = IERC20(_token);
        tokenPermit = IERC20Permit(_token);

        uint256 nextDeadline = block.timestamp + (durationHours * 1 hours);
        auctionDeadline[currentAuctionId] = nextDeadline;

        auctionOwner[currentAuctionId] = msg.sender; // <--- whoever calls becomes auction owner
    }

    /// @notice Returns metadata of the current auction
    function getCurrentAuctionMeta() external view returns (AuctionMeta memory) {
        return AuctionMeta({
            caInUse: caInUse[auctionId],
            tokenName: currencyUsed[auctionId],
            deadline: auctionDeadline[auctionId],
            auctionId: auctionId,
            auctionOwner: auctionOwner[auctionId]
        });
    }

    /// @notice Returns metadata of any auction by ID
    function getAuctionMetaById(uint256 _auctionId) external view returns (AuctionMeta memory) {
        return AuctionMeta({
            caInUse: caInUse[_auctionId],
            tokenName: currencyUsed[_auctionId],
            deadline: auctionDeadline[_auctionId],
            auctionId: _auctionId,
            auctionOwner: auctionOwner[_auctionId]
        });
    }

    function placeBid(uint256 amount, string memory fid) public {
        require(block.timestamp < auctionDeadline[auctionId], "Auction has ended");
        require(amount > highestBid, "Bid not high enough");

        require(
            erc20.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        if (highestBidder != address(0)) {
            uint256 refundAmount = highestBid;
            address previousBidder = highestBidder;
            highestBid = 0;
            require(
                erc20.transfer(previousBidder, refundAmount),
                "Refund failed"
            );
        }

        bids[auctionId][msg.sender] = amount;

        Bidders[] storage bidders = biddersByAuctionId[auctionId];
        if (!hasBid[auctionId][msg.sender]) {
            bidders.push(Bidders({bidder: msg.sender, bidAmount: amount, fid: fid}));
            hasBid[auctionId][msg.sender] = true;
        } else {
            for (uint256 i = 0; i < bidders.length; i++) {
                if (bidders[i].bidder == msg.sender) {
                    bidders[i].bidAmount = amount;
                    bidders[i].fid = fid;
                    break;
                }
            }
        }

        highestBid = amount;
        highestBidder = msg.sender;

        emit BidPlaced(msg.sender, amount, fid);
    }

    function bidWithPermit(
        uint256 amount,
        string memory fid,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp < auctionDeadline[auctionId], "Auction has ended");
        require(amount > highestBid, "Bid not high enough");

        tokenPermit.permit(msg.sender, address(this), amount, deadline, v, r, s);
        placeBid(amount, fid);
    }

    function endAuction() external {
        uint256 currentAuctionId = auctionId;
        address ownerOfAuction = auctionOwner[currentAuctionId];

        require(msg.sender == ownerOfAuction, "Only auction owner can end");

        if (highestBid > 0 && highestBidder != address(0)) {
            require(
                erc20.transfer(ownerOfAuction, highestBid),
                "Token transfer to auction owner failed"
            );
            bids[currentAuctionId][highestBidder] = 0;
        }

        emit AuctionEnded(currentAuctionId, highestBidder, highestBid, ownerOfAuction);

        // Reset state
        highestBidder = address(0);
        highestBid = 0;

        // Move to next auction
        auctionId = currentAuctionId + 1;
    }

    function getBidders(uint256 _auctionId) external view returns (Bidders[] memory) {
        return biddersByAuctionId[_auctionId];
    }

    function emergencyRefund() external {
        uint256 currentAuctionId = auctionId;
        address ownerOfAuction = auctionOwner[currentAuctionId];

        require(msg.sender == ownerOfAuction, "Only auction owner can refund");

        uint256 balance = erc20.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(erc20.transfer(ownerOfAuction, balance), "Token transfer failed");

        highestBidder = address(0);
        highestBid = 0;

        auctionId = auctionId + 1;
    }
}
