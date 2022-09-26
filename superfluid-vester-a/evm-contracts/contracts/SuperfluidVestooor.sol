// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {
    CFAv1Library
} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {
    ISuperfluid
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";

/// @title Superfluid Vestooor Contract
/// @author Superfluid
/// @notice A Simple PoC Vesting Contract built with Superfluid.
/// @dev Given the nature of perpetual SF flows, some off-chain automation is needed.
contract SuperfluidVestooor is Initializable {
    using CFAv1Library for CFAv1Library.InitData;

    /** State Variables */

    /// @notice A convenience library so we don't have to use callAgreement
    CFAv1Library.InitData public cfaV1Lib;

    /// @notice Timestamp the vesting started
    uint256 public vestingStartTimestamp;

    /// @notice Timestamp the vesting should end (roughly)
    /// @dev This will be the timestamp the balance of the SuperTokens will hit 0
    uint256 public vestingEndTimestamp;

    /// @notice The amount of tokens to be vested
    /// @dev This will be the total amount of SuperTokens to be vested by the contract
    uint256 public amountToVest;

    /// @notice The owner of the contract
    /// @dev This will be the vestee and ownership of the contract is non transferrable
    address public owner;

    /// @notice The SuperToken to be vested
    ISuperToken public tokenToVest;

    /** Events */

    event VestingEnded(uint256 timestamp, uint256 transferredAmount);

    /** Custom Errors */

    error VESTING_IN_PROGRESS();
    error VESTING_END_TOO_EARLY();

    /** Functions */

    /// @notice Initializes the implementation contract
    /// @dev Transfers ownership to _vestee and has the option to start vesting on contract initialization
    /// @param _vestee the address receiving the vested tokens
    /// @param _host the Superfluid host contract address
    /// @param _cfa the Superfluid cfa contract address
    /// @param _superToken the SuperToken contract address
    /// @param _amountToVest the amount of tokens to vest
    /// @param _vestingEndTimestamp the timestamp to end vesting
    function initialize(
        address _vestee,
        ISuperfluid _host,
        IConstantFlowAgreementV1 _cfa,
        ISuperToken _superToken,
        uint256 _amountToVest,
        uint256 _vestingEndTimestamp
    ) external initializer {
        // @note transfer ownership to the vestee
        owner = _vestee;

        cfaV1Lib = CFAv1Library.InitData(_host, _cfa);
        vestingStartTimestamp = block.timestamp;
        vestingEndTimestamp = _vestingEndTimestamp;
        amountToVest = _amountToVest;
        tokenToVest = _superToken;

        int96 flowRate = _getVestingFlowRate(_amountToVest, _vestingEndTimestamp, block.timestamp);
        cfaV1Lib.createFlow(_vestee, _superToken, flowRate);
    }

    /// @notice Gets the vesting flow rate given _amountToVest, _vestingEndTimestamp, _vestingStartTimestamp
    /// @param _amountToVest the amount of SuperTokens to be vested
    /// @param _vestingEndTimestamp the vesting end timestamp
    /// @param _vestingStartTimestamp the vesting start timestamp
    /// @return the vesting flow rate
    function _getVestingFlowRate(
        uint256 _amountToVest,
        uint256 _vestingEndTimestamp,
        uint256 _vestingStartTimestamp
    ) internal pure returns (int96) {
        return int96(int256(_amountToVest / (_vestingEndTimestamp - _vestingStartTimestamp)));
    }

    /// @notice Restarts vesting in the event that the receiver deletes their flow during the vesting period.
    /// @dev If Vesting Endable state, we transfer the remaining vest amount and end it.
    /// Else: We settle the amount that should've been vested since the flow was deleted and continue vesting the remaining amount.
    /// NOTE: Anyone can call this function and can deposit more tokens to this contract to increase the flow rate.
    function restartVesting() public {
        (, int96 currentFlowRate, , ) = cfaV1Lib.cfa.getFlow(tokenToVest, address(this), owner);
        if (currentFlowRate != 0) revert VESTING_IN_PROGRESS();

        uint256 remainingTokenBalance = tokenToVest.balanceOf(address(this));

        if (canStopVesting()) {
            tokenToVest.transfer(owner, remainingTokenBalance);

            emit VestingEnded(block.timestamp, remainingTokenBalance);

            return;
        }

        // vesting flow rate based on the original amount to vest and the vesting start and end timestamps
        int96 vestingFlowRate = _getVestingFlowRate(
            amountToVest,
            vestingEndTimestamp,
            vestingStartTimestamp
        );

        // the remaining amount to be flown at the current time
        uint256 remainingToBeFlowed = (vestingEndTimestamp - block.timestamp) *
            uint256(uint96(vestingFlowRate));

        // instantly settle the amount that should've been flown since the flow stopped
        // this is based on the remaining balance, not the total amount to be vested
        // if someone deposited tokens when the flow stopped, these additional tokens
        // would be settled to the
        uint256 instantSettlementAmount = remainingTokenBalance - remainingToBeFlowed;
        tokenToVest.transfer(owner, instantSettlementAmount);

        // continue vesting
        cfaV1Lib.createFlow(owner, tokenToVest, vestingFlowRate);
    }

    /// @notice Checks whether vesting can be ended by the operator
    /// @return bool
    function canStopVesting() public view returns (bool) {
        return block.timestamp >= vestingEndTimestamp - 7 days;
    }

    /// @notice Allows an operator to stop the vesting
    /// @dev The operator has a 7 day grace period to stop vesting prior to the end date and transfer the deposit to the vestee
    function stopVesting() external {
        if (!canStopVesting()) {
            revert VESTING_END_TOO_EARLY();
        }

        cfaV1Lib.deleteFlow(address(this), owner, tokenToVest);

        uint256 tokenBalance = tokenToVest.balanceOf(address(this));
        tokenToVest.transfer(owner, tokenBalance);

        emit VestingEnded(block.timestamp, tokenBalance);
    }
}
