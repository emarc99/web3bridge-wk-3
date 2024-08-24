
pragma solidity >=0.7.0 <0.9.0;

// /** 
//  * @title Crowdfunding
//  * @dev emarc99
//  */
// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;




abstract contract ReentrancyGuard {
    // The ReentrancyGuard contract is designed to prevent reentrancy attacks by
    // using a modifier called nonReentrant (source: OpenZeppelin)

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}


abstract contract Ownable {
    // The Ownable contract provides basic access control, with an account (an owner) that can be granted 
    // exclusive access to specific functions via the onlyOwner modifier (source: OpenZeppelin)
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(msg.sender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


contract CrowdFunding is ReentrancyGuard, Ownable {

    // Campaign structure
    struct Campaign {
        string title;
        string description;
        address payable benefactor;
        uint goal;
        uint deadline;
        uint amountRaised;
        bool ended;
    }

    // Campaign ID tracker
    uint public campaignCount;

    // Mapping of campaign IDs to Campaign structures
    mapping(uint => Campaign) public campaigns;

    // Events
    // Log corresponding events whenever a campaign is created, donation is received or a campaign has ended
    event CampaignCreated(uint indexed campaignId, string title, address indexed benefactor, uint goal, uint deadline);
    event DonationReceived(uint indexed campaignId, address indexed donor, uint amount);
    event CampaignEnded(uint indexed campaignId, address indexed benefactor, uint amountRaised);

    // Create a new campaign
    function createCampaign(
        string memory _title,
        string memory _description,
        address payable _benefactor,
        uint _goal,
        uint _duration
    ) external { // The function can be externally 
        // Check that goal amount is greater than zero 
        require(_goal > 0, "Goal should be greater than zero.");
        require(_duration > 0, "Duration should be greater than zero.");
        // Store number of campaigns created 
        campaignCount++;

        uint _deadline = block.timestamp + _duration;

        // Create new campaign with below inputs
        campaigns[campaignCount] = Campaign({
            title: _title,
            description: _description,
            benefactor: _benefactor,
            goal: _goal,
            deadline: _deadline,
            amountRaised: 0,
            ended: false
        });

        emit CampaignCreated(campaignCount, _title, _benefactor, _goal, _deadline);
    }

    // Donate to a campaign
    function donate(uint _campaignId) external payable nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];

        // If camping has ended, stop taking donations 
        require(block.timestamp < campaign.deadline, "Campaign has ended.");
        require(msg.value > 0, "Donation amount should be greater than zero.");
        require(!campaign.ended, "Campaign has already ended.");

        campaign.amountRaised += msg.value;

        // Emit total donation received 
        emit DonationReceived(_campaignId, msg.sender, msg.value);
    }

    // End a campaign and transfer funds to the benefactor
    function endCampaign(uint _campaignId) external nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];
        // Check that deadline has passed 
        require(block.timestamp >= campaign.deadline, "Campaign is still ongoing.");
        require(!campaign.ended, "Campaign has already ended.");
        // If deadline has passed, change campaign state to ended and log it
        campaign.ended = true;
        emit CampaignEnded(_campaignId, campaign.benefactor, campaign.amountRaised);
        // Let owner withdraw amount raised 
        (bool success, ) = campaign.benefactor.call{value: campaign.amountRaised}("");
        require(success, "Transfer failed.");
    }

    // Withdraw leftover funds by the owner
    // Only the contract owner can withdraw any leftover funds from the contract using `onlyOwner`
    function withdrawLeftoverFunds() external onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No funds to withdraw.");
        // If no balanc
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Withdrawal failed.");
    }
}
