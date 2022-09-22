// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {
    ISuperfluid
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {
    ISuperToken,
    IERC20
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";

import { SuperfluidVestooor } from "./SuperfluidVestooor.sol";

/// @title Superfluid Vesting Factory Contract
/// @author Superfluid
/// @notice A Contract Factory which creates vesting contract(s) for individual vestee(s).
contract SuperfluidVestooorFactory {
    struct Vestee {
        address vesteeAddress;
        uint256 amountToVest;
        uint256 vestingEndTimestamp;
    }

    /// @notice The address of the superfluid vesting contract
    address public sfVestingImplementation;

    /// @notice The address of the SuperToken to be vested
    ISuperToken public vestedToken;

    /// @notice VestingContractCreated Event
    /// @dev This event is emitted whenever a Vestooor Contract is created
    /// @param vestedToken the token to be vested
    /// @param instanceAddress the address of the new vesting instance
    /// @param bank the origin of the vested tokens
    /// @param amountToVest the amount of tokens to be vested
    /// @param vestingEndTimestamp the timestamp the balance of the vested token will be 0
    event VestingContractCreated(
        ISuperToken vestedToken,
        address instanceAddress,
        address vestee,
        address bank,
        uint256 amountToVest,
        uint256 vestingEndTimestamp
    );

    constructor(address _sfVestingImplementation, ISuperToken _vestedToken) {
        sfVestingImplementation = _sfVestingImplementation;
        vestedToken = _vestedToken;
    }

    /// @notice Creates vesting contracts for multiple vestees.
    /// @dev The person sending this must properly approve and have enough balance sent to this
    /// @param _vestees A list of Vestee structs
    /// @param _host Superfluid Host contract address
    /// @param _cfa Superfluid CFA contract address
    function createVestingContracts(
        Vestee[] calldata _vestees,
        uint256 _totalAmountToBeVested,
        ISuperfluid _host,
        IConstantFlowAgreementV1 _cfa
    ) external returns (address[] memory) {
        address[] memory vestingContractAddresses = new address[](_vestees.length);
        _handleERC20TokenTransferAndUpgrade(msg.sender, _totalAmountToBeVested);
        for (uint256 i; i < _vestees.length; ++i) {
            address vestingContractAddress = _createVestingContract(
                msg.sender,
                _vestees[i],
                _host,
                _cfa
            );
            vestingContractAddresses[i] = vestingContractAddress;
        }
        return vestingContractAddresses;
    }

    /// @notice External function for creating the vesting contract
    function createVestingContract(
        Vestee calldata _vestee,
        ISuperfluid _host,
        IConstantFlowAgreementV1 _cfa
    ) external returns (address) {
        _handleERC20TokenTransferAndUpgrade(msg.sender, _vestee.amountToVest);
        return _createVestingContract(msg.sender, _vestee, _host, _cfa);
    }

    /// @notice Takes an ERC20 and transfer it from the "bank" to this contract
    /// @dev This also handles upgrading the token to a SuperToken for transferring to the vesting contract later
    /// @param _bank the source of funds
    /// @param _totalAmountToVest the total amount to be vested
    function _handleERC20TokenTransferAndUpgrade(address _bank, uint256 _totalAmountToVest)
        internal
    {
        address underlyingAddress = vestedToken.getUnderlyingToken();
        IERC20 token = IERC20(underlyingAddress);
        token.transferFrom(_bank, address(this), _totalAmountToVest);
        token.approve(address(vestedToken), _totalAmountToVest);
        vestedToken.upgrade(_totalAmountToVest);
    }

    /// @notice Creates a vesting contract
    /// @dev Creates a vesting contract using the Minimal Proxy Pattern (EIP-1167)
    /// @param _bank the address which will be transferring the tokens
    /// @param _vestee Vestee struct [vesteeAddress, amountToVest, vestingEndTimestamp, startVesting]
    /// @param _host the host contract address
    /// @param _cfa the cfa contract address
    function _createVestingContract(
        address _bank,
        Vestee calldata _vestee,
        ISuperfluid _host,
        IConstantFlowAgreementV1 _cfa
    ) internal returns (address) {
        address instanceAddress = Clones.clone(sfVestingImplementation);

        vestedToken.transfer(instanceAddress, _vestee.amountToVest);

        SuperfluidVestooor(instanceAddress).initialize(
            _vestee.vesteeAddress,
            _host,
            _cfa,
            vestedToken,
            _vestee.amountToVest,
            _vestee.vestingEndTimestamp
        );

        emit VestingContractCreated(
            vestedToken,
            instanceAddress,
            _vestee.vesteeAddress,
            _bank,
            _vestee.amountToVest,
            _vestee.vestingEndTimestamp
        );

        return instanceAddress;
    }
}
