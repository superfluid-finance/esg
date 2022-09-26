import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { verifyContract } from "./verify";

/**
 * Deploys the Superfluid Vestooor Factory contract
 * @param signer deployer
 * @param vestingImplAddress vestooor implementation contract address
 * @param operatorAddress operator who can stop vesting
 * @returns SuperfluidVestooorFactory Contract
 */
export async function deployVestingFactoryContract(
    hre: HardhatRuntimeEnvironment,
    signer: SignerWithAddress,
    vestingImplAddress: string,
    tokenAddress: string
) {
    const SuperfluidVestooorFactoryFactory =
        await hre.ethers.getContractFactory("SuperfluidVestooorFactory");
    const SuperfluidVestooorFactoryContract =
        await SuperfluidVestooorFactoryFactory.connect(signer).deploy(
            vestingImplAddress,
            tokenAddress
        );

    console.log(
        "Deployed SuperfluidVestooorFactory at:",
        SuperfluidVestooorFactoryContract.address
    );

    // programmatically verify the contract in production
    // https://hardhat.org/plugins/nomiclabs-hardhat-etherscan.html#using-programmatically
    if (
        process.env.VERIFY_CONTRACTS ||
        (hre.network.name !== "hardhat" && hre.network.name !== "localhost")
    ) {
        console.log("Awaiting 6 confirmations before verification...");
        await SuperfluidVestooorFactoryContract.deployTransaction.wait(6);

        await verifyContract(hre, SuperfluidVestooorFactoryContract.address, [
            vestingImplAddress,
            tokenAddress,
        ]);
    }

    return SuperfluidVestooorFactoryContract;
}
