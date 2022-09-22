import { expect } from "chai";
import { ethers } from "hardhat";

import { _makeSuite, TestEnvironment } from "./TestEnvironment";
import {
    buildVestee,
    buildVestees,
    createMultipleVestingContractPromise,
    createSingleVestingContractPromise,
    getEndTimestamp,
    getTotalAmountToBeVested,
    mintTokens,
} from "./utils";

_makeSuite("SuperfluidVestooorFactory Tests", (testEnv: TestEnvironment) => {
    describe("Negative Cases", function () {
        it("Owner cannot create a vesting contract without approval", async () => {
            const endTimestamp = await getEndTimestamp();
            const vestee = buildVestee(
                testEnv.alice.address,
                testEnv.constants.DEFAULT_VEST_AMOUNT,
                endTimestamp
            );
            await expect(
                createSingleVestingContractPromise(
                    testEnv,
                    testEnv.admin,
                    vestee
                )
            ).to.be.revertedWith("ERC20: insufficient allowance");
        });
    });

    describe("Happy Path", function () {
        context("Vesting Contract Creation", () => {
            this.beforeEach(async function () {
                await mintTokens(
                    testEnv,
                    testEnv.admin,
                    testEnv.constants.TOTAL_SUPPLY
                );
            });

            it("Should be able to create a single vesting contract", async () => {
                const endTimestamp = await getEndTimestamp();
                const vestee = buildVestee(
                    testEnv.alice.address,
                    testEnv.constants.DEFAULT_VEST_AMOUNT,
                    endTimestamp
                );
                const totalAmountToBeVested = getTotalAmountToBeVested([
                    vestee,
                ]);

                await testEnv.token
                    .connect(testEnv.admin)
                    .approve(
                        testEnv.SuperfluidVestooorFactory.address,
                        totalAmountToBeVested
                    );

                await expect(
                    createSingleVestingContractPromise(
                        testEnv,
                        testEnv.admin,
                        vestee
                    )
                ).to.emit(
                    testEnv.SuperfluidVestooorFactory,
                    "VestingContractCreated"
                );
            });

            it("Should be able to create multiple vesting contracts", async () => {
                const vestees = await buildVestees(
                    testEnv.users.slice(1, 11).map((x) => x.address)
                );
                const totalAmountToBeVested = getTotalAmountToBeVested(vestees);

                await testEnv.token
                    .connect(testEnv.admin)
                    .approve(
                        testEnv.SuperfluidVestooorFactory.address,
                        totalAmountToBeVested
                    );

                await createMultipleVestingContractPromise(
                    testEnv,
                    testEnv.admin,
                    vestees,
                    totalAmountToBeVested
                );
            });
        });
    });
});
