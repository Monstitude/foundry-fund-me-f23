// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

error NotEnoughETH();
error WithdrawUnsuccessful();

contract FundMe is Ownable {
    using PriceConverter for uint256;

    mapping(address => uint256) private addressToAmountFunded;
    address[] private funders;

    uint256 public constant MINIMUM_USD = 5 * 1e18;
    AggregatorV3Interface public immutable i_dataFeed;

    constructor(address dataFeed_) Ownable(msg.sender) {
        i_dataFeed = AggregatorV3Interface(dataFeed_);
    }

    function fund() public payable {
        if (msg.value.getConversionRate(i_dataFeed) < MINIMUM_USD)
            revert NotEnoughETH();

        addressToAmountFunded[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    function cheaperWithdraw() public onlyOwner {
        uint256 fundersLength = funders.length;

        for (
            uint256 funderIndex = 0;
            funderIndex < fundersLength;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0);

        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!success) revert WithdrawUnsuccessful();
    }

    function withdraw() public onlyOwner {
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0);

        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!success) revert WithdrawUnsuccessful();
    }

    function getFunder(uint256 idx) public view returns (address) {
        return funders[idx];
    }

    function getAddressToAmountFunded(
        address fundingAddress
    ) public view returns (uint256) {
        return addressToAmountFunded[fundingAddress];
    }

    function getDataFeedVersion() public view returns (uint256) {
        return i_dataFeed.version();
    }

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }
}
