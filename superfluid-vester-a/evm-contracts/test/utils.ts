import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumberish, ContractTransaction } from "ethers";
import { ethers } from "hardhat";

import { SuperfluidVestooorFactory } from "../typechain-types";

import { TEST_ENVIRONMENT_CONSTANTS, TestEnvironment } from "./TestEnvironment";

export const _console = (message?: any, ...optionalParams: any[]) => {
    if (process.env.CONSOLE_LOG) {
        optionalParams.length > 0
            ? console.log(message, ...optionalParams)
            : console.log(message);
    }
};

export const toBN = (x: any) => ethers.BigNumber.from(x);

export const buildVestee = (
    vesteeAddress: string,
    amountToVest: BigNumberish,
    vestingEndTimestamp: BigNumberish
): SuperfluidVestooorFactory.VesteeStruct => {
    return {
        vesteeAddress,
        vestingEndTimestamp,
        amountToVest,
    };
};

export const buildVestees = async (
    vesteeAddresses: string[],
    timeToGoForwards = TEST_ENVIRONMENT_CONSTANTS.DEFAULT_VEST_DURATION
): Promise<SuperfluidVestooorFactory.VesteeStruct[]> => {
    const block = await ethers.provider.getBlock("latest");
    const desiredVestingEndTime = block.timestamp + timeToGoForwards;

    return vesteeAddresses.map((x) =>
        buildVestee(
            x,
            TEST_ENVIRONMENT_CONSTANTS.DEFAULT_VEST_AMOUNT,
            desiredVestingEndTime
        )
    );
};

export const getTotalAmountToBeVested = (
    vestees: SuperfluidVestooorFactory.VesteeStruct[]
) => {
    return vestees
        .map((x) => toBN(x.amountToVest))
        .reduce((a, b) => toBN(a).add(toBN(b)), toBN(0));
};

export const getEndTimestamp = async (
    timeToGoForwards = TEST_ENVIRONMENT_CONSTANTS.DEFAULT_VEST_DURATION
) => {
    const block = await ethers.provider.getBlock("latest");
    _console("Current Timestamp:", block.timestamp);
    const futureTimestamp = block.timestamp + timeToGoForwards;
    _console("Future Timestamp", futureTimestamp);
    return futureTimestamp;
};

export const getInstanceAddress = async (txn: ContractTransaction) => {
    const receipt = await txn.wait();
    const { events } = receipt;
    if (events) {
        const { args } = events.find(
            (x) => x.event === "VestingContractCreated"
        )!;
        const address = args!.instanceAddress;
        _console("Instance at:", address);
        return address;
    }
    return ethers.constants.AddressZero;
};

export const createSingleVestingContractPromise = (
    testEnv: TestEnvironment,
    signer: SignerWithAddress,
    vestee: SuperfluidVestooorFactory.VesteeStruct
) => {
    const { hostAddress, cfaV1Address } = testEnv.framework.settings.config;
    return testEnv.SuperfluidVestooorFactory.connect(
        signer
    ).createVestingContract(vestee, hostAddress, cfaV1Address);
};

export const createMultipleVestingContractPromise = (
    testEnv: TestEnvironment,
    signer: SignerWithAddress,
    vestees: SuperfluidVestooorFactory.VesteeStruct[],
    totalAmountToBeVested: BigNumberish
) => {
    const { hostAddress, cfaV1Address } = testEnv.framework.settings.config;
    return testEnv.SuperfluidVestooorFactory.connect(
        signer
    ).createVestingContracts(
        vestees,
        totalAmountToBeVested,
        hostAddress,
        cfaV1Address
    );
};

export const mintTokens = async (
    testEnv: TestEnvironment,
    signer: SignerWithAddress,
    amount: BigNumberish
) => {
    _console(`Mint ${amount.toString()} Tokens to ${signer.address}`);
    await testEnv.token.connect(signer).mint(signer.address, amount);
};
